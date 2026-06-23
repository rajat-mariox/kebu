import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/BookARideModule/LocationPicker/location_picker_screen.dart';
import 'package:kebu_customer/Screens/BookARideModule/RideFindingScreen/ride_finding_screen.dart';
import 'package:kebu_customer/Screens/BookARideModule/RidePaymentScreen/ride_payment_screen.dart';
import 'package:kebu_customer/Utils/ApiClient/api_client.dart';
import 'package:fluttertoast/fluttertoast.dart';

class BookARideScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const BookARideScreen({super.key, this.onBack});
  @override
  State<BookARideScreen> createState() => _BookARideScreenState();
}

class _BookARideScreenState extends State<BookARideScreen>
    with WidgetsBindingObserver {
  final BookingController _bc = Get.find<BookingController>();
  final TextEditingController _promoController = TextEditingController();
  GoogleMapController? _mapController;

  static final Color _kYellow = HexColor("#FFD546");

  /// Recenter the map to the user's live GPS location.
  Future<void> _goToMyLocation() async {
    await _bc.detectCurrentLocation();
    final lat = _bc.pickupLat.value;
    final lng = _bc.pickupLng.value;
    if (lat != 0 && lng != 0) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
      );
    }
  }

  /// Default vehicle images and labels (fallback when server has no image)
  final Map<String, Map<String, dynamic>> _vehicleDefaults = {
    'bike': {'image': 'assets/bike.png', 'seats': '1 Seat'},
    'rickshaw': {'image': 'assets/ricsha.png', 'seats': '3 Seats'},
    'auto': {'image': 'assets/ricsha.png', 'seats': '3 Seats'},
    'normal': {'image': 'assets/premium_car.png', 'seats': '4 Seats'},
    'economy': {'image': 'assets/economy_car.png', 'seats': '5 Seats'},
    'comfort': {'image': 'assets/economy_car.png', 'seats': '6 Seats'},
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Always default the pickup to the user's live location on entering the
    // booking screen; they can still drag the map to move the pickup after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCurrentLocation();
    });

    // If locations already chosen, load fares
    if (_bc.pickupLat.value != 0 &&
        _bc.dropLat.value != 0 &&
        _bc.fareEstimates.isEmpty) {
      _bc.loadFareEstimates();
    }

    // Recent destinations + "Book for others" riders
    _bc.loadRecentPlaces();
    _bc.loadRiders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _promoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_bc.pickupLat.value == 0 || !_bc.currentLocationLoaded.value)) {
      _ensureCurrentLocation();
    }
  }

  Future<void> _ensureCurrentLocation() async {
    await _bc.detectCurrentLocation();
    final lat = _bc.pickupLat.value;
    final lng = _bc.pickupLng.value;
    if (lat != 0 && lng != 0) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openLocationPicker({bool focusDrop = false}) async {
    final result =
        await pushTo(context, LocationPickerScreen(focusDrop: focusDrop));
    if (result == true && mounted) {
      _bc.loadFareEstimates();
    }
  }

  /// Tapping a recent destination sets it as the drop and loads fares so the
  /// vehicle options appear in place of the recent list.
  void _onRecentPlaceTap(Map<String, dynamic> place) {
    final address = (place['address'] ?? '').toString();
    final lat = (place['lat'] ?? 0).toDouble();
    final lng = (place['lng'] ?? 0).toDouble();
    if (lat == 0 || lng == 0) return;
    _bc.setDropLocation(address, lat, lng);
    _bc.loadFareEstimates();
  }

  Future<void> _bookNow() async {
    // No destination yet → send the user to pick one first.
    if (_bc.dropLat.value == 0) {
      _openLocationPicker(focusDrop: true);
      return;
    }
    if (_bc.nearbyDrivers.isEmpty) {
      Fluttertoast.showToast(
          msg: 'No drivers available nearby. Please try again later.');
      return;
    }
    if (_bc.selectedVehicleIndex.value < 0) {
      Fluttertoast.showToast(msg: 'Please select a vehicle type');
      return;
    }

    // UPI / Online → open the payments screen and pay FIRST. The booking is
    // created there only after the payment is verified, then the ride is
    // driven. Cash → book straight away (driver collects on ride completion).
    if (_bc.paymentMethod.value == 'UPI') {
      final amount = _selectedFare;
      if (amount <= 0) {
        Fluttertoast.showToast(msg: 'Unable to determine fare. Please retry.');
        return;
      }
      pushTo(context, RidePaymentScreen(amount: amount));
      return;
    }

    await _createRideBooking();
  }

  /// Cash flow: create the booking and move to the driver-search screen.
  Future<void> _createRideBooking() async {
    final success = await _bc.createBooking();
    if (success && mounted) {
      pushTo(context, RideFindingScreen(bookingId: _bc.bookingId.value));
    } else {
      Fluttertoast.showToast(
          msg: _bc.errorMessage.value.isNotEmpty
              ? _bc.errorMessage.value
              : 'Failed to create booking');
    }
  }

  /// Fare shown for the currently selected vehicle — the amount the user pays
  /// upfront for an online (UPI) booking.
  double get _selectedFare {
    final i = _bc.selectedVehicleIndex.value;
    if (i < 0 || i >= _bc.fareEstimates.length) return 0;
    final est = _bc.fareEstimates[i];
    return ((est['finalFare'] ?? est['totalFare'] ?? 0) as num).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Full-screen Uber-style map — drag the sheet down to reveal more.
          Positioned.fill(child: _mapSection(screenH)),

          // Yellow header over the map.
          Positioned(top: 0, left: 0, right: 0, child: _header(topInset)),

          // Live-location ("my location") button at the top of the map.
          Positioned(
            top: topInset + 70,
            right: 16,
            child: GestureDetector(
              onTap: _goToMyLocation,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location,
                    color: Color(0xFF3B65DB), size: 22),
              ),
            ),
          ),

          // Draggable "Where are you going" sheet.
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.30,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 20,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      _content(),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header (yellow) — back, title, "For me" pill
  // ─────────────────────────────────────────────
  Widget _header(double topInset) {
    return Container(
      color: _kYellow,
      padding: EdgeInsets.only(top: topInset + 8, left: 12, right: 16, bottom: 14),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.pop(context);
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            "Book a cab",
            style: GoogleFonts.inter(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _riderSelector(),
        ],
      ),
    );
  }

  Widget _riderSelector() {
    return Obx(() => InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: _showRiderPicker,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF3B3B3B)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Text(
                    _bc.riderLabel,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black),
              ],
            ),
          ),
        ));
  }

  void _showRiderPicker() {
    // Local selection applied only when "Done" is tapped. `null` => Myself.
    Map<String, dynamic>? tempSelected = _bc.selectedRider.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Obx(() {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: title + close
                      Row(
                        children: [
                          Text("Booking ride for",
                              style: GoogleFonts.poppins(
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.pop(sheetCtx),
                            child: const Icon(Icons.close, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Myself
                      _riderRow(
                        name: 'Myself',
                        selected: tempSelected == null,
                        onTap: () => setSheetState(() => tempSelected = null),
                      ),
                      // Riders from backend
                      ..._bc.riders.map((rider) {
                        final name =
                            (rider['name'] ?? rider['fullName'] ?? 'Rider')
                                .toString();
                        final selected = tempSelected != null &&
                            tempSelected!['_id'] == rider['_id'];
                        return _riderRow(
                          name: name,
                          selected: selected,
                          onTap: () =>
                              setSheetState(() => tempSelected = rider),
                        );
                      }),

                      const SizedBox(height: 4),
                      // Add new rider
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showAddRiderDialog(sheetCtx),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.person_add_alt,
                                  size: 22, color: Color(0xFF3B65DB)),
                              const SizedBox(width: 14),
                              Text("Add new rider",
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF3B65DB))),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      // Info note
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Contact name won't be shared with captain",
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: const Color(0xFF5A5A5A)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Done
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            _bc.selectedRider.value = tempSelected;
                            Navigator.pop(sheetCtx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kYellow,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text("Done",
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            });
          },
        );
      },
    );
  }

  /// One "Booking ride for" row — avatar + name + radio dot.
  Widget _riderRow({
    required String name,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3B3B3B), width: 1.5),
              ),
              child: const Icon(Icons.person, size: 20, color: Color(0xFF3B3B3B)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(name,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black)),
            ),
            // Radio dot
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.green : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Add-new-rider dialog — name + phone → POST /customer/riders.
  void _showAddRiderDialog(BuildContext sheetCtx) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text("Add new rider",
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: GoogleFonts.poppins(fontSize: 14),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone number',
                      labelStyle: GoogleFonts.poppins(fontSize: 14),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogCtx),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kYellow,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          if (name.isEmpty || phone.isEmpty) {
                            Fluttertoast.showToast(
                                msg: 'Enter name and phone number');
                            return;
                          }
                          // Capture before the await so we don't use a
                          // BuildContext across the async gap. Dialog + sheet
                          // share the same root navigator.
                          final navigator = Navigator.of(sheetCtx);
                          setDialogState(() => saving = true);
                          final ok = await _bc.addRider(name, phone);
                          if (!mounted) return;
                          if (ok) {
                            navigator.pop(); // close dialog
                            navigator.pop(); // close sheet (selection applied)
                            Fluttertoast.showToast(msg: 'Rider added');
                          } else {
                            setDialogState(() => saving = false);
                            Fluttertoast.showToast(msg: 'Failed to add rider');
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : Text('Add',
                          style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontWeight: FontWeight.w500)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Map section + "Get a cab in 5 mins" tooltip
  // ─────────────────────────────────────────────
  Widget _mapSection(double screenH) {
    return Stack(
      children: [
        // Uber-style live map: shows all nearby driver vehicles (real vehicle
        // PNG icons); dragging the map re-anchors the pickup (center pin).
        Positioned.fill(
          child: Obx(() => GoogleMapWidget(
                centerLat: _bc.pickupLat.value != 0 ? _bc.pickupLat.value : null,
                centerLng: _bc.pickupLng.value != 0 ? _bc.pickupLng.value : null,
                pickupLat: _bc.pickupLat.value,
                pickupLng: _bc.pickupLng.value,
                nearbyVehicles: _bc.nearbyDrivers.toList(),
                zoom: _bc.pickupLat.value != 0 ? 15 : 12,
                showMyLocation: _bc.currentLocationLoaded.value,
                liteModeEnabled: false,
                interactive: true,
                showPickupMarker: false,
                showZoomButtons: false,
                // Shift the focal point above the bottom sheet so the center
                // pin lands in the visible map area.
                padding: EdgeInsets.only(bottom: screenH * 0.42),
                onMapCreated: (c) => _mapController = c,
                onCameraIdle: (center) => _bc.updatePickupFromMap(
                    center.latitude, center.longitude),
              )),
        ),
        // Center pickup indicator (aligned with the padded focal point):
        // soft pulse + pin + "Get a cab in X mins" tooltip.
        Align(
          alignment: const Alignment(0, -0.42),
          child: IgnorePointer(
            child: Obx(() =>
                _PickupCenterIndicator(etaMinutes: _bc.cabEtaMinutes.value)),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // White content sheet
  // ─────────────────────────────────────────────
  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Where are you going\ntoday?",
          style: GoogleFonts.poppins(
            fontSize: 24,
            height: 1.33,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 24),

        // Pickup / Drop stepper
        Obx(() => _buildLocationDisplay()),

        const SizedBox(height: 24),

        // Recent places (initial) OR vehicle options (once a drop is set)
        Obx(() {
          if (_bc.dropLat.value == 0) {
            return _recentPlacesSection();
          }
          return _vehicleSection();
        }),

        const SizedBox(height: 20),

        // Book Now
        Obx(() {
          final hasDrop = _bc.dropLat.value != 0;
          final canBook = hasDrop &&
              _bc.fareEstimates.isNotEmpty &&
              !_bc.isLoading.value &&
              _bc.nearbyDrivers.isNotEmpty;
          return SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (!hasDrop || canBook) && !_bc.isLoading.value
                  ? _bookNow
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kYellow,
                disabledBackgroundColor: _kYellow.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _bc.isLoading.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(
                      "Book Now",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
            ),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Payment method dropdown (Cash / UPI)
  // ─────────────────────────────────────────────
  static const Map<String, ({String label, IconData icon})> _paymentOptions = {
    'CASH': (label: 'Cash ', icon: Icons.payments_outlined),
    'UPI': (
      label: 'UPI / Online ',
      icon: Icons.account_balance_wallet_outlined,
    ),
  };

  Widget _paymentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Payment method",
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Obx(() {
          final selected = _bc.paymentMethod.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _paymentOptions.containsKey(selected) ? selected : 'CASH',
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: _paymentOptions.entries
                    .map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Row(
                            children: [
                              Icon(e.value.icon,
                                  size: 20, color: Colors.grey.shade700),
                              const SizedBox(width: 10),
                              Text(
                                e.value.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) _bc.paymentMethod.value = val;
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Recent places list
  // ─────────────────────────────────────────────
  Widget _recentPlacesSection() {
    if (_bc.isLoadingRecent.value && _bc.recentPlaces.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_bc.recentPlaces.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Your recent destinations will appear here',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recent places",
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5A5A5A))),
              GestureDetector(
                onTap: _bc.clearRecentPlaces,
                child: Text("Clear All",
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF4BE05))),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0x33DADADA)),
        const SizedBox(height: 6),
        ..._bc.recentPlaces.map(_recentPlaceTile),
      ],
    );
  }

  Widget _recentPlaceTile(Map<String, dynamic> place) {
    final name = (place['name'] ?? 'Place').toString();
    final address = (place['address'] ?? '').toString();
    final lat = (place['lat'] ?? 0).toDouble();
    final lng = (place['lng'] ?? 0).toDouble();
    final dist = _bc.distanceFromPickupKm(lat, lng);

    return InkWell(
      onTap: () => _onRecentPlaceTap(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.access_time,
                  size: 20, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5A5A5A))),
                  const SizedBox(height: 2),
                  Text(address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.5,
                          color: const Color(0xFFB8B8B8))),
                ],
              ),
            ),
            if (dist != null) ...[
              const SizedBox(width: 8),
              Text("${dist.toStringAsFixed(1)}km",
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5A5A5A))),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Vehicle / fare options (shown once a drop is set)
  // ─────────────────────────────────────────────
  Widget _vehicleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() {
          if (_bc.isLoading.value && _bc.fareEstimates.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (_bc.fareEstimates.isEmpty) {
            // No vehicle available — keep auto-retrying the API every 3s
            // (handled in the controller). No manual retry button.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('🚕💨', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'Sorry, no vehicle available',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hang tight — we\'re looking for a ride near you…',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            children: List.generate(_bc.fareEstimates.length, (index) {
              return Obx(() {
                final est = _bc.fareEstimates[index];
                final isSelected = _bc.selectedVehicleIndex.value == index;
                final vt = est['vehicleType'] ?? {};
                final name = (vt['name'] ?? 'Vehicle').toString();
                final nameLower = name.toLowerCase();
                final defaults = _vehicleDefaults[nameLower] ?? {};
                final image = _resolveVehicleImage(vt, defaults);
                final fare = est['finalFare'] ?? est['totalFare'] ?? 0;
                final duration = est['durationMin'] ?? 0;
                final distanceRaw = est['distanceKm'];
                final distanceText = distanceRaw is num
                    ? distanceRaw.toStringAsFixed(1)
                    : null;
                final seatsCount = (vt['maxSeats'] is num)
                    ? (vt['maxSeats'] as num).toInt()
                    : null;
                final seats = seatsCount != null
                    ? '$seatsCount ${seatsCount == 1 ? 'Seat' : 'Seats'}'
                    : (defaults['seats'] ?? '4 Seats');
                final isPopular = nameLower == 'normal';

                return GestureDetector(
                  onTap: () => _bc.selectedVehicleIndex.value = index,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFFF8E1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _kYellow : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              _vehicleImage(image),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text('₹$fare',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(width: 10),
                                          _infoIcon(Icons.access_time,
                                              '$duration min'),
                                          if (distanceText != null) ...[
                                            const SizedBox(width: 10),
                                            _infoIcon(Icons.route,
                                                '$distanceText km'),
                                          ],
                                          const SizedBox(width: 10),
                                          _infoIcon(
                                              Icons.person_outline, seats),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _vehicleRadio(isSelected),
                            ],
                          ),
                        ),
                        if (isPopular)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              child: Text("Popular",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              });
            }),
          );
        }),
        const SizedBox(height: 16),
        _paymentSelector(),
        const SizedBox(height: 4),
        _promoCodeField(),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Pickup / Drop stepper
  // ─────────────────────────────────────────────
  Widget _buildLocationDisplay() {
    final hasDrop = _bc.dropAddress.value.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 6),
            // Pickup marker (outlined yellow circle)
            Container(
              height: 18,
              width: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kYellow, width: 5),
              ),
            ),
            Container(height: 56, width: 1.5, color: Colors.grey.shade300),
            // Drop marker (diamond)
            Transform.rotate(
              angle: 0.785398, // 45°
              child: Container(
                height: 14,
                width: 14,
                decoration: BoxDecoration(
                  color: hasDrop ? Colors.amber.shade600 : Colors.transparent,
                  border: Border.all(color: _kYellow, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openLocationPicker(focusDrop: false),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Pick-up",
                            style: GoogleFonts.balooBhai2(
                                fontSize: 14, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(
                            _bc.pickupAddress.value.isNotEmpty
                                ? _bc.pickupAddress.value
                                : 'My current location',
                            style: GoogleFonts.balooBhai2(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openLocationPicker(focusDrop: true),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Drop off (optional)",
                            style: GoogleFonts.balooBhai2(
                                fontSize: 14, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(
                            hasDrop
                                ? _bc.dropAddress.value
                                : 'Tap to set destination',
                            style: GoogleFonts.balooBhai2(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: hasDrop
                                    ? const Color(0xFF475569)
                                    : const Color(0xFF94A3B8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.grey),
      ],
    );
  }

  Widget _promoCodeField() {
    return Obx(() {
      final applied = _bc.promoCode.value.isNotEmpty;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: applied ? Colors.amber.shade600 : Colors.grey.shade300,
            width: applied ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer_outlined,
                size: 18,
                color: applied ? Colors.amber.shade700 : Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _promoController,
                enabled: !applied,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: applied ? _bc.promoCode.value : 'Enter promo code',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: applied ? Colors.black87 : Colors.grey.shade500,
                    fontWeight: applied ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                style:
                    GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () {
                if (applied) {
                  _bc.promoCode.value = '';
                  _promoController.clear();
                } else {
                  final code = _promoController.text.trim().toUpperCase();
                  if (code.isEmpty) return;
                  _bc.promoCode.value = code;
                  Fluttertoast.showToast(
                      msg: 'Promo $code will be applied at booking');
                }
              },
              child: Text(
                applied ? 'Remove' : 'Apply',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: applied ? Colors.redAccent : Colors.amber.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Custom radio matching Figma — filled yellow with a white center when
  /// selected, hollow grey ring otherwise.
  Widget _vehicleRadio(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _kYellow : Colors.transparent,
        border: Border.all(
          color: selected ? _kYellow : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  Widget _infoIcon(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _vehicleImage(String image) {
    final isRemote = image.startsWith('http://') || image.startsWith('https://');

    if (isRemote) {
      return Image.network(
        image,
        height: 40,
        width: 50,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 40),
      );
    }

    return Image.asset(
      image,
      height: 40,
      width: 50,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 40),
    );
  }

  String _resolveVehicleImage(
    Map<String, dynamic> vehicleType,
    Map<String, dynamic> defaults,
  ) {
    final rawImage = [
      vehicleType['image'],
      vehicleType['imageUrl'],
      vehicleType['icon'],
    ]
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere(
          (value) => value.isNotEmpty && value.toLowerCase() != 'null',
          orElse: () => '',
        );

    if (rawImage.isNotEmpty) {
      return _normalizeImageUrl(rawImage);
    }

    return (defaults['image']?.toString().trim().isNotEmpty ?? false)
        ? defaults['image'].toString()
        : 'assets/premium_car.png';
  }

  String _normalizeImageUrl(String image) {
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }

    final baseUri = Uri.parse(ApiClient.baseUrl);
    final origin =
        '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';

    if (image.startsWith('/')) {
      return '$origin$image';
    }

    return '$origin/$image';
  }
}

/// Uber-style center pickup indicator: soft pulse rings + a pin on a white
/// base, with the "Get a cab in 5 mins" pill floating above it.
class _PickupCenterIndicator extends StatelessWidget {
  final int? etaMinutes;
  const _PickupCenterIndicator({this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3B65DB);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CabEtaTooltip(etaMinutes: etaMinutes),
        const SizedBox(height: 2),
        SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft pulse rings
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blue.withValues(alpha: 0.08),
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blue.withValues(alpha: 0.14),
                ),
              ),
              // White base + blue pin
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on, color: blue, size: 26),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The blue "Get a cab in X mins" pill with the downward pointer, centered on
/// the map over the pickup. The minutes come from the backend ETA.
class _CabEtaTooltip extends StatelessWidget {
  final int? etaMinutes;
  const _CabEtaTooltip({this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    final label = etaMinutes != null
        ? 'Get a cab in $etaMinutes ${etaMinutes == 1 ? 'min' : 'mins'}'
        : 'Finding cabs near you';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF3B65DB),
            borderRadius: BorderRadius.circular(92),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Pointer
        CustomPaint(
          size: const Size(12, 7),
          painter: _TrianglePainter(const Color(0xFF3B65DB)),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
