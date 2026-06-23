import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/button_widget.dart';
import 'package:kebu_driver/CommonWidgets/edit_text_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/service_categories_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/vehicle_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';


class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();

  void _showBankSelector() {
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
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("Select Bank", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _controller.banks.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_controller.banks[i]),
                      onTap: () {
                        _controller.selectedBank.value = _controller.banks[i];
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
    if (_controller.selectedBank.value == null) {
      showCustomToast(context, "Please select a bank.");
      return;
    }
    final accError = Validators.validateAccountNumber(_controller.accountNumberController.text);
    if (accError != null) {
      showCustomToast(context, accError);
      return;
    }
    final ifscError = Validators.validateIFSC(_controller.ifscCodeController.text);
    if (ifscError != null) {
      showCustomToast(context, ifscError);
      return;
    }

    _controller.isLoading.value = true;
    final res = await OnboardingApiService.saveBankDetails(
      bank: _controller.selectedBank.value!,
      accountNumber: _controller.accountNumberController.text.trim(),
      ifscCode: _controller.ifscCodeController.text.trim(),
    );
    _controller.isLoading.value = false;

    if (!mounted) return;

    if (res.success) {
      // Cleaning vendors don't have a vehicle — they pick services instead.
      if (_controller.serviceType.value == 'cleaning') {
        pushTo(context, const ServiceCategoriesScreen());
      } else {
        pushTo(context, const VehicleDetailsScreen());
      }
    } else {
      showCustomToast(context, res.message ?? 'Failed to save bank details.');
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
            Image.asset('assets/bank_sc.png'),

            Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 17,),
                  _sectionHeader("BANK DETAILS"),
                  const SizedBox(height: 17,),

                  // Bank selector
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
                              child: const Text("Bank", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("*", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _showBankSelector,
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
                                    _controller.selectedBank.value ?? "-- Select Bank --",
                                    style: TextStyle(color: _controller.selectedBank.value != null ? Colors.black : Colors.grey, fontSize: 13),
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

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.accountNumberController, hintText: "Enter account number", isOptional: false, labelText: "Account Number")
                  ),

                  const SizedBox(height: 14,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.ifscCodeController, hintText: "Enter IFSC code", isOptional: false, labelText: "IFSC Code")
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20,),
          ],
        ),
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
