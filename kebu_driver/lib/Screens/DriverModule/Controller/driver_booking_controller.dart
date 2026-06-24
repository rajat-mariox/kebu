import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kebu_driver/Utils/ApiClient/api_client.dart';
import 'package:kebu_driver/Services/socket_service.dart';

enum DriverRideState {
  idle,
  newRequest,
  navigatingToPickup,
  arrivedAtPickup,
  inProgress,
  completed,
}

class DriverBookingController extends GetxController {
  final SocketService _socket = SocketService();

  // ── State ──
  final rideState = DriverRideState.idle.obs;
  final isOnline = false.obs;
  final isLoading = false.obs;

  // ── Current booking info ──
  final bookingId = ''.obs;
  final bookingOtp = ''.obs;
  final pickupAddress = ''.obs;
  final dropAddress = ''.obs;
  final pickupLat = 0.0.obs;
  final pickupLng = 0.0.obs;
  final dropLat = 0.0.obs;
  final dropLng = 0.0.obs;
  final estimatedFare = 0.0.obs;
  // Surge component of the fare — the "+ ₹x" incentive on the take-booking
  // earnings card. 0 for non-surge rides (badge hidden).
  final surgeFare = 0.0.obs;
  // Trip-level distance/duration as quoted by the backend (booking.distanceKm
  // / durationMin), distinct from the live driver→pickup road distance.
  final tripDistanceKm = 0.0.obs;
  final tripDurationMin = 0.obs;
  // Scheduled pickup time; null for immediate rides.
  final scheduledAt = Rxn<DateTime>();
  // Trip type label (e.g. "One Way"); backend has no field yet so it defaults.
  final tripType = ''.obs;
  final vehicleType = ''.obs;
  final customerName = ''.obs;
  final customerPhone = ''.obs;
  final paymentMethod = 'CASH'.obs;

  // ── Ride timing — used by the post-ride summary / collect-cash screen ──
  final rideStartedAt = Rxn<DateTime>();
  final rideEndedAt = Rxn<DateTime>();

  // ── Incoming ride request (pending accept/reject) ──
  final pendingRequest = Rxn<Map<String, dynamic>>();

  // ── Driver's own GPS location ──
  final currentLat = 0.0.obs;
  final currentLng = 0.0.obs;
  StreamSubscription<Position>? _positionSub;

  // Road-distance (meters) to pickup/drop, populated by Google Distance Matrix
  // via `/driver/app/distance`. Null until first response arrives.
  final roadDistanceToPickupMeters = Rxn<double>();
  final roadDistanceToDropMeters = Rxn<double>();
  // Encoded polyline string for the active phase (driver→pickup or
  // driver→drop). Refreshed by the same throttled GPS handler.
  final routePolyline = Rxn<String>();
  // Duration in minutes for the active phase, populated by /driver/app/route.
  final routeDurationMin = Rxn<int>();

  // ── Turn-by-turn voice guidance ──
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  /// Reactive banner shown on the active-ride map during navigation.
  final navInstruction = ''.obs; // e.g. "Turn right onto Polk St"
  final navDistanceText = ''.obs; // distance to the next maneuver
  final navManeuver = ''.obs; // e.g. "turn-right" → picks the arrow icon
  /// Steps for the active leg: {instruction, maneuver, distanceMeters, lat, lng}.
  List<Map<String, dynamic>> _navSteps = [];
  int _navStepIndex = 0;
  String _lastSpoken = '';
  // Encoded polyline of the full trip (pickup → drop), drawn on the
  // take-booking / buzzer map so the driver sees the route up front.
  final tripRoutePolyline = Rxn<String>();
  DateTime? _lastDistanceCallAt;
  double? _lastDistanceCallLat;
  double? _lastDistanceCallLng;

  // Driver must be within this driving distance of pickup (meters) before
  // "I've Arrived" enables. Uses Google road distance when available, falls
  // back to GPS straight-line distance otherwise.
  static const double pickupArrivalRadiusMeters = 50.0;

  double? _haversinePickup() {
    if (currentLat.value == 0 || currentLng.value == 0) return null;
    if (pickupLat.value == 0 || pickupLng.value == 0) return null;
    return Geolocator.distanceBetween(
      currentLat.value,
      currentLng.value,
      pickupLat.value,
      pickupLng.value,
    );
  }

