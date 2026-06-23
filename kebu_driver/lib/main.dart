import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kebu_driver/firebase_options.dart';
import 'package:kebu_driver/Routes/app_routes.dart';
import 'package:kebu_driver/Screens/DriverModule/Controller/driver_booking_controller.dart';
import 'package:kebu_driver/Screens/LoginScreen/Controller/auth_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Services/fcm_notification_service.dart';
import 'package:kebu_driver/Services/app_config_service.dart';
import 'package:kebu_driver/Utils/PrefsManager/prefs_manager.dart';
import 'package:kebu_driver/Utils/PermissionHelper/permission_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use Google's latest Android Maps renderer (modern map styling/tiles)
  // instead of the legacy one. Wrapped in try/catch so a failure here never
  // blocks app startup.
  final mapsImpl = GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    try {
      await mapsImpl.initializeWithRenderer(AndroidMapRenderer.latest);
    } catch (_) {}
  }

  // Initialize SharedPreferences
  await Prefs.load();
  Prefs.loadData();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize FCM
  await FCMNotificationService().initialize();
  
  // Fetch and cache API keys from backend
  await AppConfigService.initialize();
  
  // Request location and other permissions
  await PermissionHelper.requestAllPermissions();
  
  Get.put(AuthController(), permanent: true);
  Get.put(DriverBookingController(), permanent: true);
  Get.put(OnboardingController(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: Get.key,
      debugShowCheckedModeBanner: false,
      locale: Get.deviceLocale,
      title: 'i',
      theme: ThemeData(
        textTheme: GoogleFonts.nunitoTextTheme(),
      ),
      initialRoute: AppRoutes.initialRoute,
      getPages: AppRoutes.pages,
    );
  }
}
