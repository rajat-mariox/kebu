import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kebu_customer/Services/booking_api_service.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';
import 'package:kebu_customer/Services/maps_api_service.dart';
import 'package:kebu_customer/Services/socket_service.dart';
import 'package:kebu_customer/Utils/ApiClient/api_client.dart';

/// Booking lifecycle states
enum BookingState {
  idle,
  selectingLocations,
  loadingFares,
  selectingVehicle,
  creatingBooking,
  searching,
  driverAssigned,
  driverArrived,
  inProgress,
  completed,
  cancelled,
}

class BookingController extends GetxController {
  static const double pickupRadiusMeters = 5000.0;
  static const double nearbyDriverSearchRadiusKm = 5.0;

  // ── State ──
  final Rx<BookingState> state = BookingState.idle.obs;
  final RxBool isLoading = false.obs;

  // ── Location ──
  final RxString pickupAddress = 'My current location'.obs;
  final RxDouble pickupLat = 0.0.obs;
  final RxDouble pickupLng = 0.0.obs;
  final RxString dropAddress = ''.obs;
  final RxDouble dropLat = 0.0.obs;
  final RxDouble dropLng = 0.0.obs;

  // ── Distance / Duration ──
  final RxDouble distanceKm = 0.0.obs;
  final RxInt durationMin = 0.obs;

  // ── Vehicle / Fare ──
  final RxList<Map<String, dynamic>> fareEstimates =
      <Map<String, dynamic>>[].obs;
  final RxInt selectedVehicleIndex = (-1).obs;

  // ── Active Booking ──
  final RxString bookingId = ''.obs;
  final RxString bookingOtp = ''.obs;
  final RxString bookingStatus = ''.obs;
  final RxDouble finalFare = 0.0.obs;
  // Vehicle type name of the booked ride (e.g. "Bike", "Auto") — drives the
  // correct vehicle marker on the live-tracking map.
  final RxString bookedVehicleType = ''.obs;
  final RxString paymentMethod = 'CASH'.obs;
  final RxString promoCode = ''.obs;

  // ── Driver ──
  final RxMap<String, dynamic> driverInfo = <String, dynamic>{}.obs;
  final RxDouble driverLat = 0.0.obs;
  final RxDouble driverLng = 0.0.obs;
  final RxDouble driverHeading = 0.0.obs;
  final RxInt etaMinutes = 0.obs;

  // ── Live route polyline (driver → pickup, then driver → drop) ──
  // Encoded Google polyline string. Refreshed by `_refreshRoutePolyline()`
  // whenever the driver location changes by a meaningful amount.
  final Rxn<String> routePolyline = Rxn<String>();
  DateTime? _lastRouteCallAt;
  double? _lastRouteCallDriverLat;
  double? _lastRouteCallDriverLng;

  // ── Place Search ──
  final RxList<Map<String, dynamic>> searchResults =
      <Map<String, dynamic>>[].obs;
  final RxBool isSearching = false.obs;

  // ── Nearby Drivers ──
  final RxList<Map<String, dynamic>> nearbyDrivers =
      <Map<String, dynamic>>[].obs;
  final RxBool currentLocationLoaded = false.obs;

  /// Backend-computed ETA (minutes) for the nearest available driver to reach
  /// the pickup — powers the "Get a cab in X mins" map pill. Null when no
  /// driver is nearby.
  final RxnInt cabEtaMinutes = RxnInt();

  // ── Recent places (derived from past bookings' drop locations) ──
  final RxList<Map<String, dynamic>> recentPlaces =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoadingRecent = false.obs;

  // ── Riders ("For me" / Book for others) ──
  final RxList<Map<String, dynamic>> riders = <Map<String, dynamic>>[].obs;
  // null => booking for self ("For me").
  final Rxn<Map<String, dynamic>> selectedRider = Rxn<Map<String, dynamic>>();

  // ── Error message ──
  final RxString errorMessage = ''.obs;

