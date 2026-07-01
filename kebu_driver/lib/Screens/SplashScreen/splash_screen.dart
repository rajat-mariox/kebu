import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/DriverModule/HomeScreen/home_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/IntroScreens/intro_screens_1.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/technician_dashboard.dart';
import 'package:kebu_driver/Screens/ParcelModule/ParcelHomeScreen/parcel_home_screen.dart';
import 'package:kebu_driver/Screens/WelcomeScreen/welcome_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/VerificationScreen/verification_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/basic_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/driving_licence_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/aadhar_card_onboarding_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/address_onboarding_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/bank_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/service_categories_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/vehicle_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/vehicle_images_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_basic_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_driving_licence_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_documents_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_address_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_bank_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_vehicle_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_vehicle_images_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Utils/AppColors/app_colors.dart';
import 'package:kebu_driver/Utils/PermissionHelper/permission_helper.dart';
import 'package:kebu_driver/Utils/PrefsManager/prefs_manager.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Keep the branded splash visible for a minimum time so it doesn't just
    // flash by when routing is instant (e.g. a first launch going to intro).
    // This runs concurrently with the work below — it adds no time on top of a
    // slow dashboard fetch, it only fills in when the work finishes early.
    final minSplash = Future.delayed(const Duration(milliseconds: 1500));

    // Small delay to let the first frame settle before the permission dialogs.
    await Future.delayed(const Duration(milliseconds: 100));

    // Request all app permissions once. Fire-and-forget — do NOT await. On a
    // first launch these native dialogs would otherwise hold the splash until
    // every prompt is answered. The dialogs still show (now over the screen we
    // route to), they just no longer block the route decision.
    // (Prefs/Firebase are already initialized in main() before runApp; GPS
    // streaming is kicked off from DriverBookingController.onInit.)
    PermissionHelper.requestAllPermissions();

    final destination = await _resolveDestination();

    // Hold until the branded splash has had its minimum on-screen time.
    await minSplash;
    if (!mounted) return;
    replaceRoute(context, destination);
  }

  /// Decides which screen to land on. Logged-out users go straight to intro;
  /// logged-in users are routed from their dashboard status/serviceType, with a
  /// single retry (the ApiClient timeout bounds each attempt) before falling
  /// back to the welcome screen.
  Future<Widget> _resolveDestination() async {
    if (!Prefs.check_log_in || Prefs.auth_token.isEmpty) {
      return const IntroScreens();
    }

    var res = await DriverApiService.getDashboard();
    if (!(res.success && res.data != null)) {
      await Future.delayed(const Duration(seconds: 2));
      res = await DriverApiService.getDashboard();
    }

    if (!(res.success && res.data != null)) {
      // Still failing — go to welcome screen.
      return const WelcomeScreen();
    }

    final driver = res.data['driver'];
    final status = driver?['status'] ?? '';
    final serviceType = driver?['serviceType'] ?? '';
    final onboardingStep = driver?['onboardingStep'] ?? 0;

    if (status == 'approved') {
      if (serviceType == 'cleaning') return const TechnicianDashboard();
      if (serviceType == 'parcel') return const ParcelHomeScreen();
      return const HomeScreen();
    }

    if (status == 'documents_uploaded' || status == 'under_verification') {
      // Onboarding complete but not yet approved - show verification screen.
      return const VerificationScreen();
    }

    if (serviceType != null && serviceType.toString().isNotEmpty) {
      // Onboarding in progress - resume from where they left off. Seed the
      // controller serviceType so subsequent screens branch correctly.
      try {
        Get.find<OnboardingController>().serviceType.value =
            serviceType.toString();
      } catch (_) {
        Get.put(OnboardingController()).serviceType.value =
            serviceType.toString();
      }
      return _getOnboardingScreen(onboardingStep, serviceType.toString());
    }

    // New driver.
    return const WelcomeScreen();
  }

  /// Routes to the NEXT screen after the last completed step.
  /// Cab flow:      0 -> basic, 1 -> licence, 2 -> docs, 3 -> address,
  ///                4 -> bank,  5 -> vehicle, 6 -> images, 7 -> verification
  /// Cleaning flow: 0 -> basic, 1 -> docs (DL skipped), 3 -> address,
  ///                4 -> bank,  5 -> service categories, 7 -> verification
  Widget _getOnboardingScreen(int completedStep, String serviceType) {
    if (serviceType == 'parcel') {
      // Parcel mirrors the cab flow but uses the pink Figma-themed screens.
      switch (completedStep) {
        case 0:
          return const ParcelBasicDetailsScreen();
        case 1:
          return const ParcelDrivingLicenceScreen();
        case 2:
          return const ParcelDocumentsScreen();
        case 3:
          return const ParcelAddressScreen();
        case 4:
          return const ParcelBankDetailsScreen();
        case 5:
          return const ParcelVehicleDetailsScreen();
        case 6:
          return const ParcelVehicleImagesScreen();
        case 7:
          return const VerificationScreen();
        default:
          return const ParcelBasicDetailsScreen();
      }
    }

    if (serviceType == 'cleaning') {
      switch (completedStep) {
        case 0:
          return const BasicDetailsScreen();
        case 1:
        case 2:
          return const AadharCardOnboardingScreen();
        case 3:
          return const AddressOnboardingScreen();
        case 4:
          return const BankDetailsScreen();
        case 5:
        case 6:
          return const ServiceCategoriesScreen();
        case 7:
          return const VerificationScreen();
        default:
          return const BasicDetailsScreen();
      }
    }

    switch (completedStep) {
      case 0:
        return const BasicDetailsScreen();
      case 1:
        return const DrivingLicenceScreen();
      case 2:
        return const AadharCardOnboardingScreen();
      case 3:
        return const AddressOnboardingScreen();
      case 4:
        return const BankDetailsScreen();
      case 5:
        return const VehicleDetailsScreen();
      case 6:
        return const VehicleImagesScreen();
      case 7:
        return const VerificationScreen();
      default:
        return const BasicDetailsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // for Android
      statusBarBrightness: Brightness.dark, // for iOS
    ));

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.brandGradient),
        child: Center(
          child: Image.asset(
            "assets/logo/kebu_logo_vertical_dark.png",
            width: MediaQuery.of(context).size.width * 0.6,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
