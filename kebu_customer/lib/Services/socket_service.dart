import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:kebu_customer/Utils/ApiClient/api_config.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Event stream controllers
  final _rideAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _driverArrivedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _rideStartedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _rideCompletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _rideCancelledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _noDriversController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _serviceBookingAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _serviceBookingStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _providerLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  // Driver availability (online/offline) changes broadcast by the backend to
  // all customers — powers live nearby-driver markers on the booking map.
  final _driverStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onDriverStatusChanged =>
      _driverStatusController.stream;
  Stream<Map<String, dynamic>> get onServiceBookingAccepted =>
      _serviceBookingAcceptedController.stream;
  Stream<Map<String, dynamic>> get onServiceBookingStatus =>
      _serviceBookingStatusController.stream;
  Stream<Map<String, dynamic>> get onProviderLocation =>
      _providerLocationController.stream;
  Stream<Map<String, dynamic>> get onNoDriversAvailable =>
      _noDriversController.stream;
  Stream<Map<String, dynamic>> get onRideAccepted =>
      _rideAcceptedController.stream;
  Stream<Map<String, dynamic>> get onDriverLocation =>
      _driverLocationController.stream;
  Stream<Map<String, dynamic>> get onDriverArrived =>
      _driverArrivedController.stream;
  Stream<Map<String, dynamic>> get onRideStarted =>
      _rideStartedController.stream;
  Stream<Map<String, dynamic>> get onRideCompleted =>
      _rideCompletedController.stream;
  Stream<Map<String, dynamic>> get onRideCancelled =>
      _rideCancelledController.stream;
  Stream<Map<String, dynamic>> get onNotification =>
      _notificationController.stream;

  String get _socketUrl {
    String base = ApiConfig.baseUrl;
    final idx = base.indexOf('/v1/api');
    if (idx > 0) base = base.substring(0, idx);
    return base;
  }

  void connect() {
    if (_isConnected && _socket != null) return;
    if (Prefs.auth_token.isEmpty) return;

    _socket = IO.io(_socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {
        'token': Prefs.auth_token,
        'userType': 'user',
      },
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('Socket connected');
    });

    _socket!.on('ride_accepted', (data) {
      _rideAcceptedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('driver_location', (data) {
      _driverLocationController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('driver_arrived', (data) {
      _driverArrivedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('ride_started', (data) {
      _rideStartedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('ride_completed', (data) {
      _rideCompletedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('ride_cancelled', (data) {
      _rideCancelledController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('new_notification', (data) {
      _notificationController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('no_drivers_available', (data) {
      _noDriversController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('service_booking_accepted', (data) {
      _serviceBookingAcceptedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('service_booking_status', (data) {
      _serviceBookingStatusController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('provider_location', (data) {
      _providerLocationController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('driver_status_changed', (data) {
      _driverStatusController.add(Map<String, dynamic>.from(data));
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('Socket disconnected');
    });

    _socket!.onError((error) {
      debugPrint('Socket error: $error');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void cancelRide(String bookingId, {String? reason}) {
    _socket?.emit(
        'cancel_ride_user', {'bookingId': bookingId, 'reason': reason});
  }

  void sendSOS(String bookingId, {double? lat, double? lng}) {
    _socket
        ?.emit('sos_emergency', {'bookingId': bookingId, 'lat': lat, 'lng': lng});
  }

  void emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  void dispose() {
    disconnect();
    _rideAcceptedController.close();
    _driverLocationController.close();
    _driverArrivedController.close();
    _rideStartedController.close();
    _rideCompletedController.close();
    _rideCancelledController.close();
    _notificationController.close();
    _noDriversController.close();
    _serviceBookingAcceptedController.close();
    _serviceBookingStatusController.close();
    _providerLocationController.close();
    _driverStatusController.close();
  }
}