  // ── Internals ──
  StreamSubscription? _rideAcceptedSub;
  StreamSubscription? _driverLocationSub;
  StreamSubscription? _driverArrivedSub;
  StreamSubscription? _rideStartedSub;
  StreamSubscription? _rideCompletedSub;
  StreamSubscription? _rideCancelledSub;
  StreamSubscription? _driverStatusSub;
  Timer? _trackingTimer;
  Timer? _nearbyTimer;
  // Auto-retries fare/vehicle availability every 3s while none is available.
  Timer? _fareTimer;

  @override
  void onInit() {
    super.onInit();
    _listenToSocket();
    detectCurrentLocation();
  }

  @override
  void onClose() {
    _rideAcceptedSub?.cancel();
    _driverLocationSub?.cancel();
    _driverArrivedSub?.cancel();
    _rideStartedSub?.cancel();
    _rideCompletedSub?.cancel();
    _rideCancelledSub?.cancel();
    _driverStatusSub?.cancel();
    _trackingTimer?.cancel();
    _nearbyTimer?.cancel();
    _fareTimer?.cancel();
    super.onClose();
  }

  // ─────────────────────────────
  // Socket listeners
  // ─────────────────────────────
  void _listenToSocket() {
    final socket = SocketService();

    _rideAcceptedSub = socket.onRideAccepted.listen((data) {
      debugPrint('BookingController: ride_accepted $data');
      final driver = data['driver'] as Map<String, dynamic>?;
      final booking = data['booking'] as Map<String, dynamic>?;
      final driverLoc = data['driverLocation'] as Map<String, dynamic>?;

      if (driver != null) driverInfo.value = driver;
      if (booking != null) {
        bookingOtp.value = booking['otp']?.toString() ?? '';
        bookingStatus.value = booking['status'] ?? 'ASSIGNED';
      }
      if (driverLoc != null) {
        driverLat.value = (driverLoc['latitude'] ?? 0).toDouble();
        driverLng.value = (driverLoc['longitude'] ?? 0).toDouble();
      }
      state.value = BookingState.driverAssigned;
      _startTrackingPolling();
      // Cold-start the polyline so the path is visible before the next
      // location ping arrives.
      _maybeRefreshRoutePolyline();
    });

    _driverLocationSub = socket.onDriverLocation.listen((data) {
      driverLat.value = (data['latitude'] ?? 0).toDouble();
      driverLng.value = (data['longitude'] ?? 0).toDouble();
      driverHeading.value = (data['heading'] ?? 0).toDouble();
      _maybeRefreshRoutePolyline();
    });

    _driverArrivedSub = socket.onDriverArrived.listen((data) {
      bookingStatus.value = 'DRIVER_ARRIVED';
      state.value = BookingState.driverArrived;
    });

    _rideStartedSub = socket.onRideStarted.listen((data) {
      bookingStatus.value = 'IN_PROGRESS';
      state.value = BookingState.inProgress;
      // Phase changed: clear pickup polyline so the next refresh draws
      // the driver→drop path instead of stale driver→pickup.
      routePolyline.value = null;
      _lastRouteCallAt = null;
      _maybeRefreshRoutePolyline();
    });

    _rideCompletedSub = socket.onRideCompleted.listen((data) {
      final booking = data['booking'] as Map<String, dynamic>?;
      if (booking != null) {
        finalFare.value = (booking['finalFare'] ?? 0).toDouble();
      }
      bookingStatus.value = 'COMPLETED';
      state.value = BookingState.completed;
      _stopTrackingPolling();
    });

    _rideCancelledSub = socket.onRideCancelled.listen((data) {
      bookingStatus.value = 'CANCELLED';
      state.value = BookingState.cancelled;
      _stopTrackingPolling();
    });

    // Live driver availability: a driver going online/offline is reflected on
    // the map instantly instead of waiting for the 30s nearby-drivers poll.
    _driverStatusSub = socket.onDriverStatusChanged.listen(_onDriverStatusChanged);
  }

