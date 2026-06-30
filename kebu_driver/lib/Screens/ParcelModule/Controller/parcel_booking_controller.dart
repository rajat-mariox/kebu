import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Services/google_places_service.dart';
import 'package:kebu_driver/Services/socket_service.dart';

/// State + real-time request handling for the Parcel partner home.
///
/// Mirrors the cab `DriverBookingController` pattern: connects the socket,
/// keeps the partner online/offline, streams location so the backend dispatch
/// can find the driver, and surfaces incoming `new_delivery_request` events as
/// a live "New jobs" list with accept/reject.
class ParcelBookingController extends GetxController {
  // ── Partner / dashboard ──
  final isLoading = false.obs;
  final isOnline = false.obs;
  final partnerName = ''.obs;
  final partnerInitials = ''.obs;
  final profileImage = ''.obs;
  final rating = 0.0.obs;
  final availableBalance = 0.0.obs;
  final balanceHidden = false.obs;
  final currentLocationLabel = ''.obs;

  /// Live list of available delivery requests shown under "New jobs".
  final jobs = <Map<String, dynamic>>[].obs;

  // ── Accept in-flight guard (per delivery id) ──
  final acceptingId = ''.obs;

  StreamSubscription? _newReqSub;
  StreamSubscription? _takenSub;
  StreamSubscription? _cancelledSub;
  StreamSubscription<Position>? _positionSub;

  @override
  void onInit() {
    super.onInit();
    SocketService().connect();
    _subscribeSockets();
    _initOnline();
    loadCurrentLocation();
  }

  /// Load the dashboard and make sure the partner is ONLINE so the backend
  /// dispatch can reach them. There is no manual online/offline toggle anymore;
  /// a parcel partner is considered available whenever the home is open.
  Future<void> _initOnline() async {
    await fetchDashboard();
    if (!isOnline.value) {
      await toggleOnline();
    } else {
      SocketService().syncOnlineState(true);
      _startLocationStream();
    }
  }