  double? _haversineDrop() {
    if (currentLat.value == 0 || currentLng.value == 0) return null;
    if (dropLat.value == 0 || dropLng.value == 0) return null;
    return Geolocator.distanceBetween(
      currentLat.value,
      currentLng.value,
      dropLat.value,
      dropLng.value,
    );
  }

  /// Effective distance (meters) from driver to pickup. Prefers Google road
  /// distance once available, falls back to GPS straight-line.
  double? get distanceToPickupMeters {
    return roadDistanceToPickupMeters.value ?? _haversinePickup();
  }

  /// Effective distance (meters) from driver to drop. Prefers Google road
  /// distance once available, falls back to GPS straight-line.
  double? get distanceToDropMeters {
    return roadDistanceToDropMeters.value ?? _haversineDrop();
  }

  /// Whether the driver is close enough to the pickup to confirm arrival.
  /// Uses the *closer* of GPS straight-line and Google road distance, because
  /// road distance can be misleading near pickup (e.g. Google snaps the
  /// pickup point to a road 80 m away when the actual entrance is 5 m away).
  /// Either signal indicating ≤ 50 m is enough.
  bool get isWithinPickupRadius {
    final road = roadDistanceToPickupMeters.value;
    final straight = _haversinePickup();
    if (road == null && straight == null) return false;
    final closest = [road, straight]
        .whereType<double>()
        .fold<double>(double.infinity, (a, b) => b < a ? b : a);
    return closest <= pickupArrivalRadiusMeters;
  }

  // ── Subscriptions ──
  final List<StreamSubscription> _subs = [];
  bool _disposed = false;

  @override
  void onInit() {
    super.onInit();
    _listenToSocket();
    detectCurrentLocation();
    _initTts();
  }

  @override
  void onClose() {
    _disposed = true;
    for (final sub in _subs) {
      sub.cancel();
    }
    _positionSub?.cancel();
    _positionSub = null;
    _tts.stop();
    super.onClose();
  }