  /// Applies a real-time driver online/offline event to [nearbyDrivers] so the
  /// booking map's car markers appear/disappear immediately. Mutating the list
  /// in place (rather than re-fetching) keeps the update smooth; the 30s poll
  /// still runs as a reconciliation fallback.
  void _onDriverStatusChanged(Map<String, dynamic> data) {
    final driverId = data['driverId']?.toString();
    if (driverId == null || driverId.isEmpty) return;

    final isOnline = data['isOnline'] == true;
    final current = nearbyDrivers.toList();
    final index = current.indexWhere((d) => d['id']?.toString() == driverId);

    if (!isOnline) {
      // Driver went offline / disconnected → drop their marker if present.
      if (index != -1) {
        current.removeAt(index);
        nearbyDrivers.value = current;
      }
      return;
    }

    // Online: only a cab driver within the search radius of the current pickup
    // should show up on this map.
    final serviceType = data['serviceType']?.toString();
    if (serviceType != null && serviceType.isNotEmpty && serviceType != 'cab') {
      return;
    }
    final lat = (data['latitude'] ?? 0).toDouble();
    final lng = (data['longitude'] ?? 0).toDouble();
    if (lat == 0 || lng == 0) return;
    if (pickupLat.value == 0 || pickupLng.value == 0) return;

    final meters = Geolocator.distanceBetween(
      pickupLat.value, pickupLng.value, lat, lng,
    );
    if (meters > nearbyDriverSearchRadiusKm * 1000) return;

    final entry = {
      'id': driverId,
      'latitude': lat,
      'longitude': lng,
      'heading': (data['heading'] ?? 0).toDouble(),
      'vehicleImage': '',
      // Drives the per-type map marker. May be empty on the realtime event
      // (then the marker shows as a car until the next nearby-drivers poll
      // fills in the real type).
      'vehicleType': (data['vehicleType'] ?? '').toString(),
    };
    if (index != -1) {
      current[index] = entry; // already known — refresh its position
    } else {
      current.add(entry);
    }
    nearbyDrivers.value = current;
  }

  // ─────────────────────────────
  // Route polyline (live driver → pickup or driver → drop)
  // ─────────────────────────────
  /// Throttled fetch of the encoded driving polyline from the backend so
  /// the live-tracking map can draw the actual road path. Refreshes only
  /// when the driver has moved >= 100 m AND it has been >= 20s since the
  /// last call. Driver location pings arrive multiple times per second; we
  /// don't want to hit Google Directions on every one of them.
  Future<void> _maybeRefreshRoutePolyline() async {
    if (driverLat.value == 0 || driverLng.value == 0) return;

    // Phase: driver→pickup before pickup, driver→drop after.
    final isDropPhase = bookingStatus.value == 'IN_PROGRESS' ||
        bookingStatus.value == 'PICKED';
    final destLat = isDropPhase ? dropLat.value : pickupLat.value;
    final destLng = isDropPhase ? dropLng.value : pickupLng.value;
    if (destLat == 0 || destLng == 0) return;

    final now = DateTime.now();
    final lastAt = _lastRouteCallAt;
    final lastLat = _lastRouteCallDriverLat;
    final lastLng = _lastRouteCallDriverLng;
    if (lastAt != null && lastLat != null && lastLng != null) {
      final movedMeters = Geolocator.distanceBetween(
        lastLat, lastLng, driverLat.value, driverLng.value,
      );
      final sinceMs = now.difference(lastAt).inMilliseconds;
      if (movedMeters < 100 || sinceMs < 20000) return;
    }

    _lastRouteCallAt = now;
    _lastRouteCallDriverLat = driverLat.value;
    _lastRouteCallDriverLng = driverLng.value;

    try {
      final res = await ApiClient.get('/maps/route', queryParams: {
        'originLat': driverLat.value.toString(),
        'originLng': driverLng.value.toString(),
        'destLat': destLat.toString(),
        'destLng': destLng.toString(),
      });
      if (!res.success || res.data is! Map) return;
      final data = res.data as Map;
      final poly = (data['polyline'] as String?) ?? '';
      if (poly.isNotEmpty) routePolyline.value = poly;
    } catch (e) {
      debugPrint('[BookingController] route fetch failed: $e');
    }
  }