  Future<void> loadCurrentLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final label =
          await GooglePlacesService.reverseGeocode(pos.latitude, pos.longitude);
      if (label.isNotEmpty) currentLocationLabel.value = label;
    } catch (e) {
      debugPrint('[Parcel] current location failed: $e');
    }
  }

  @override
  void onClose() {
    _newReqSub?.cancel();
    _takenSub?.cancel();
    _cancelledSub?.cancel();
    _positionSub?.cancel();
    super.onClose();
  }

  void _subscribeSockets() {
    _newReqSub = SocketService().onNewDeliveryRequest.listen(_onNewRequest);
    _takenSub = SocketService().onDeliveryTaken.listen((data) {
      _removeJob(data['deliveryId']?.toString());
    });
    _cancelledSub = SocketService().onDeliveryCancelled.listen((data) {
      _removeJob(data['deliveryId']?.toString());
    });
  }

  Future<void> fetchDashboard() async {
    isLoading.value = true;
    final res = await DriverApiService.getParcelDashboard();
    isLoading.value = false;

    if (res.success && res.data != null) {
      final partner = res.data['partner'] ?? {};
      partnerName.value = (partner['name'] ?? '').toString();
      partnerInitials.value = (partner['initials'] ?? '').toString();
      profileImage.value = (partner['profileImage'] ?? '').toString();
      rating.value = (partner['rating'] ?? 0).toDouble();
      isOnline.value = partner['isOnline'] == true;
      availableBalance.value =
          (res.data['availableBalance'] ?? 0).toDouble();

      final list = (res.data['newJobs'] as List?) ?? [];
      jobs.value =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Align the socket presence with the authoritative server status.
      SocketService().syncOnlineState(isOnline.value);
      if (isOnline.value) _startLocationStream();
    }
  }

  /// Pull the available list again (used by pull-to-refresh).
  Future<void> refreshJobs() async {
    final res = await DriverApiService.getAvailableDeliveries();
    if (res.success && res.data != null) {
      final list = (res.data['deliveries'] as List?) ?? [];
      jobs.value =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  }

  Future<void> toggleOnline() async {
    final res = await DriverApiService.toggleStatus();
    if (res.success) {
      final online = res.data?['isOnline'] == true;
      isOnline.value = online;
      if (online) {
        SocketService().goOnline();
        _startLocationStream();
      } else {
        SocketService().goOffline();
        _positionSub?.cancel();
        _positionSub = null;
      }
    } else {
      Get.snackbar('Status', res.message.isEmpty ? 'Could not update status' : res.message);
    }
  }

  void toggleBalanceVisibility() => balanceHidden.toggle();

  /// Build a job card from a live socket payload and prepend it (dedup by id).
  void _onNewRequest(Map<String, dynamic> data) {
    final id = data['deliveryId']?.toString();
    if (id == null || id.isEmpty) return;
    if (jobs.any((j) => j['deliveryId']?.toString() == id)) return;

    final drops = (data['drops'] as List?) ?? [];
    final firstDrop = drops.isNotEmpty ? Map<String, dynamic>.from(drops.first as Map) : null;
    final pickup = data['pickup'] is Map
        ? Map<String, dynamic>.from(data['pickup'] as Map)
        : null;

    jobs.insert(0, {
      'deliveryId': id,
      'deliveryType': data['deliveryType'],
      'category': _prettyType(data['deliveryType']?.toString()),
      'recipientName': firstDrop?['contactName'] ?? '',
      'dropAddress': firstDrop?['address'] ?? '',
      'pickupAddress': pickup?['address'] ?? '',
      'dropCount': drops.length,
      'fare': data['fare'] ?? 0,
    });

    _playAlert();
  }

  /// Audible + haptic alert when a new job arrives (best-effort).
  void _playAlert() {
    try {
      HapticFeedback.mediumImpact();
      FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
        looping: false,
        volume: 1.0,
        asAlarm: false,
      );
    } catch (_) {}
    Vibration.hasVibrator().then((has) {
      if (has == true) Vibration.vibrate(duration: 400);
    }).catchError((_) {});
  }

  void _removeJob(String? deliveryId) {
    if (deliveryId == null) return;
    jobs.removeWhere((j) => j['deliveryId']?.toString() == deliveryId);
  }

  /// Accept a request. Returns true when the delivery was successfully
  /// assigned to this partner.
  Future<bool> accept(String deliveryId) async {
    if (acceptingId.value.isNotEmpty) return false;
    acceptingId.value = deliveryId;
    final res = await DriverApiService.acceptDelivery(deliveryId);
    acceptingId.value = '';

    if (res.success) {
      _removeJob(deliveryId);
      Get.snackbar('Accepted', 'Delivery accepted successfully');
      // Refresh balance/active state.
      fetchDashboard();
      return true;
    } else {
      // Likely taken by someone else or already busy — drop the stale card.
      _removeJob(deliveryId);
      Get.snackbar(
        'Unavailable',
        res.message.isEmpty ? 'This request is no longer available' : res.message,
      );
      return false;
    }
  }

  Future<void> reject(String deliveryId) async {
    _removeJob(deliveryId);
    // Fire-and-forget; the card is dismissed locally regardless.
    DriverApiService.rejectDelivery(deliveryId);
  }

  void _startLocationStream() {
    if (_positionSub != null) return;
    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen((pos) {
        if (isOnline.value) {
          SocketService().updateLocation(
            pos.latitude,
            pos.longitude,
            heading: pos.heading,
            speed: pos.speed,
          );
        }
      });
    } catch (e) {
      debugPrint('[Parcel] location stream failed: $e');
    }
  }

  String _prettyType(String? type) {
    switch (type) {
      case 'DOCUMENT':
        return 'Document';
      case 'PARCEL':
        return 'Parcel';
      case 'FOOD':
        return 'Food';
      case 'GROCERY':
        return 'Grocery';
      default:
        return 'Delivery';
    }
  }
}
