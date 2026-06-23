import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';
import 'package:kebu_customer/Screens/Screens/SavedAddresses/Controller/address_controller.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';

class AddAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? existingAddress;

  const AddAddressScreen({super.key, this.existingAddress});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final AddressController _ac = Get.find<AddressController>();

  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _houseNoCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCodeCtrl = TextEditingController();

  String _addressType = 'Home';
  Timer? _debounce;
  bool get _isEditing => widget.existingAddress != null;

  @override
  void initState() {
    super.initState();
    _ac.resetSelection();

    if (_isEditing) {
      final addr = widget.existingAddress!;
      _fullNameCtrl.text = addr['fullName'] ?? '';
      _mobileCtrl.text = addr['mobileNumber'] ?? '';
      _houseNoCtrl.text = addr['houseNo'] ?? '';
      _areaCtrl.text = addr['area'] ?? '';
      _cityCtrl.text = addr['city'] ?? '';
      _stateCtrl.text = addr['state'] ?? '';
      _pinCodeCtrl.text = (addr['pinCode'] ?? '').toString();
      _addressType = addr['addressType'] ?? 'Home';
      _ac.selectedLat.value = (addr['latitude'] ?? 0).toDouble();
      _ac.selectedLng.value = (addr['longitude'] ?? 0).toDouble();
      _ac.selectedAddress.value = addr['address'] ?? '';
    } else {
      // Auto-fill mobile number from user profile
      if (Prefs.mobile_number.isNotEmpty) {
        _mobileCtrl.text = Prefs.mobile_number;
      }
      // Detect current location and auto-fill address fields
      _ac.detectCurrentLocation().then((_) {
        if (mounted) _fillFromReverseGeocode();
      });
    }

    // Listen for location changes (when user picks a place from search)
    ever(_ac.reverseArea, (_) {
      if (mounted) _fillFromReverseGeocode();
    });
  }

  void _fillFromReverseGeocode() {
    if (_ac.reverseHouseNo.value.isNotEmpty && _houseNoCtrl.text.isEmpty) {
      _houseNoCtrl.text = _ac.reverseHouseNo.value;
    }
    if (_ac.reverseArea.value.isNotEmpty && _areaCtrl.text.isEmpty) {
      _areaCtrl.text = _ac.reverseArea.value;
    }
    if (_ac.reverseCity.value.isNotEmpty && _cityCtrl.text.isEmpty) {
      _cityCtrl.text = _ac.reverseCity.value;
    }
    if (_ac.reverseState.value.isNotEmpty && _stateCtrl.text.isEmpty) {
      _stateCtrl.text = _ac.reverseState.value;
    }
    if (_ac.reversePinCode.value.isNotEmpty && _ac.reversePinCode.value != '0' && _pinCodeCtrl.text.isEmpty) {
      _pinCodeCtrl.text = _ac.reversePinCode.value;
    }
    _fillFromSelectedAddressFallback();
    setState(() {});
  }

  void _fillFromSelectedAddressFallback() {
    final address = _ac.selectedAddress.value.trim();
    if (address.isEmpty) return;

    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (_houseNoCtrl.text.isEmpty && parts.isNotEmpty) {
      _houseNoCtrl.text = parts.first;
    }

    if (_areaCtrl.text.isEmpty && parts.length > 1) {
      _areaCtrl.text = parts[1];
    }

    // Google formatted addresses in India are typically:
    //   "<house>, <area>, <city>, <state> <pin>, <country>"
    // The country is usually the last segment, "<state> <pin>" the second-last,
    // and the city sits in the third-from-last position.
    if (_cityCtrl.text.isEmpty && parts.length >= 3) {
      _cityCtrl.text = parts[parts.length - 3];
    }

    if (parts.length >= 2) {
      final statePinPart = parts[parts.length - 2];
      final pinMatch = RegExp(r'(\d{6})').firstMatch(statePinPart);
      final stateOnly = statePinPart.replaceAll(RegExp(r'\d'), '').trim();

      if (_pinCodeCtrl.text.isEmpty && pinMatch != null) {
        _pinCodeCtrl.text = pinMatch.group(1) ?? '';
      }

      if (_stateCtrl.text.isEmpty && stateOnly.isNotEmpty) {
        _stateCtrl.text = stateOnly;
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _fullNameCtrl.dispose();
    _mobileCtrl.dispose();
    _houseNoCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCodeCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _ac.searchPlaces(query);
    });
  }

  Future<void> _onPlaceSelected(Map<String, dynamic> prediction) async {
    final success = await _ac.selectPlace(prediction);
    if (success) {
      _searchCtrl.clear();
      FocusScope.of(context).unfocus();
      // Overwrite form fields with new location data
      _houseNoCtrl.text = _ac.reverseHouseNo.value;
      _areaCtrl.text = _ac.reverseArea.value;
      _cityCtrl.text = _ac.reverseCity.value;
      _stateCtrl.text = _ac.reverseState.value;
      if (_ac.reversePinCode.value.isNotEmpty && _ac.reversePinCode.value != '0') {
        _pinCodeCtrl.text = _ac.reversePinCode.value;
      }
      _fillFromSelectedAddressFallback();
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final pinCode = int.tryParse(_pinCodeCtrl.text.trim()) ?? 0;
    if (pinCode <= 0) return;

    bool success;
    if (_isEditing) {
      success = await _ac.updateAddress(
        id: widget.existingAddress!['_id'],
        fullName: _fullNameCtrl.text.trim(),
        mobileNumber: _mobileCtrl.text.trim(),
        houseNo: _houseNoCtrl.text.trim(),
        area: _areaCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        pinCode: pinCode,
        addressType: _addressType,
        latitude: _ac.selectedLat.value != 0 ? _ac.selectedLat.value : null,
        longitude: _ac.selectedLng.value != 0 ? _ac.selectedLng.value : null,
      );
    } else {
      success = await _ac.addAddress(
        fullName: _fullNameCtrl.text.trim(),
        mobileNumber: _mobileCtrl.text.trim(),
        houseNo: _houseNoCtrl.text.trim(),
        area: _areaCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        pinCode: pinCode,
        addressType: _addressType,
        latitude: _ac.selectedLat.value != 0 ? _ac.selectedLat.value : null,
        longitude: _ac.selectedLng.value != 0 ? _ac.selectedLng.value : null,
      );
    }

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // App bar
          commonAppBar(
            height: 100,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 50, left: 15, right: 15),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(_isEditing ? "Edit Address" : "Add Address",
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ),
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Search bar ──
                  Text("Search Location",
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: "Search for area, street name...",
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 22),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),

                  // ── Search results ──
                  Obx(() {
                    if (_ac.searchResults.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _ac.searchResults.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) {
                          final place = _ac.searchResults[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.location_on_outlined,
                                color: Colors.grey.shade500, size: 20),
                            title: Text(
                                place['mainText'] ??
                                    place['description'] ??
                                    '',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            subtitle: Text(
                                place['secondaryText'] ?? '',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            onTap: () => _onPlaceSelected(place),
                          );
                        },
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // ── Map preview ──
                  Obx(() {
                    final lat = _ac.selectedLat.value;
                    final lng = _ac.selectedLng.value;
                    return Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: GoogleMapWidget(
                          centerLat: lat != 0 ? lat : null,
                          centerLng: lng != 0 ? lng : null,
                          pickupLat: lat != 0 ? lat : null,
                          pickupLng: lng != 0 ? lng : null,
                          zoom: lat != 0 ? 16 : 12,
                          showMyLocation: lat != 0 && lng != 0,
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  
                  // ── Current address + re-detect button ──
                  Row(
                    children: [
                      Expanded(
                        child: Obx(() => Text(
                            _ac.selectedAddress.value.isNotEmpty
                                ? _ac.selectedAddress.value
                                : 'Detecting location...',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _ac.resetSelection();
                          _houseNoCtrl.clear();
                          _areaCtrl.clear();
                          _cityCtrl.clear();
                          _stateCtrl.clear();
                          _pinCodeCtrl.clear();
                          _ac.detectCurrentLocation().then((_) {
                            if (mounted) {
                              _houseNoCtrl.text = _ac.reverseHouseNo.value;
                              _areaCtrl.text = _ac.reverseArea.value;
                              _cityCtrl.text = _ac.reverseCity.value;
                              _stateCtrl.text = _ac.reverseState.value;
                              if (_ac.reversePinCode.value.isNotEmpty && _ac.reversePinCode.value != '0') {
                                _pinCodeCtrl.text = _ac.reversePinCode.value;
                              }
                              _fillFromSelectedAddressFallback();
                              setState(() {});
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: HexColor("#FF3B59"),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.my_location, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text("My Location",
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Address type ──
                  Text("Address Type",
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 10),
                  Row(
                    children: ['Home', 'Work', 'Other'].map((type) {
                      final isActive = _addressType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _ac.getAddressTypeIcon(type),
                                size: 16,
                                color:
                                    isActive ? Colors.black : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(type),
                            ],
                          ),
                          selected: isActive,
                          selectedColor: HexColor("#FFD546"),
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isActive
                                  ? Colors.black
                                  : Colors.grey.shade600),
                          onSelected: (_) =>
                              setState(() => _addressType = type),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isActive
                                  ? HexColor("#FFD546")
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── Form fields ──
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildField("Full Name", _fullNameCtrl,
                            hint: "Enter full name",
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Full name is required';
                              if (v.trim().length < 2) return 'Name must be at least 2 characters';
                              if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(v.trim())) return 'Name can only contain letters';
                              return null;
                            }),
                        _buildField("Mobile Number", _mobileCtrl,
                            hint: "Enter 10-digit mobile number",
                            keyboard: TextInputType.phone,
                            maxLength: 10,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                              if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) return 'Enter a valid 10-digit mobile number';
                              return null;
                            }),
                        _buildField("House No / Flat / Building",
                            _houseNoCtrl,
                            hint: "e.g. Flat 101, Tower A",
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'House/Flat number is required';
                              return null;
                            }),
                        _buildField("Area / Street / Locality", _areaCtrl,
                            hint: "e.g. MG Road, Banjara Hills",
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Area/Street is required';
                              if (v.trim().length < 3) return 'Area must be at least 3 characters';
                              return null;
                            }),
                        Row(
                          children: [
                            Expanded(
                                child: _buildField("City", _cityCtrl,
                                    hint: "City",
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'City is required';
                                      if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(v.trim())) return 'Invalid city name';
                                      return null;
                                    })),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildField("State", _stateCtrl,
                                    hint: "State",
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'State is required';
                                      if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(v.trim())) return 'Invalid state name';
                                      return null;
                                    })),
                          ],
                        ),
                        _buildField("Pincode", _pinCodeCtrl,
                            hint: "6-digit pincode",
                            keyboard: TextInputType.number,
                            maxLength: 6,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Pincode is required';
                              if (!RegExp(r'^[0-9]{6}$').hasMatch(v.trim())) return 'Enter a valid 6-digit pincode';
                              return null;
                            }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Save button ──
                  Obx(() => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _ac.isLoading.value ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HexColor("#FFD546"),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                          ),
                          child: _ac.isLoading.value
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black))
                              : Text(
                                  _isEditing
                                      ? "Update Address"
                                      : "Save Address",
                                  style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black),
                                ),
                        ),
                      )),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {String? hint, TextInputType? keyboard, int? maxLength,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLength: maxLength,
        validator: validator ?? (v) =>
            (v == null || v.trim().isEmpty) ? 'This field is required' : null,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
              fontSize: 13, color: Colors.grey.shade400),
          counterText: '',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: HexColor("#FFD546"), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          errorStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.red),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