  // ─────────────────────────────
  // Location selection
  // ─────────────────────────────
  void setPickupLocation(
    String address,
    double lat,
    double lng, {
    bool fromDeviceLocation = false,
  }) {
    pickupAddress.value = address;
    pickupLat.value = lat;
    pickupLng.value = lng;
    currentLocationLoaded.value = fromDeviceLocation;

    if (lat != 0 && lng != 0) {
      errorMessage.value = '';
      fetchNearbyDrivers();
      _startNearbyPolling();
    } else {
      nearbyDrivers.clear();
      _nearbyTimer?.cancel();
    }
  }

  void setDropLocation(String address, double lat, double lng) {
    dropAddress.value = address;
    dropLat.value = lat;
    dropLng.value = lng;
  }

  // ─────────────────────────────
  // GPS current location
  // ─────────────────────────────
  Future<void> detectCurrentLocation() async {
    try {
      currentLocationLoaded.value = false;
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Prompt user to enable location services
        await Geolocator.openLocationSettings();
        // Re-check after user returns from settings
        await Future.delayed(const Duration(seconds: 1));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          errorMessage.value = 'Please enable location services';
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        errorMessage.value = 'Location permission denied';
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        // Open app settings so user can grant permission
        await Geolocator.openAppSettings();
        errorMessage.value = 'Please allow location permission in settings';
        return;
      }

      // Use the last known location immediately when available so the booking
      // screen can still render a pickup radius while a fresh GPS fix is pending.
      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        setPickupLocation(
          pickupAddress.value,
          position.latitude,
          position.longitude,
          fromDeviceLocation: true,
        );
        errorMessage.value = '';
      }

