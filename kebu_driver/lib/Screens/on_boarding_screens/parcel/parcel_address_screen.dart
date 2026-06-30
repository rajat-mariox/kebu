import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/address_search_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_bank_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_onboarding_widgets.dart';
import 'package:kebu_driver/Services/google_places_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';

/// Parcel Delivery onboarding — Step 4: Address.
class ParcelAddressScreen extends StatefulWidget {
  const ParcelAddressScreen({super.key});

  @override
  State<ParcelAddressScreen> createState() => _ParcelAddressScreenState();
}

class _ParcelAddressScreenState extends State<ParcelAddressScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();
  final RxString _addressText = ''.obs;

  @override
  void initState() {
    super.initState();
    _addressText.value = _controller.addressController.text;
  }

  Future<void> _openAddressSearch() async {
    final PlaceDetail? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressSearchScreen()),
    );

    if (result != null) {
      _controller.addressController.text = result.formattedAddress;
      _addressText.value = result.formattedAddress;
      if (result.state.isNotEmpty) {
        _controller.selectedState.value = result.state;
      }
      if (result.city.isNotEmpty) {
        _controller.selectedCity.value = result.city;
      }
      if (result.country.isNotEmpty) {
        _controller.selectedCountry.value = result.country;
      }
      if (result.zipCode.isNotEmpty) {
        _controller.zipCodeController.text = result.zipCode;
      }
    }
  }

  void _showStateSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Select State",
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _controller.states.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_controller.states[i],
                          style: GoogleFonts.nunito(fontSize: 15)),
                      onTap: () {
                        _controller.selectedState.value = _controller.states[i];
                        _controller.selectedCity.value = null;
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCityInput() {
    final cityCtrl =
        TextEditingController(text: _controller.selectedCity.value ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enter City"),
        content: TextField(
          controller: cityCtrl,
          decoration: const InputDecoration(hintText: "City name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (cityCtrl.text.trim().isNotEmpty) {
                _controller.selectedCity.value = cityCtrl.text.trim();
              }
              Navigator.pop(ctx);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndContinue() async {
    final addressError =
        Validators.validateAddress(_controller.addressController.text);
    if (addressError != null) {
      showCustomToast(context, addressError);
      return;
    }
    if (_controller.selectedState.value == null) {
      showCustomToast(context, "Please select state.");
      return;
    }
    if (_controller.selectedCity.value == null) {
      showCustomToast(context, "Please select city.");
      return;
    }
    final zipError =
        Validators.validateZipCode(_controller.zipCodeController.text);
    if (zipError != null) {
      showCustomToast(context, zipError);
      return;
    }

    _controller.isLoading.value = true;
    final res = await OnboardingApiService.saveAddress(
      address: _controller.addressController.text.trim(),
      apartment: _controller.apartmentController.text.trim(),
      state: _controller.selectedState.value!,
      city: _controller.selectedCity.value!,
      country: _controller.selectedCountry.value,
      zipCode: _controller.zipCodeController.text.trim(),
    );
    _controller.isLoading.value = false;

    if (!mounted) return;

    if (res.success) {
      pushTo(context, const ParcelBankDetailsScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to save address.');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: ParcelColors.background,
      appBar: parcelHeader(
        context: context,
        title: 'Profile',
        onSave: _saveAndContinue,
      ),
      bottomNavigationBar: Obx(() => ParcelBottomBar(
            onNext: _controller.isLoading.value ? null : _saveAndContinue,
          )),
      body: Column(
        children: [
          const ParcelStepper(currentStep: 3),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    parcelSectionDivider("Current Address"),
                    const SizedBox(height: 20),
                    // Address — taps open Google Places search.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        parcelFieldLabel("Address"),
                        GestureDetector(
                          onTap: _openAddressSearch,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ParcelColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search,
                                    color: ParcelColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Obx(() {
                                    final addr = _addressText.value;
                                    return Text(
                                      addr.isEmpty
                                          ? "Search for your address..."
                                          : addr,
                                      style: GoogleFonts.nunito(
                                        fontSize: 15,
                                        color: addr.isEmpty
                                            ? ParcelColors.hint
                                            : ParcelColors.labelDark,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.apartmentController,
                      label: "Apartment, Suite, Unit, Building, Floor, etc",
                      hint: "Enter apartment, suite, etc.",
                      required: false,
                    ),
                    const SizedBox(height: 20),
                    Obx(() => parcelSelector(
                          label: "State/Province",
                          value: _controller.selectedState.value ?? '',
                          placeholder: "-- Select State/Province --",
                          onTap: _showStateSelector,
                        )),
                    const SizedBox(height: 20),
                    Obx(() => parcelSelector(
                          label: "City",
                          value: _controller.selectedCity.value ?? '',
                          placeholder: "-- Select City --",
                          onTap: () {
                            if (_controller.selectedState.value == null) {
                              showCustomToast(
                                  context, "Please select state first.");
                              return;
                            }
                            _showCityInput();
                          },
                        )),
                    const SizedBox(height: 20),
                    Obx(() => parcelSelector(
                          label: "Country",
                          value: _controller.selectedCountry.value,
                          placeholder: "Country",
                          onTap: () {},
                        )),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.zipCodeController,
                      label: "ZIP / Postal Code",
                      hint: "Enter ZIP / postal code",
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
