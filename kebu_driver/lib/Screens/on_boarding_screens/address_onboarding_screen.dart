import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/button_widget.dart';
import 'package:kebu_driver/CommonWidgets/edit_text_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/bank_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/address_search_screen.dart';
import 'package:kebu_driver/Services/google_places_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';


class AddressOnboardingScreen extends StatefulWidget {
  const AddressOnboardingScreen({super.key});

  @override
  State<AddressOnboardingScreen> createState() => _AddressOnboardingScreenState();
}

class _AddressOnboardingScreenState extends State<AddressOnboardingScreen> {
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

  void _showSelectionSheet(String title, List<String> items, Function(String) onSelect) {
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
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: items.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(items[i]),
                      onTap: () {
                        onSelect(items[i]);
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

  Future<void> _saveAndContinue() async {
    final addressError = Validators.validateAddress(_controller.addressController.text);
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
    final zipError = Validators.validateZipCode(_controller.zipCodeController.text);
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
      pushTo(context, const BankDetailsScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to save address.');
    }
  }

  @override
  Widget build(BuildContext context) {

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Container(
        height: 82,
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Column(
          children: [
            const SizedBox(height: 15,),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Obx(() => ButtonWidget(
                onTap: _controller.isLoading.value ? null : _saveAndContinue,
                borderRadius: BorderRadius.circular(8),
                text: _controller.isLoading.value ? "Saving..." : "Save & Continue",
                textColor: HexColor("#000000"),
                backgroundColor: HexColor("#A2BF49"),
              )),
            ),
            const SizedBox(height: 15,),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            commonAppBar(
                height : 110,
                context : context,
                child: Container(
                  padding: const EdgeInsets.only(top: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () { Navigator.pop(context); },
                        child: Container(
                          padding: const EdgeInsets.only(left: 16),
                          width: 40, height: 35, alignment: Alignment.center,
                          child: Image.asset("assets/back_arrow.png", color: HexColor("#000000"),),
                        ),
                      ),
                      const SizedBox(width: 6,),
                      Text("OnBoarding", style: TextStyle(color: HexColor("#000000"), fontSize: 17, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text("save", style: TextStyle(color: HexColor("#000000"), fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 15,)
                    ],
                  ),
                )
            ),

            const SizedBox(height: 25,),
            Image.asset('assets/address_sc.png'),

            Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 17,),
                  _sectionHeader("CURRENT ADDRESS"),
                  const SizedBox(height: 17,),

                  // Address field - taps opens Google Places search
                  Container(
                    margin: const EdgeInsets.only(left: 15, right: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 3),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("Address", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("*", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _openAddressSearch,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: HexColor("#A2BF49"), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Obx(() {
                                    final addr = _addressText.value;
                                    return Text(
                                      addr.isEmpty ? "Search for your address..." : addr,
                                      style: TextStyle(
                                        color: addr.isEmpty ? Colors.grey : Colors.black,
                                        fontSize: 13,
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
                  ),

                  const SizedBox(height: 14,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.apartmentController, hintText: "Enter apartment, suite, etc.", isOptional: true, labelText: "Apartment, Suite, Unit, Building, Floor, etc")
                  ),

                  const SizedBox(height: 14,),

                  // State selector
                  Container(
                    margin: const EdgeInsets.only(left: 15, right: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 3,),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("State/Province", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("*", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _showSelectionSheet("Select State", _controller.states, (val) {
                            _controller.selectedState.value = val;
                            _controller.selectedCity.value = null;
                          }),
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.only(left: 15, right: 15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Obx(() => Text(
                                    _controller.selectedState.value ?? "-- Select State/Province --",
                                    style: TextStyle(color: _controller.selectedState.value != null ? Colors.black : Colors.grey, fontSize: 13),
                                  )),
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, size: 35),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14,),

                  // City selector
                  Container(
                    margin: const EdgeInsets.only(left: 15, right: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 3,),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("City", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("*", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_controller.selectedState.value == null) {
                              showCustomToast(context, "Please select state first.");
                              return;
                            }
                            _showCityInput();
                          },
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.only(left: 15, right: 15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Obx(() => Text(
                                    _controller.selectedCity.value ?? "-- Select City --",
                                    style: TextStyle(color: _controller.selectedCity.value != null ? Colors.black : Colors.grey, fontSize: 13),
                                  )),
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, size: 35),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14,),

                  // Country (read-only)
                  Container(
                    margin: const EdgeInsets.only(left: 15, right: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 3,),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("Country", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("*", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        Container(
                          height: 50,
                          padding: const EdgeInsets.only(left: 15, right: 15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Obx(() => Text(
                                  _controller.selectedCountry.value,
                                  style: const TextStyle(color: Colors.black, fontSize: 13),
                                )),
                              ),
                              Icon(Icons.arrow_drop_down_rounded, size: 35, color: Colors.grey[500]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.zipCodeController, hintText: "Enter ZIP / postal code", isOptional: false, labelText: "ZIP / Postal Code")
                  ),

                  const SizedBox(height: 14,),
                ],
              ),
            ),

            const SizedBox(height: 20,),
          ],
        ),
      ),
    );
  }

  void _showCityInput() {
    final cityCtrl = TextEditingController(text: _controller.selectedCity.value ?? '');
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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

  Widget _sectionHeader(String title) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Row(
        children: [
          const SizedBox(width: 16,),
          Expanded(child: Container(height: 1, color: HexColor("#E1E6EF"))),
          const SizedBox(width: 10,),
          Text(title, style: const TextStyle(color: Colors.black, fontSize: 13)),
          const SizedBox(width: 10,),
          Expanded(child: Container(height: 1, color: HexColor("#E1E6EF"))),
          const SizedBox(width: 16,),
        ],
      ),
    );
  }
}