      final LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 2),
          forceLocationManager: false,
        );
      } else if (Platform.isIOS || Platform.isMacOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
        );
      }

      try {
        position = await Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).first.timeout(const Duration(seconds: 20));
      } on TimeoutException catch (_) {
        if (position == null) {
          errorMessage.value =
              'Could not detect live location. Set emulator/device location and try again.';
          return;
        }
      }

      setPickupLocation(
        pickupAddress.value,
        position.latitude,
        position.longitude,
        fromDeviceLocation: true,
      );
      errorMessage.value = '';

      // Reverse geocode to get address
      final response = await MapsApiService.reverseGeocode(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (response.success && response.data != null) {
        final addr = response.data['address'] ?? response.data['display_name'] ?? '';
        if (addr.toString().isNotEmpty) {
          pickupAddress.value = addr.toString();
        }
      }

    } catch (e) {
      debugPrint('Error detecting location: $e');
      errorMessage.value = 'Could not detect location. Please try again.';
    }
  }

  // ─────────────────────────────
  // Nearby drivers
  // ─────────────────────────────
  Future<void> fetchNearbyDrivers() async {
    if (pickupLat.value == 0 || pickupLng.value == 0) return;

    final response = await BookingApiService.getNearbyDrivers(
      lat: pickupLat.value,
      lng: pickupLng.value,
      maxDistance: nearbyDriverSearchRadiusKm,
    );

    debugPrint('Nearby drivers response: success=${response.success}, data=${response.data}');
    if (response.success && response.data != null) {
      final drivers = response.data['drivers'] as List? ?? [];
      nearbyDrivers.value =
          drivers.map((d) => Map<String, dynamic>.from(d as Map)).toList();
      final eta = response.data['etaMinutes'];
      cabEtaMinutes.value = eta is num ? eta.toInt() : null;
      debugPrint('Found ${nearbyDrivers.length} nearby drivers, eta=$eta');
    }
  }

  /// Re-anchor the pickup to wherever the map is centered (Uber-style: drag the
  /// map, the centre pin sets the pickup). Updates coords + nearby drivers
  /// immediately, then reverse-geocodes for a readable address.
  Future<void> updatePickupFromMap(double lat, double lng) async {
    // Ignore tiny camera settles (~20m) to avoid spamming reverse geocode.
    if ((lat - pickupLat.value).abs() < 0.0002 &&
        (lng - pickupLng.value).abs() < 0.0002) {
      return;
    }
    pickupLat.value = lat;
    pickupLng.value = lng;
    currentLocationLoaded.value = false;
    errorMessage.value = '';
    fetchNearbyDrivers();
    _startNearbyPolling();

    try {
      final response = await MapsApiService.reverseGeocode(lat: lat, lng: lng);
      if (response.success && response.data != null) {
        final addr = response.data['address'] ??
            response.data['display_name'] ??
            '';
        if (addr.toString().isNotEmpty) {
          pickupAddress.value = addr.toString();
        }
      }
    } catch (e) {
      debugPrint('updatePickupFromMap reverse geocode failed: $e');
    }
  }

  void _startNearbyPolling() {
    _nearbyTimer?.cancel();
    _nearbyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchNearbyDrivers();
    });
  }

  Future<void> searchPlaces(String query) async {
    if (query.trim().length < 3) {
      searchResults.clear();
      return;
    }
    isSearching.value = true;
    final response = await MapsApiService.searchPlaces(
      query,
      lat: pickupLat.value != 0 ? pickupLat.value : null,
      lng: pickupLng.value != 0 ? pickupLng.value : null,
    );
    if (response.success && response.data != null) {
      final predictions = response.data['predictions'] as List? ?? [];
      searchResults.value = predictions
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
    }
    isSearching.value = false;
  }

  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    final response = await MapsApiService.getPlaceDetails(placeId);
    if (response.success && response.data != null) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  // ─────────────────────────────
  // Recent places (from booking history drop locations)
  // ─────────────────────────────
  Future<void> loadRecentPlaces() async {
    isLoadingRecent.value = true;
    try {
      final response = await BookingApiService.getBookingHistory(limit: 20);
      if (response.success && response.data != null) {
        final bookings = (response.data['bookings'] as List?) ?? [];
        final seen = <String>{};
        final places = <Map<String, dynamic>>[];

        for (final raw in bookings) {
          final b = Map<String, dynamic>.from(raw as Map);
          final drop = b['drop'];
          if (drop is! Map) continue;

          final address = (drop['address'] ?? '').toString().trim();
          final lat = (drop['lat'] ?? 0).toDouble();
          final lng = (drop['lng'] ?? 0).toDouble();
          if (address.isEmpty || lat == 0 || lng == 0) continue;

          final key = address.toLowerCase();
          if (seen.contains(key)) continue;
          seen.add(key);

          places.add({
            'name': _placeLabel(address),
            'address': address,
            'lat': lat,
            'lng': lng,
            'distanceKm': _distanceFromPickupKm(lat, lng),
          });
          if (places.length >= 6) break;
        }
        recentPlaces.value = places;
      }
    } catch (e) {
      debugPrint('[BookingController] loadRecentPlaces failed: $e');
    } finally {
      isLoadingRecent.value = false;
    }
  }

  /// Clears the recent-places list for the current session.
  void clearRecentPlaces() => recentPlaces.clear();

  /// Distance in km from current pickup to [lat]/[lng], or null when the
  /// pickup is not yet known. Public so the UI can recompute reactively once
  /// the current location resolves after the recent list is built.
  double? distanceFromPickupKm(double lat, double lng) => _distanceFromPickupKm(lat, lng);

  double? _distanceFromPickupKm(double lat, double lng) {
    if (pickupLat.value == 0 || pickupLng.value == 0) return null;
    final meters = Geolocator.distanceBetween(
      pickupLat.value, pickupLng.value, lat, lng,
    );
    return meters / 1000.0;
  }

  /// Short, human-friendly label from a full address (first segment).
  String _placeLabel(String address) {
    final first = address.split(',').first.trim();
    return first.isNotEmpty ? first : address;
  }

  // ─────────────────────────────
  // Riders ("For me" / Book for others)
  // ─────────────────────────────
  Future<void> loadRiders() async {
    try {
      final response = await CustomerFeaturesApiService.getRiders();
      if (response.success && response.data != null) {
        final list = (response.data['riders'] ?? response.data['data'] ?? []) as List?;
        if (list != null) {
          riders.value =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('[BookingController] loadRiders failed: $e');
    }
  }

  /// Creates a new rider ("Book for others") and refreshes the list.
  Future<bool> addRider(String name, String phone) async {
    try {
      final response = await CustomerFeaturesApiService.addRider({
        'name': name.trim(),
        'phone': phone.trim(),
      });
      if (response.success) {
        await loadRiders();
        // Auto-select the freshly added rider when we can identify it.
        final added = response.data is Map ? response.data['rider'] : null;
        if (added is Map) {
          selectedRider.value = Map<String, dynamic>.from(added);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[BookingController] addRider failed: $e');
    }
    return false;
  }

  /// Label shown on the "For me / For <name>" selector.
  String get riderLabel {
    final rider = selectedRider.value;
    if (rider == null) return 'For me';
    final name = (rider['name'] ?? rider['fullName'] ?? '').toString().trim();
    return name.isNotEmpty ? name : 'Rider';
  }

  // ─────────────────────────────
  // Fare estimates
  // ─────────────────────────────
  /// Loads vehicle/fare options for the current pickup→drop pair.
  ///
  /// When [silent] is true (used by the 3s auto-retry poll) the loading
  /// spinner / state transitions are skipped so the "no vehicle available"
  /// view stays put while we quietly re-check in the background.
  Future<void> loadFareEstimates({bool silent = false}) async {
    if (pickupLat.value == 0 || dropLat.value == 0) return;

    if (!silent) {
      state.value = BookingState.loadingFares;
      isLoading.value = true;
    }
    errorMessage.value = '';

    final response = await BookingApiService.getAllFareEstimates(
      pickupLat: pickupLat.value,
      pickupLng: pickupLng.value,
      dropLat: dropLat.value,
      dropLng: dropLng.value,
    );

    debugPrint('Fare estimates response: success=${response.success}, msg=${response.message}, data=${response.data}');

    if (response.success && response.data != null) {
      final estimates = response.data['estimates'] as List? ?? [];
      fareEstimates.value = estimates
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (estimates.isNotEmpty) {
        distanceKm.value =
            (estimates.first['distanceKm'] ?? 0).toDouble();
        durationMin.value =
            (estimates.first['durationMin'] ?? 0).toInt();
      }
      if (fareEstimates.isNotEmpty && selectedVehicleIndex.value < 0) {
        selectedVehicleIndex.value = 0;
      }
    }

    if (!silent) {
      state.value = BookingState.selectingVehicle;
      isLoading.value = false;
    }

    // No vehicle available → keep auto-retrying every 3s. Once vehicles show
    // up, stop the poll.
    if (fareEstimates.isEmpty) {
      _startFarePolling();
    } else {
      _fareTimer?.cancel();
      _fareTimer = null;
    }
  }

  /// Auto-retries [loadFareEstimates] every 3s while no vehicle is available,
  /// so the user never has to tap a "Retry" button. Self-cancels once a
  /// vehicle is found or the drop location is cleared.
  void _startFarePolling() {
    if (_fareTimer != null) return; // already polling
    _fareTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (dropLat.value == 0 || fareEstimates.isNotEmpty) {
        _fareTimer?.cancel();
        _fareTimer = null;
        return;
      }
      loadFareEstimates(silent: true);
    });
  }

  // ─────────────────────────────
  // Create booking
  // ─────────────────────────────
  Future<bool> createBooking({
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) async {
    if (nearbyDrivers.isEmpty) {
      errorMessage.value = 'No drivers available nearby. Please try again later.';
      return false;
    }
    if (selectedVehicleIndex.value < 0 ||
        selectedVehicleIndex.value >= fareEstimates.length) {
      return false;
    }
    final selected = fareEstimates[selectedVehicleIndex.value];
    final vehicleType = selected['vehicleType'] ?? {};
    final vehicleTypeId = vehicleType['_id'] ?? '';
    bookedVehicleType.value = (vehicleType['name'] ?? '').toString();

    state.value = BookingState.creatingBooking;
    isLoading.value = true;

    final response = await BookingApiService.createBooking(
      pickupAddress: pickupAddress.value,
      pickupLat: pickupLat.value,
      pickupLng: pickupLng.value,
      dropAddress: dropAddress.value,
      dropLat: dropLat.value,
      dropLng: dropLng.value,
      vehicleTypeId: vehicleTypeId.toString(),
      paymentMethod: paymentMethod.value,
      promoCode: promoCode.value.trim().isEmpty ? null : promoCode.value.trim(),
      riderId: selectedRider.value?['_id']?.toString(),
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );

    isLoading.value = false;

    if (response.success && response.data != null) {
      final booking = response.data['booking'] ?? response.data;
      bookingId.value = booking['_id'] ?? '';
      bookingOtp.value = booking['otp']?.toString() ?? '';
      bookingStatus.value = booking['status'] ?? 'SEARCHING';
      finalFare.value = (booking['finalFare'] ?? 0).toDouble();
      state.value = BookingState.searching;
      _startTrackingPolling();
      return true;
    }

    state.value = BookingState.selectingVehicle;
    return false;
  }

  // ─────────────────────────────
  // Cancel booking
  // ─────────────────────────────
  Future<bool> cancelBooking({String reason = 'Cancelled by user'}) async {
    if (bookingId.value.isEmpty) return false;

    isLoading.value = true;
    // Also cancel via socket for real-time notification
    SocketService().cancelRide(bookingId.value, reason: reason);

    final response = await BookingApiService.cancelBooking(
      bookingId.value,
      reason: reason,
    );
    isLoading.value = false;

    if (response.success) {
      _stopTrackingPolling();
      state.value = BookingState.cancelled;
      return true;
    }
    return false;
  }

  // ─────────────────────────────
  // Rate booking
  // ─────────────────────────────
  Future<bool> rateBooking(int rating, {String? feedback}) async {
    if (bookingId.value.isEmpty) return false;

    final response = await BookingApiService.rateBooking(
      bookingId.value,
      rating: rating,
      feedback: feedback,
    );
    return response.success;
  }

  // ─────────────────────────────
  // Tracking (poll-based fallback between socket pushes)
  // ─────────────────────────────
  void _startTrackingPolling() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (bookingId.value.isEmpty) return;
      final response =
          await BookingApiService.trackBooking(bookingId.value);
      if (response.success && response.data != null) {
        final driverLoc = response.data['driverLocation'];
        final eta = response.data['eta'];
        final booking = response.data['booking'];

        if (driverLoc != null) {
          driverLat.value = (driverLoc['latitude'] ?? 0).toDouble();
          driverLng.value = (driverLoc['longitude'] ?? 0).toDouble();
        }
        if (eta != null) {
          etaMinutes.value = (eta is int) ? eta : eta.toInt();
        }
        if (booking != null) {
          final status = booking['status'] ?? '';
          bookingStatus.value = status;
          _syncStateFromStatus(status);
        }
      }
    });
  }

  void _stopTrackingPolling() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  void _syncStateFromStatus(String status) {
    switch (status) {
      case 'SEARCHING':
        state.value = BookingState.searching;
        break;
      case 'ASSIGNED':
        state.value = BookingState.driverAssigned;
        break;
      case 'DRIVER_ARRIVED':
        state.value = BookingState.driverArrived;
        break;
      case 'PICKED':
      case 'IN_PROGRESS':
        state.value = BookingState.inProgress;
        break;
      case 'COMPLETED':
        state.value = BookingState.completed;
        _stopTrackingPolling();
        break;
      case 'CANCELLED':
        state.value = BookingState.cancelled;
        _stopTrackingPolling();
        break;
    }
  }

  // ─────────────────────────────
  // Reset for new booking
  // ─────────────────────────────
  void resetBooking({bool redetectLocation = false}) {
    _stopTrackingPolling();
    _nearbyTimer?.cancel();
    _fareTimer?.cancel();
    _fareTimer = null;
    state.value = BookingState.idle;
    bookingId.value = '';
    bookingOtp.value = '';
    bookingStatus.value = '';
    finalFare.value = 0;
    driverInfo.clear();
    driverLat.value = 0;
    driverLng.value = 0;
    driverHeading.value = 0;
    etaMinutes.value = 0;
    routePolyline.value = null;
    _lastRouteCallAt = null;
    _lastRouteCallDriverLat = null;
    _lastRouteCallDriverLng = null;
    fareEstimates.clear();
    selectedVehicleIndex.value = -1;
    dropAddress.value = '';
    dropLat.value = 0;
    dropLng.value = 0;
    searchResults.clear();
    nearbyDrivers.clear();
    errorMessage.value = '';
    if (redetectLocation) {
      pickupLat.value = 0;
      pickupLng.value = 0;
      pickupAddress.value = 'My current location';
      currentLocationLoaded.value = false;
      detectCurrentLocation();
    }
  }

  // ─────────────────────────────
  // Check for active booking on launch
  // ─────────────────────────────
  Future<bool> checkActiveBooking() async {
    final response = await BookingApiService.getActiveBooking();
    if (response.success && response.data != null) {
      final booking = response.data['booking'];
      if (booking != null) {
        bookingId.value = booking['_id'] ?? '';
        bookingOtp.value = booking['otp']?.toString() ?? '';
        bookingStatus.value = booking['status'] ?? '';
        finalFare.value = (booking['finalFare'] ?? 0).toDouble();
        pickupAddress.value = booking['pickup']?['address'] ?? '';
        pickupLat.value = (booking['pickup']?['lat'] ?? 0).toDouble();
        pickupLng.value = (booking['pickup']?['lng'] ?? 0).toDouble();
        dropAddress.value = booking['drop']?['address'] ?? '';
        dropLat.value = (booking['drop']?['lat'] ?? 0).toDouble();
        dropLng.value = (booking['drop']?['lng'] ?? 0).toDouble();

        final driver = booking['driverId'];
        if (driver != null && driver is Map) {
          final info = Map<String, dynamic>.from(driver);
          // Merge the booked vehicle's type (name/image) and plate so the
          // live-tracking card is fully backend-driven on a resumed session.
          final vt = booking['vehicleTypeId'];
          if (vt is Map) {
            info['vehicleName'] = vt['name'];
            info['vehicleImage'] = vt['image'];
            bookedVehicleType.value = (vt['name'] ?? '').toString();
          }
          if (booking['vehicleNumber'] != null) {
            info['vehicleNumber'] = booking['vehicleNumber'];
          }
          driverInfo.value = info;
        }

        _syncStateFromStatus(bookingStatus.value);
        if (state.value != BookingState.idle &&
            state.value != BookingState.completed &&
            state.value != BookingState.cancelled) {
          _startTrackingPolling();
          return true;
        }
      }
    }
    return false;
  }

  /// Masked driver phone: show only last 4 digits
  String get maskedDriverPhone {
    final phone = driverInfo['mobileNumber']?.toString() ?? '';
    if (phone.length <= 4) return phone;
    return '${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}';
  }
}
