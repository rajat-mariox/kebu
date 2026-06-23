import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:kebu_driver/Utils/ApiClient/api_config.dart';
import 'package:kebu_driver/Utils/PrefsManager/prefs_manager.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 30; // seconds

  // Whether the driver has chosen to be online. The socket connecting (e.g. on
  // app open) must NOT by itself mark the driver available — only an explicit
  // goOnline()/toggle does. This flag lets a reconnect restore the online
  // presence without force-onlining an offline driver.
  bool _desiredOnline = false;

  // ── Broadcast streams ──
  final _newRideRequestController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideAcceptedConfirmedController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideTakenController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _newServiceBookingController = StreamController<Map<String, dynamic>>.broadcast();
  final _serviceBookingTakenController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewRideRequest => _newRideRequestController.stream;
  Stream<Map<String, dynamic>> get onRideAcceptedConfirmed => _rideAcceptedConfirmedController.stream;
  Stream<Map<String, dynamic>> get onRideCancelled => _rideCancelledController.stream;
  Stream<Map<String, dynamic>> get onRideTaken => _rideTakenController.stream;
  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<Map<String, dynamic>> get onNewServiceBooking => _newServiceBookingController.stream;
  Stream<Map<String, dynamic>> get onServiceBookingTaken => _serviceBookingTakenController.stream;

  void connect() {
    if (_socket != null && _socket!.connected) return;

    final baseUrl = ApiConfig.baseUrl.replaceAll('/v1/api', '');
    final token = Prefs.auth_token;
    if (token.isEmpty) {
      debugPrint('[Socket] No auth token, skipping connect');
      return;
    }

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token, 'userType': 'driver'})
        .disableAutoConnect()
        .build());

    _socket!.onConnect((_) async {
      debugPrint('[Socket] Connected');
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      // Only (re)assert online presence if the driver actually chose to be
      // online. Otherwise a fresh connect would silently flip the driver
      // available on the server and show their car to customers while the app
      // still reads Offline.
      if (_desiredOnline) {
        await _emitDriverOnlineWithLocation();
      }
    });

    _socket!.on('location_required', (_) {
      debugPrint('[Socket] Server requested location — re-sending');
      _emitDriverOnlineWithLocation();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected');
      _scheduleReconnect();
    });
    _socket!.onConnectError((e) {
      debugPrint('[Socket] Connect error: $e');
      _scheduleReconnect();
    });

    // ── Listen for incoming ride requests ──
    _socket!.on('new_ride_request', (data) {
      debugPrint('[Socket] New ride request: $data');
      _newRideRequestController.add(Map<String, dynamic>.from(data));
    });

    // ── Confirmation that ride was assigned to this driver ──
    _socket!.on('ride_accepted_confirmed', (data) {
      debugPrint('[Socket] Ride accepted confirmed: $data');
      _rideAcceptedConfirmedController.add(Map<String, dynamic>.from(data));
    });

    // ── Ride cancelled by user ──
    _socket!.on('ride_cancelled', (data) {
      debugPrint('[Socket] Ride cancelled: $data');
      _rideCancelledController.add(Map<String, dynamic>.from(data));
    });

    // ── Ride taken by another driver ──
    _socket!.on('ride_taken', (data) {
      debugPrint('[Socket] Ride taken by another driver: $data');
      _rideTakenController.add(Map<String, dynamic>.from(data));
    });

    // ── Notifications ──
    _socket!.on('new_notification', (data) {
      _notificationController.add(Map<String, dynamic>.from(data));
    });

    // ── Household service bookings ──
    _socket!.on('new_service_booking', (data) {
      debugPrint('[Socket] New service booking: $data');
      _newServiceBookingController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('service_booking_taken', (data) {
      debugPrint('[Socket] Service booking taken: $data');
      _serviceBookingTakenController.add(Map<String, dynamic>.from(data));
    });

    _socket!.connect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (Prefs.auth_token.isEmpty) return;

    // Exponential backoff: 2s, 4s, 8s, 16s, capped at 30s
    final delay = (_reconnectAttempts < 5)
        ? Duration(seconds: 2 << _reconnectAttempts)
        : const Duration(seconds: _maxReconnectDelay);
    _reconnectAttempts++;

    debugPrint('[Socket] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(delay, () {
      if (!isConnected) {
        debugPrint('[Socket] Attempting reconnect...');
        _socket?.connect();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _desiredOnline = false;
    if (_socket != null) {
      _socket!.emit('driver_offline', {'driverId': Prefs.user_id});
      _socket!.disconnect();
      _socket = null;
    }
  }

  Future<void> _emitDriverOnlineWithLocation() async {
    double? lat;
    double? lng;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (e) {
      debugPrint('[Socket] Could not get GPS for driver_online: $e');
    }
    _socket?.emit('driver_online', {
      'driverId': Prefs.user_id,
      if (lat != null) 'latitude': lat,
      if (lng != null) 'longitude': lng,
    });
  }

  // ── Emit actions ──
  void goOnline({double? latitude, double? longitude}) {
    _desiredOnline = true;
    if (latitude == null || longitude == null) {
      _emitDriverOnlineWithLocation();
      return;
    }
    _socket?.emit('driver_online', {
      'driverId': Prefs.user_id,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  void goOffline() {
    _desiredOnline = false;
    _socket?.emit('driver_offline', {'driverId': Prefs.user_id});
  }

  /// Aligns the socket's online presence with the authoritative server status
  /// (from the dashboard). Called on app open so that a driver who is genuinely
  /// online per the backend keeps their car/location fresh on reconnect, while
  /// an offline driver is never silently re-onlined.
  void syncOnlineState(bool online) {
    _desiredOnline = online;
    if (online && isConnected) {
      _emitDriverOnlineWithLocation();
    }
  }

  void updateLocation(double lat, double lng, {double heading = 0, double speed = 0}) {
    _socket?.emit('location_update', {
      'driverId': Prefs.user_id,
      'latitude': lat,
      'longitude': lng,
      'heading': heading,
      'speed': speed,
    });
  }

  void acceptRide(String bookingId) {
    _socket?.emit('accept_ride', {
      'bookingId': bookingId,
      'driverId': Prefs.user_id,
    });
  }

  void rejectRide(String bookingId) {
    _socket?.emit('reject_ride', {
      'bookingId': bookingId,
      'driverId': Prefs.user_id,
    });
  }

  void arrivedAtPickup(String bookingId) {
    _socket?.emit('arrived_at_pickup', {
      'bookingId': bookingId,
      'driverId': Prefs.user_id,
    });
  }

  void startRide(String bookingId, String otp) {
    _socket?.emit('start_ride', {
      'bookingId': bookingId,
      'driverId': Prefs.user_id,
      'otp': otp,
    });
  }

  void completeRide(String bookingId) {
    _socket?.emit('complete_ride', {
      'bookingId': bookingId,
      'driverId': Prefs.user_id,
    });
  }

  void cancelRide(String bookingId, {String reason = ''}) {
    _socket?.emit('cancel_ride_driver', {
      'bookingId': bookingId,
      'driverId': Prefs.user_id,
      'reason': reason,
    });
  }

  void emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  void dispose() {
    _newRideRequestController.close();
    _rideAcceptedConfirmedController.close();
    _rideTakenController.close();
    _rideCancelledController.close();
    _notificationController.close();
    disconnect();
  }
}
