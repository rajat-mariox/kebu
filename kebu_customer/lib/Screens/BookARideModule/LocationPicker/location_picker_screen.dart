import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';

/// Screen where user picks both pickup and drop location via text search.
/// After selecting both, the user proceeds to vehicle/fare selection.
class LocationPickerScreen extends StatefulWidget {
  final bool focusDrop;
  const LocationPickerScreen({super.key, this.focusDrop = false});
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final BookingController _bc = Get.find<BookingController>();
  final TextEditingController _pickupCtrl = TextEditingController();
  final TextEditingController _dropCtrl = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _dropFocus = FocusNode();

  bool _editingPickup = false; // which field is active for search results
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Pre-fill with actual detected address or fallback
    _pickupCtrl.text = _bc.pickupAddress.value.isNotEmpty
        ? _bc.pickupAddress.value
        : 'My current location';
    _dropCtrl.text = _bc.dropAddress.value;

    // Auto-focus drop field if requested
    if (widget.focusDrop) {
      _editingPickup = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_dropFocus);
      });
    }

    // If current location not yet detected, trigger it
    if (_bc.pickupLat.value == 0) {
      _bc.detectCurrentLocation().then((_) {
        if (mounted && _bc.pickupAddress.value.isNotEmpty) {
          _pickupCtrl.text = _bc.pickupAddress.value;
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _pickupFocus.dispose();
    _dropFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, bool isPickup) {
    _editingPickup = isPickup;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _bc.searchPlaces(query);
    });
  }

  Future<void> _onPlaceSelected(Map<String, dynamic> prediction) async {
    final placeId = prediction['placeId'] ?? '';
    final description = prediction['description'] ?? '';
    if (placeId.isEmpty) return;

    final details = await _bc.getPlaceDetails(placeId);
    if (details == null) return;
    final place = details['place'] ?? details;
    final lat = (place['lat'] ?? 0).toDouble();
    final lng = (place['lng'] ?? 0).toDouble();
    final address = place['address'] ?? description;

    if (_editingPickup) {
      _bc.setPickupLocation(address, lat, lng);
      _pickupCtrl.text = address;
      _pickupFocus.unfocus();
      FocusScope.of(context).requestFocus(_dropFocus);
    } else {
      _bc.setDropLocation(address, lat, lng);
      _dropCtrl.text = address;
      _dropFocus.unfocus();
    }
    _bc.searchResults.clear();

    // If both locations set, proceed
    if (_bc.pickupLat.value != 0 && _bc.dropLat.value != 0) {
      _proceed();
    }
  }

  void _proceed() {
    Navigator.pop(context, true); // signal that locations are set
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Set route',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Pickup / Drop inputs ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dot-line-dot indicator
                Padding(
                  padding: const EdgeInsets.only(top: 14, right: 10),
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: Colors.green, shape: BoxShape.circle),
                      ),
                      Container(
                          width: 2,
                          height: 40,
                          color: Colors.grey.shade300),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ),
                // Text fields
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _pickupCtrl,
                        focusNode: _pickupFocus,
                        onChanged: (v) => _onSearchChanged(v, true),
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Pickup location',
                          hintStyle: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.green)),
                          suffixIcon: _pickupCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _pickupCtrl.clear();
                                    _bc.setPickupLocation('', 0, 0);
                                    _bc.searchResults.clear();
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dropCtrl,
                        focusNode: _dropFocus,
                        onChanged: (v) => _onSearchChanged(v, false),
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Where to?',
                          hintStyle: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.grey),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.red)),
                          suffixIcon: _dropCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _dropCtrl.clear();
                                    _bc.setDropLocation('', 0, 0);
                                    _bc.searchResults.clear();
                                  },
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Search results / Quick picks ──
          Expanded(
            child: Obx(() {
              if (_bc.isSearching.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_bc.searchResults.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // Use current location
                    if (_bc.currentLocationLoaded.value)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade50,
                          child: const Icon(Icons.my_location, color: Colors.green, size: 20),
                        ),
                        title: Text('Use current location',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Obx(() => Text(
                            _bc.pickupAddress.value != 'My current location'
                                ? _bc.pickupAddress.value
                                : 'Detected via GPS',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                        onTap: () {
                          if (_editingPickup) {
                            _pickupCtrl.text = _bc.pickupAddress.value;
                            // pickup lat/lng already set
                            _pickupFocus.unfocus();
                            FocusScope.of(context).requestFocus(_dropFocus);
                          } else {
                            _bc.setDropLocation(
                              _bc.pickupAddress.value,
                              _bc.pickupLat.value,
                              _bc.pickupLng.value,
                            );
                            _dropCtrl.text = _bc.pickupAddress.value;
                            _dropFocus.unfocus();
                          }
                          if (_bc.pickupLat.value != 0 && _bc.dropLat.value != 0) {
                            _proceed();
                          }
                        },
                      ),
                    Divider(height: 1, color: Colors.grey.shade200),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                      child: Text('Search for a place',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
                    ),
                    Center(
                      child: Icon(Icons.search, size: 40, color: Colors.grey.shade300),
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _bc.searchResults.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final place = _bc.searchResults[index];
                  return ListTile(
                    leading: Icon(Icons.location_on,
                        color: HexColor('#FF6B35'), size: 22),
                    title: Text(
                      place['mainText'] ?? place['description'] ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      place['secondaryText'] ?? '',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _onPlaceSelected(place),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
