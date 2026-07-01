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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences (fast, needed before runApp to pick the route).
  await Prefs.load();
  Prefs.loadData();

  // Firebase and the Maps renderer are the two slow init steps. No map is shown
  // on the splash, so run them concurrently instead of one-after-another to cut
  // time-to-first-frame roughly in half. The renderer must still be selected
  // before the first GoogleMap is built — the splash + permissions + dashboard
  // fetch give it ample time to finish before the home map appears.
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    _initMapsRenderer(),
  ]);

  Get.put(AuthController(), permanent: true);
  Get.put(DriverBookingController(), permanent: true);
  Get.put(OnboardingController(), permanent: true);

  // Paint the first frame immediately. FCM and remote config aren't needed to
  // render the splash, and permissions are requested once from SplashScreen —
  // so none of these should block startup.
  runApp(const MyApp());

  // Fire-and-forget post-launch init (runs while the splash is on screen).
  FCMNotificationService().initialize();
  AppConfigService.initialize();
}

/// Selects Google's latest Android Maps renderer (modern styling/tiles) instead
/// of the legacy one. Wrapped in try/catch so a failure here never blocks
/// startup — the plugin falls back to the legacy renderer on its own.
Future<void> _initMapsRenderer() async {
  final mapsImpl = GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    try {
      await mapsImpl.initializeWithRenderer(AndroidMapRenderer.latest);
    } catch (_) {}
  }
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
