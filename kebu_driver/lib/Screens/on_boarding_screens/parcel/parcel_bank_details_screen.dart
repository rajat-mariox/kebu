import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_vehicle_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_onboarding_widgets.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';

/// Parcel Delivery onboarding — Step 5: Bank Details.
class ParcelBankDetailsScreen extends StatefulWidget {
  const ParcelBankDetailsScreen({super.key});

  @override
  State<ParcelBankDetailsScreen> createState() =>
      _ParcelBankDetailsScreenState();
}

class _ParcelBankDetailsScreenState extends State<ParcelBankDetailsScreen> {
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Select Bank",
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _controller.banks.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_controller.banks[i],
                          style: GoogleFonts.nunito(fontSize: 15)),
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
    final accError = Validators.validateAccountNumber(
        _controller.accountNumberController.text);
    if (accError != null) {
      showCustomToast(context, accError);
      return;
    }
    final ifscError =
        Validators.validateIFSC(_controller.ifscCodeController.text);
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
      pushTo(context, const ParcelVehicleDetailsScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to save bank details.');
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
          const ParcelStepper(currentStep: 4),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    parcelSectionDivider("Bank Details"),
                    const SizedBox(height: 20),
                    Obx(() => parcelSelector(
                          label: "Bank",
                          value: _controller.selectedBank.value ?? '',
                          placeholder: "-- Select Bank --",
                          onTap: _showBankSelector,
                        )),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.accountNumberController,
                      label: "Account Number",
                      hint: "Enter account number",
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.ifscCodeController,
                      label: "IFSC Code",
                      hint: "Enter IFSC code",
                      keyboardType: TextInputType.text,
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
