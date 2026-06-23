import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/LoginScreen/login_screen.dart';
import 'package:kebu_customer/Screens/Screens/DashboardScreen/dashboard_screen.dart';
import 'package:kebu_customer/Utils/AppColors/app_colors.dart';
import 'package:kebu_customer/Utils/PermissionHelper/permission_helper.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    Future.delayed(const Duration(seconds: 3), () async {
      await Prefs.load();
      Prefs.loadData();

      // Request all permissions on first launch
      await PermissionHelper.requestAllPermissions();

      if(Prefs.check_log_in == true)
      {
        replaceRoute(context, const DashboardScreen());
      }
      else
      {
        replaceRoute(context, const LoginScreen());
      }
    });
    super.initState();
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