  // ── Voice guidance ───────────────────────────────────────────────
  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
  }

  /// Voice/banner guidance runs ONLY during the trip (pickup → destination),
  /// not while heading to the pickup — that leg uses the plain tracking map.
  bool get _navActive => rideState.value == DriverRideState.inProgress;

  /// Store the decoded turn-by-turn steps for the active leg and refresh the
  /// banner. Called whenever a fresh route arrives from `/driver/app/route`.
  void _setNavSteps(List raw) {
    _navSteps = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _navStepIndex = 0;
    _lastSpoken = '';
    _updateNavGuidance();
  }

  /// Recompute the next-maneuver banner from the driver's current position,
  /// advance past maneuvers already reached, and speak each one once when the
  /// driver gets within announcing range.
  void _updateNavGuidance() {
    if (!_navActive || _navSteps.isEmpty) {
      _clearNav();
      return;
    }
    if (currentLat.value == 0 || currentLng.value == 0) return;
    if (_navStepIndex >= _navSteps.length) {
      _clearNav();
      return;
    }

    double distTo(Map s) => Geolocator.distanceBetween(
          currentLat.value,
          currentLng.value,
          (s['lat'] as num).toDouble(),
          (s['lng'] as num).toDouble(),
        );

    var step = _navSteps[_navStepIndex];
    var dist = distTo(step);
    // Skip maneuvers we've already driven past.
    while (dist < 30 && _navStepIndex < _navSteps.length - 1) {
      _navStepIndex++;
      step = _navSteps[_navStepIndex];
      dist = distTo(step);
    }

    final instr = (step['instruction'] ?? '').toString();
    navInstruction.value = instr;
    navManeuver.value = (step['maneuver'] ?? '').toString();
    navDistanceText.value = dist >= 1000
        ? '${(dist / 1000).toStringAsFixed(1)} km'
        : '${dist.round()} m';

    // Announce each instruction once, when within range.
    if (instr.isNotEmpty && dist <= 250 && instr != _lastSpoken) {
      _speak(dist >= 100 ? 'In ${dist.round()} meters, $instr' : instr);
      _lastSpoken = instr;
    }
  }

  Future<void> _speak(String text) async {
    if (!_ttsReady || text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void _clearNav() {
    navInstruction.value = '';
    navDistanceText.value = '';
    navManeuver.value = '';
  }

  void _listenToSocket() {
    _subs.add(_socket.onNewRideRequest.listen((data) {
      debugPrint('[DriverBookingCtrl] New ride request: $data');
      pendingRequest.value = data;
      _populateFromBooking(data);
      rideState.value = DriverRideState.newRequest;
    }));

    _subs.add(_socket.onRideCancelled.listen((data) {
      debugPrint('[DriverBookingCtrl] Ride cancelled by user: $data');
      // Only react if this is the ride we're currently showing (a pending
      // request or an active one). The customer cancelling a SEARCHING ride
      // fans this out to every notified driver, so without this guard an
      // unrelated request could get cleared.
      final cancelledBookingId = data['bookingId']?.toString() ?? '';
      if (cancelledBookingId.isNotEmpty &&
          bookingId.value.isNotEmpty &&
          cancelledBookingId != bookingId.value) {
        return;
      }
      final cancelledBy = (data['cancelledBy'] ?? 'USER').toString();
      resetBooking();
      Get.snackbar(
        'Ride Cancelled',
        cancelledBy == 'USER'
            ? 'The customer cancelled this ride. You are still online.'
            : 'This ride was cancelled.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }));

    // Listen for ride taken by another driver
    _subs.add(_socket.onRideTaken.listen((data) {
      debugPrint('[DriverBookingCtrl] Ride taken by another driver: $data');
      final takenBookingId = data['bookingId']?.toString() ?? '';
      
      // If this is the ride we were looking at, clear it
      if (bookingId.value == takenBookingId) {
        resetBooking();
        Get.snackbar(
          'Ride Taken',
          'This ride was accepted by another driver',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    }));
  }

  // ── GPS: Detect current location ──
  Future<void> detectCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        await Future.delayed(const Duration(seconds: 1));
        if (!await Geolocator.isLocationServiceEnabled()) return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
      }

      currentLat.value = pos.latitude;
      currentLng.value = pos.longitude;

      // Start continuous location stream
      _startLocationStream();
    } catch (e) {
      debugPrint('[DriverBookingCtrl] Location error: $e');
    }
  }

  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 meters
      ),
    ).listen((Position pos) {
      // The stream can deliver one buffered event after onClose() cancels the
      // subscription — writing to a disposed Rx throws. Guard with the flag.
      if (_disposed) return;
      currentLat.value = pos.latitude;
      currentLng.value = pos.longitude;

      // Send location to server via socket if online
      if (isOnline.value) {
        _socket.updateLocation(pos.latitude, pos.longitude,
            heading: pos.heading, speed: pos.speed);
      }

      // Refresh Google road-distance for the active ride.
      _maybeRefreshRoadDistance();
      // Update the turn-by-turn banner / speak the next maneuver.
      _updateNavGuidance();
    });
  }

  /// Throttled refresh of road distance + driving polyline using the
  /// backend `/driver/app/route` endpoint (Google Directions).
  ///
  /// Refreshes when:
  ///   - we don't yet have a road distance for the active phase, OR
  ///   - the driver has moved >= 100 m since the last call AND it has been
  ///     >= 20 seconds since the last call.
  ///
  /// 20s/100m is plenty for the live-tracking UI — at 50 km/h the driver
  /// covers 100m in ~7s, so the throttle keeps Google Directions calls to
  /// roughly 3 per minute even on a highway, instead of one per GPS tick.
  Future<void> _maybeRefreshRoadDistance() async {
    final state = rideState.value;
    final isPickupPhase = state == DriverRideState.navigatingToPickup;
    final isDropPhase = state == DriverRideState.inProgress;
    if (!isPickupPhase && !isDropPhase) return;

    if (currentLat.value == 0 || currentLng.value == 0) return;

    final destLat = isPickupPhase ? pickupLat.value : dropLat.value;
    final destLng = isPickupPhase ? pickupLng.value : dropLng.value;
    if (destLat == 0 || destLng == 0) return;

    final now = DateTime.now();
    final lastAt = _lastDistanceCallAt;
    final lastLat = _lastDistanceCallLat;
    final lastLng = _lastDistanceCallLng;

    final hasCachedForPhase = isPickupPhase
        ? roadDistanceToPickupMeters.value != null
        : roadDistanceToDropMeters.value != null;

    if (hasCachedForPhase && lastAt != null && lastLat != null && lastLng != null) {
      final movedMeters = Geolocator.distanceBetween(
        lastLat, lastLng, currentLat.value, currentLng.value,
      );
      final sinceMs = now.difference(lastAt).inMilliseconds;
      if (movedMeters < 100 || sinceMs < 20000) return;
    }

    _lastDistanceCallAt = now;
    _lastDistanceCallLat = currentLat.value;
    _lastDistanceCallLng = currentLng.value;

    try {
      // /route returns both the encoded polyline and distance/duration in
      // a single hop, so we don't need to also call /distance.
      final res = await ApiClient.get('/driver/app/route', queryParams: {
        'originLat': currentLat.value.toString(),
        'originLng': currentLng.value.toString(),
        'destLat': destLat.toString(),
        'destLng': destLng.toString(),
      });

      if (!res.success || res.data is! Map) return;
      final data = res.data as Map;
      final km = (data['distanceKm'] as num?)?.toDouble();
      final meters = km != null ? km * 1000.0 : null;
      final poly = (data['polyline'] as String?) ?? '';
      final durMin = (data['durationMin'] as num?)?.toInt();
      final steps = data['steps'];

      // Guard against stale responses arriving after the phase changed.
      if (isPickupPhase && rideState.value == DriverRideState.navigatingToPickup) {
        if (meters != null) roadDistanceToPickupMeters.value = meters;
        if (poly.isNotEmpty) routePolyline.value = poly;
        if (durMin != null) routeDurationMin.value = durMin;
        if (steps is List) _setNavSteps(steps);
      } else if (isDropPhase && rideState.value == DriverRideState.inProgress) {
        if (meters != null) roadDistanceToDropMeters.value = meters;
        if (poly.isNotEmpty) routePolyline.value = poly;
        if (durMin != null) routeDurationMin.value = durMin;
        if (steps is List) _setNavSteps(steps);
      }
    } catch (e) {
      debugPrint('[DriverBookingCtrl] route fetch failed: $e');
    }
  }

  /// Pull (lat, lng) from a location subdocument that may use either
  /// `{lat, lng}` (REST active-booking, fare-estimate) or
  /// `{coordinates: [lng, lat]}` (GeoJSON, socket events).
  /// Returns (0, 0) when neither shape is present.
  (double, double) _coordsFrom(dynamic loc) {
    if (loc is! Map) return (0, 0);
    if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
      final c = loc['coordinates'] as List;
      final lng = (c[0] as num?)?.toDouble() ?? 0;
      final lat = (c[1] as num?)?.toDouble() ?? 0;
      return (lat, lng);
    }
    final lat = (loc['lat'] as num?)?.toDouble()
        ?? (loc['latitude'] as num?)?.toDouble()
        ?? 0;
    final lng = (loc['lng'] as num?)?.toDouble()
        ?? (loc['longitude'] as num?)?.toDouble()
        ?? 0;
    return (lat, lng);
  }

  void _populateFromBooking(Map<String, dynamic> data) {
    // Clear stale road-distance / route from any prior booking before populating new coords.
    roadDistanceToPickupMeters.value = null;
    roadDistanceToDropMeters.value = null;
    routePolyline.value = null;
    routeDurationMin.value = null;
    tripRoutePolyline.value = null;
    _lastDistanceCallAt = null;
    _lastDistanceCallLat = null;
    _lastDistanceCallLng = null;

    bookingId.value = (data['bookingId'] ?? data['_id'] ?? '').toString();
    final pickup = data['pickupLocation'] ?? data['pickup'] ?? const {};
    final drop = data['dropLocation'] ?? data['drop'] ?? const {};
    pickupAddress.value = (pickup is Map ? pickup['address'] : '')?.toString() ?? '';
    dropAddress.value = (drop is Map ? drop['address'] : '')?.toString() ?? '';
    final (pLat, pLng) = _coordsFrom(pickup);
    pickupLat.value = pLat;
    pickupLng.value = pLng;
    final (dLat, dLng) = _coordsFrom(drop);
    dropLat.value = dLat;
    dropLng.value = dLng;

    estimatedFare.value =
        (data['finalFare'] ?? data['fare'] ?? data['estimatedFare'] ?? 0).toDouble();
    surgeFare.value = (data['surgeFare'] ?? 0).toDouble();
    tripDistanceKm.value = (data['distanceKm'] ?? 0).toDouble();
    tripDurationMin.value = (data['durationMin'] ?? 0).toInt();
    final sched = data['scheduledAt'];
    scheduledAt.value = sched is String ? DateTime.tryParse(sched)?.toLocal() : null;
    tripType.value = (data['tripType'] ?? data['rideType'] ?? '').toString();
    final vt = data['vehicleTypeId'];
    vehicleType.value = (vt is Map ? vt['name'] : null)?.toString()
        ?? (data['vehicleTypeName'] ?? data['vehicleType'] ?? '').toString();

    // The user/customer block is named `user` on socket events but `userId`
    // on REST endpoints (where mongoose populated the ref). Try both.
    final user = (data['user'] is Map ? data['user'] : data['userId']) ?? const {};
    customerName.value = (user is Map
            ? (user['fullName'] ?? user['name'] ?? '')
            : '')
        .toString();
    customerPhone.value = (user is Map
            ? (user['mobileNumber'] ?? user['phone'] ?? '')
            : '')
        .toString();
    paymentMethod.value = (data['paymentMethod'] ?? 'CASH').toString();

    // Fetch the pickup→drop driving route so the map can draw it. Fire and
    // forget — the map binds reactively to tripRoutePolyline.
    fetchTripRoute();
  }

  /// Fetch the driving route between pickup and drop and store its encoded
  /// polyline (and backfill trip distance/duration if the booking lacked
  /// them) so the take-booking map can render the route.
  Future<void> fetchTripRoute() async {
    if (pickupLat.value == 0 ||
        pickupLng.value == 0 ||
        dropLat.value == 0 ||
        dropLng.value == 0) {
      return;
    }
    try {
      final res = await ApiClient.get('/driver/app/route', queryParams: {
        'originLat': pickupLat.value.toString(),
        'originLng': pickupLng.value.toString(),
        'destLat': dropLat.value.toString(),
        'destLng': dropLng.value.toString(),
      });
      if (!res.success || res.data is! Map) return;
      final data = res.data as Map;
      final poly = (data['polyline'] as String?) ?? '';
      if (poly.isNotEmpty) tripRoutePolyline.value = poly;
      final km = (data['distanceKm'] as num?)?.toDouble();
      final dur = (data['durationMin'] as num?)?.toInt();
      if (km != null && km > 0 && tripDistanceKm.value == 0) {
        tripDistanceKm.value = km;
      }
      if (dur != null && dur > 0 && tripDurationMin.value == 0) {
        tripDurationMin.value = dur;
      }
    } catch (e) {
      debugPrint('[DriverBookingCtrl] trip route fetch failed: $e');
    }
  }

  /// Populate controller state from an arbitrary booking payload (e.g.
  /// fetched from `/driver/app/booking/:id` after a push tap) and put the
  /// state machine in `newRequest` so the buzzer screen UI binds correctly.
  void populateFromPush(Map<String, dynamic> data) {
    pendingRequest.value = data;
    _populateFromBooking(data);
    rideState.value = DriverRideState.newRequest;
  }

  /// True when the driver is currently committed to a booking (anything past
  /// `newRequest`). Used to block online/offline toggling during an active
  /// ride — driver should finish or cancel the ride first.
  bool get hasActiveRide {
    final s = rideState.value;
    return s == DriverRideState.navigatingToPickup ||
        s == DriverRideState.arrivedAtPickup ||
        s == DriverRideState.inProgress;
  }

  // ── Toggle online status ──
  Future<void> toggleOnline() async {
    // Block toggling when an active ride is in progress: driver must be
    // implicitly online for the customer side to keep working, and shouldn't
    // be made available for new rides until the current one ends.
    if (hasActiveRide) {
      Get.snackbar(
        'Active ride in progress',
        'Complete or cancel the current ride before changing status.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    isLoading.value = true;
    final body = <String, dynamic>{};
    if (currentLat.value != 0 && currentLng.value != 0) {
      body['latitude'] = currentLat.value;
      body['longitude'] = currentLng.value;
    }
    final res = await ApiClient.put('/driver/app/status', body: body);
    if (res.success) {
      isOnline.value = !isOnline.value;
      if (isOnline.value) {
        _socket.connect();
        _socket.goOnline(
          latitude: currentLat.value != 0 ? currentLat.value : null,
          longitude: currentLng.value != 0 ? currentLng.value : null,
        );
      } else {
        _socket.goOffline();
      }
    }
    isLoading.value = false;
  }

  // ── Accept ride (REST only — socket notifies backend separately) ──
  Future<void> acceptRide() async {
    if (bookingId.value.isEmpty) return;
    isLoading.value = true;
    final res = await ApiClient.post('/driver/app/booking/${bookingId.value}/accept');
    if (res.success) {
      final booking = (res.data is Map && res.data['booking'] is Map)
          ? res.data['booking'] as Map
          : (res.data is Map ? res.data as Map : const {});
      bookingOtp.value = (booking['otp'] ?? '').toString();
      rideState.value = DriverRideState.navigatingToPickup;
      pendingRequest.value = null;
      // Kick off the first road-distance fetch immediately rather than
      // waiting for the next GPS tick.
      _maybeRefreshRoadDistance();
    } else {
      Get.snackbar('Error', res.message ?? 'Ride is no longer available',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
    isLoading.value = false;
  }

  // ── Reject ride ──
  void rejectRide() {
    if (bookingId.value.isEmpty) return;
    _socket.rejectRide(bookingId.value);
    resetBooking();
  }

  // ── Arrived at pickup ──
  // No client-side radius gate: OTP entry on the next sheet is the actual
  // proof-of-presence, and GPS noise / off-road pickup pins make a 50m gate
  // unreliable in practice.
  Future<void> arrivedAtPickup() async {
    isLoading.value = true;
    final res = await ApiClient.put('/driver/app/booking/${bookingId.value}/status', body: {
      'status': 'DRIVER_ARRIVED',
    });
    if (res.success) {
      rideState.value = DriverRideState.arrivedAtPickup;
    } else {
      // Fluttertoast doesn't need an Overlay/Navigator ancestor, so it's safe
      // from inside a controller; Get.snackbar threw "No Overlay widget found"
      // here because the snackbar overlay lookup races with route lifecycle.
      Fluttertoast.showToast(
        msg: res.message ?? 'Could not confirm arrival. Please try again.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
    isLoading.value = false;
  }

  // ── Start ride (with OTP verification) ──
  Future<bool> startRide(String otp) async {
    isLoading.value = true;
    final res = await ApiClient.put('/driver/app/booking/${bookingId.value}/status', body: {
      'status': 'IN_PROGRESS',
      'otp': otp,
    });
    isLoading.value = false;
    if (res.success) {
      rideState.value = DriverRideState.inProgress;
      rideStartedAt.value = DateTime.now();
      // Phase changed: drop the cached pickup distance/route and fetch drop's.
      roadDistanceToPickupMeters.value = null;
      routePolyline.value = null;
      routeDurationMin.value = null;
      _lastDistanceCallAt = null;
      _maybeRefreshRoadDistance();
      return true;
    }
    Get.snackbar('Error', res.message ?? 'Invalid OTP',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white);
    return false;
  }

  // ── Complete ride ──
  Future<void> completeRide() async {
    isLoading.value = true;
    final res = await ApiClient.put('/driver/app/booking/${bookingId.value}/status', body: {
      'status': 'COMPLETED',
    });
    if (res.success) {
      rideEndedAt.value = DateTime.now();
      rideState.value = DriverRideState.completed;
    }
    isLoading.value = false;
  }

  /// Mark the cash payment as collected by the driver. Called from the
  /// CollectCashScreen after the driver confirms cash in hand. The booking
  /// is already COMPLETED on the backend at this point — this just flips
  /// the payment status.
  Future<bool> markCashCollected() async {
    if (bookingId.value.isEmpty) return false;
    isLoading.value = true;
    final res = await ApiClient.put(
      '/driver/app/booking/${bookingId.value}/payment',
      body: {'paymentStatus': 'PAID'},
    );
    isLoading.value = false;
    return res.success;
  }

  // ── Cancel ride ──
  Future<void> cancelRide({String reason = ''}) async {
    await ApiClient.put('/driver/app/booking/${bookingId.value}/cancel', body: {
      'reason': reason,
    });
    resetBooking();
  }

  // ── Check for active booking on app start ──
  Future<bool> checkActiveBooking() async {
    final res = await ApiClient.get('/driver/app/booking/active');
    if (res.success && res.data != null) {
      // Backend wraps the booking as `{ booking: {...} }`. Older callers
      // returned the raw booking object — accept both shapes.
      Map booking = res.data is Map ? res.data as Map : {};
      if (booking['booking'] is Map) {
        booking = booking['booking'] as Map;
      }
      if (booking['_id'] != null) {
        _populateFromBooking(Map<String, dynamic>.from(booking));
        bookingOtp.value = (booking['otp'] ?? '').toString();
        final status = (booking['status'] ?? '').toString();
        switch (status) {
          case 'ASSIGNED':
            rideState.value = DriverRideState.navigatingToPickup;
            break;
          case 'DRIVER_ARRIVED':
            rideState.value = DriverRideState.arrivedAtPickup;
            break;
          case 'IN_PROGRESS':
          case 'PICKED':
            rideState.value = DriverRideState.inProgress;
            break;
          default:
            return false;
        }
        _maybeRefreshRoadDistance();
        return true;
      }
    }
    return false;
  }

  /// Open native turn-by-turn navigation to (lat,lng) using Google Maps when
  /// available, falling back to Apple Maps on iOS, then to a web URL.
  Future<void> openExternalNavigation(double lat, double lng, {String? label}) async {
    if (lat == 0 || lng == 0) {
      Get.snackbar('Navigation', 'Destination coordinates are not available',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final candidates = <Uri>[];

    if (Platform.isAndroid) {
      // google.navigation gives turn-by-turn with the Google Maps app
      candidates.add(Uri.parse('google.navigation:q=$lat,$lng&mode=d'));
      candidates.add(Uri.parse('geo:$lat,$lng?q=$lat,$lng${label != null ? '(${Uri.encodeComponent(label)})' : ''}'));
    } else if (Platform.isIOS) {
      candidates.add(Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving'));
      candidates.add(Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d'));
    }

    // Universal web fallback
    candidates.add(Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'));

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return;
        }
      } catch (e) {
        debugPrint('[DriverBookingCtrl] launch failed for $uri: $e');
      }
    }

    Get.snackbar('Navigation', 'No maps app could be opened',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red, colorText: Colors.white);
  }

  void resetBooking() {
    _navSteps = [];
    _navStepIndex = 0;
    _lastSpoken = '';
    _clearNav();
    _tts.stop();
    rideState.value = DriverRideState.idle;
    bookingId.value = '';
    bookingOtp.value = '';
    pickupAddress.value = '';
    dropAddress.value = '';
    pickupLat.value = 0;
    pickupLng.value = 0;
    dropLat.value = 0;
    dropLng.value = 0;
    estimatedFare.value = 0;
    surgeFare.value = 0;
    tripDistanceKm.value = 0;
    tripDurationMin.value = 0;
    scheduledAt.value = null;
    tripType.value = '';
    vehicleType.value = '';
    customerName.value = '';
    customerPhone.value = '';
    pendingRequest.value = null;
    roadDistanceToPickupMeters.value = null;
    roadDistanceToDropMeters.value = null;
    routePolyline.value = null;
    routeDurationMin.value = null;
    tripRoutePolyline.value = null;
    rideStartedAt.value = null;
    rideEndedAt.value = null;
    _lastDistanceCallAt = null;
    _lastDistanceCallLat = null;
    _lastDistanceCallLng = null;
  }
}
