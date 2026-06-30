import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/parcel_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';
import 'package:kebu_customer/Services/maps_api_service.dart';
import 'package:kebu_customer/Services/user_api_service.dart';
import 'package:geolocator/geolocator.dart';

class LoadingPointScreen extends StatefulWidget {
  // Title shown in the header ("Loading Point" or "Unloading Point").
  // On Confirm the screen pops with {lat, lng, address} of the chosen point.
  final String title;
  const LoadingPointScreen({super.key, this.title = 'Loading Point'});

  @override
  State<LoadingPointScreen> createState() => _LoadingPointScreenState();
}

class _LoadingPointScreenState extends State<LoadingPointScreen> {
  static final Color _brandRed = HexColor("#E53935");

  String selectedAddress = 'Detecting location...';
  double selectedLat = 0;
  double selectedLng = 0;
  bool _detecting = false;
  List<dynamic> savedAddresses = [];

  // Manual address search (Google Places).
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _detectCurrentLocation();
    _loadAddresses();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _detecting = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }
      if (permission == LocationPermission.denied) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final res = await MapsApiService.reverseGeocode(
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (mounted) {
        setState(() {
          selectedLat = pos.latitude;
          selectedLng = pos.longitude;
          selectedAddress = (res.success && res.data != null)
              ? (res.data['address'] ??
                  res.data['display_name'] ??
                  '${pos.latitude}, ${pos.longitude}')
              : '${pos.latitude}, ${pos.longitude}';
          _searchCtrl.text = selectedAddress;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _loadAddresses() async {
    final response = await UserApiService.getAddresses();
    if (response.success && response.data != null && mounted) {
      setState(() {
        savedAddresses = response.data['addresses'] ?? [];
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final res = await MapsApiService.searchPlaces(
      query,
      lat: selectedLat != 0 ? selectedLat : null,
      lng: selectedLng != 0 ? selectedLng : null,
    );
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      if (res.success && res.data != null) {
        final preds = res.data['predictions'] as List? ?? [];
        _results =
            preds.map((p) => Map<String, dynamic>.from(p as Map)).toList();
      } else {
        _results = [];
      }
    });
  }

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    final placeId = (prediction['placeId'] ?? '').toString();
    if (placeId.isEmpty) return;
    FocusScope.of(context).unfocus();
    final res = await MapsApiService.getPlaceDetails(placeId);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final place = res.data['place'] ?? res.data;
      final lat = (place['lat'] ?? 0).toDouble();
      final lng = (place['lng'] ?? 0).toDouble();
      final address =
          (place['address'] ?? prediction['description'] ?? '').toString();
      setState(() {
        selectedLat = lat;
        selectedLng = lng;
        selectedAddress = address;
        _searchCtrl.text = address;
        _results = [];
      });
    }
  }

  void _selectSaved(dynamic addr) {
    final lat = (addr['lat'] ?? addr['latitude'] ?? 0).toDouble();
    final lng = (addr['lng'] ?? addr['longitude'] ?? 0).toDouble();
    final address = (addr['address'] ?? '').toString();
    setState(() {
      if (lat != 0) selectedLat = lat;
      if (lng != 0) selectedLng = lng;
      selectedAddress = address;
      _searchCtrl.text = address;
      _results = [];
    });
  }

  bool get _canConfirm => selectedLat != 0 && selectedLng != 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          sendParcelAppBar(
            height: 120,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 55, left: 15, right: 15),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 20, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const NotificationIconButton(),
                ],
              ),
            ),
          ),

          // ── Manual search box ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search ${widget.title.toLowerCase()} address",
                hintStyle:
                    GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _brandRed),
                ),
              ),
            ),
          ),

          // ── Map ──
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: selectedLat != 0
                      ? GoogleMapWidget(
                          pickupLat: selectedLat,
                          pickupLng: selectedLng,
                          centerLat: selectedLat,
                          centerLng: selectedLng,
                          zoom: 15,
                        )
                      : Image.asset("assets/map_view.png", fit: BoxFit.cover),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: GestureDetector(
                    onTap: _detecting ? null : _detectCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: HexColor("#FF3B59"),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _detecting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.my_location,
                                  size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          const Text("Use live location",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Results / selected address / saved addresses ──
          Expanded(child: _middle()),

          // ── Confirm ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _canConfirm ? _brandRed : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _canConfirm
                    ? () {
                        Navigator.pop(context, {
                          'lat': selectedLat,
                          'lng': selectedLng,
                          'address': selectedAddress,
                        });
                      }
                    : null,
                child: Text(
                  'Confirm',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _middle() {
    if (_isSearching) {
      return Center(child: CircularProgressIndicator(color: _brandRed));
    }
    // Search results take priority.
    if (_results.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _results.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (_, i) {
          final p = _results[i];
          return ListTile(
            leading: Icon(Icons.location_on, color: _brandRed, size: 22),
            title: Text(
              (p['mainText'] ?? p['description'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              (p['secondaryText'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            onTap: () => _selectPrediction(p),
          );
        },
      );
    }
    // Default: chosen address + any saved addresses.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: [
        Row(
          children: [
            Image.asset("assets/star_with_location.png",
                height: 28, width: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedAddress,
                style: const TextStyle(color: Colors.black, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (savedAddresses.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text("Saved addresses",
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          ...savedAddresses.map((a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bookmark_border, size: 22),
                title: Text(
                  (a['address'] ?? '').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                onTap: () => _selectSaved(a),
              )),
        ],
      ],
    );
  }
}
