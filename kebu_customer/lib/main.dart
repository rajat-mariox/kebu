import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:kebu_customer/firebase_options.dart';
import 'package:kebu_customer/Routes/app_routes.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/CleaningModule/Controller/household_booking_controller.dart';
import 'package:kebu_customer/Screens/LoginScreen/Controller/auth_controller.dart';
import 'package:kebu_customer/Services/fcm_notification_service.dart';
import 'package:kebu_customer/Services/app_config_service.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';
import 'package:kebu_customer/Utils/PermissionHelper/permission_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw behind the OS status bar and navigation bar (edge-to-edge)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize SharedPreferences
  await Prefs.load();
  Prefs.loadData();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FCMNotificationService().initialize();
  
  // Fetch and cache API keys from backend
  await AppConfigService.initialize();

  await _initializeGoogleMapsRenderer();
  
  // Request location and other permissions
  await PermissionHelper.requestAllPermissions();
  
  Get.put(AuthController(), permanent: true);
  Get.put(BookingController(), permanent: true);
  Get.put(HouseholdBookingController(), permanent: true);
  runApp(const MyApp());
}

Future<void> _initializeGoogleMapsRenderer() async {
  final mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    try {
      await mapsImplementation.initializeWithRenderer(
        AndroidMapRenderer.latest,
      );
    } catch (e) {
      debugPrint('Google Maps renderer init failed: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: Get.key,
      debugShowCheckedModeBanner: false,
      locale: Get.deviceLocale,
      title: 'i',
      initialRoute: AppRoutes.initialRoute,
      getPages: AppRoutes.pages,
    );
  }
}
