import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/DriverModule/IntroScreens/intro_screens_1.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/basic_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/household_personal_info_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_basic_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Utils/AppColors/app_colors.dart';
import 'package:kebu_driver/Utils/PrefsManager/prefs_manager.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout",
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text(
            "Logout and sign in with a different number?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Prefs.clear();
      Prefs.check_log_in = false;
      Prefs.auth_token = '';
      Prefs.user_id = '';
      Prefs.mobile_number = '';

      if (context.mounted) {
        replaceRoute(context, const IntroScreens());
      }
    }
  }

  Widget _continueButton({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: HexColor("#FFD546"),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF132234),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // for Android
      statusBarBrightness: Brightness.dark, // for iOS
      )
    );

    return Scaffold(
      body: SingleChildScrollView(
       child: Column(
         children: [

           Container(
             width: MediaQuery.of(context).size.width,
             decoration: BoxDecoration(
               gradient: AppColors.brandGradient,
               borderRadius: const BorderRadius.only(bottomRight: Radius.circular(30), bottomLeft: Radius.circular(30))
             ),
             child: Stack(
               children: [

                 const SizedBox(height: 220, width: double.infinity),

                 Positioned(
                   top: 40,
                   right: 12,
                   child: SafeArea(
                     child: InkWell(
                       borderRadius: BorderRadius.circular(20),
                       onTap: () => _confirmLogout(context),
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: Colors.white.withValues(alpha: 0.18),
                           borderRadius: BorderRadius.circular(20),
                           border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                         ),
                         child: const Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Icon(Icons.logout, color: Colors.white, size: 16),
                             SizedBox(width: 4),
                             Text("Logout",
                               style: TextStyle(
                                 color: Colors.white,
                                 fontSize: 12,
                                 fontWeight: FontWeight.w600,
                               ),
                             ),
                           ],
                         ),
                       ),
                     ),
                   ),
                 ),

                 Positioned(
                   top: 80,
                   left: 0,
                   right: 0,
                   child: Column(
                     children: [

                       Image.asset("assets/logo/kebu_logo_horizontal_dark.png", height: 60, fit: BoxFit.contain,),

                       const SizedBox(height: 10,),

                       const Text("Welcome to",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w400
                          ),
                       ),

                     const Text("Kebu One Partner App",
                       style: TextStyle(
                         color: Colors.white,
                         fontSize: 19,
                         fontWeight: FontWeight.bold
                        ),
                     )
                     ],
                   ),
                 ),

               ],
             ),
           ),

           const SizedBox(height: 20,),

           const Text("Please select the service you want to register for",
             style: TextStyle(
                 color: Colors.black,
                 fontSize: 13,
                 fontWeight: FontWeight.w400
             ),
           ),

           // Card 1 — Register as a Cab Driver (photo background)
           Container(
             margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
             height: 149,
             clipBehavior: Clip.antiAlias,
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(14),
               boxShadow: const [
                 BoxShadow(
                   color: Color(0x80DDDDDD),
                   blurRadius: 12,
                 ),
               ],
             ),
             child: Stack(
               children: [
                 Positioned.fill(
                   child: Image.asset(
                     "assets/register_as_cab_driver.png",
                     fit: BoxFit.cover,
                   ),
                 ),
                 // Dark overlay on the left for text legibility
                 const Positioned.fill(
                   child: DecoratedBox(
                     decoration: BoxDecoration(
                       gradient: LinearGradient(
                         begin: Alignment.centerLeft,
                         end: Alignment.centerRight,
                         colors: [Color(0x66000000), Color(0x00000000)],
                         stops: [0.0, 0.55],
                       ),
                     ),
                   ),
                 ),
                 Positioned(
                   top: 12,
                   left: 12,
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.start,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text(
                         "Register \nas a Cab Driver",
                         style: TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.w600,
                           fontSize: 18,
                           height: 1.33,
                         ),
                       ),
                       const SizedBox(height: 6),
                       const Text(
                         "to earn from daily rides",
                         style: TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.w400,
                           fontSize: 14,
                         ),
                       ),
                       const SizedBox(height: 8),
                       _continueButton(
                         label: "Continue as Cab Driver",
                         onTap: () {
                           final controller = Get.find<OnboardingController>();
                           controller.serviceType.value = 'cab';
                           pushTo(context, const BasicDetailsScreen());
                         },
                       ),
                     ],
                   ),
                 ),
               ],
             ),
           ),

           // Card 2 — Register for Household service (blue gradient)
           Container(
             margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
             height: 149,
             clipBehavior: Clip.antiAlias,
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(14),
               gradient: LinearGradient(
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
                 colors: [HexColor("#226DD2"), HexColor("#3B2FA8")],
               ),
             ),
             child: Stack(
               children: [
                 Positioned(
                   right: 0,
                   bottom: 0,
                   top: 10,
                   child: Image.asset(
                     "assets/cleaning_wel.png",
                     fit: BoxFit.contain,
                   ),
                 ),
                 Positioned(
                   top: 12,
                   left: 12,
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.start,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text(
                         "Register for Household \nservice",
                         style: TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.w600,
                           fontSize: 18,
                           height: 1.33,
                         ),
                       ),
                       const SizedBox(height: 6),
                       const Text(
                         "Dummy earn with flexible timings",
                         style: TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.w400,
                           fontSize: 14,
                         ),
                       ),
                       const SizedBox(height: 8),
                       _continueButton(
                         label: "Continue Household",
                         onTap: () {
                           final controller = Get.find<OnboardingController>();
                           controller.serviceType.value = 'cleaning';
                           pushTo(context, const HouseholdPersonalInfoScreen());
                         },
                       ),
                     ],
                   ),
                 ),
               ],
             ),
           ),

           // Card 3 — Parcel Delivery (red gradient)
           Container(
             margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
             height: 149,
             clipBehavior: Clip.antiAlias,
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(14),
               gradient: LinearGradient(
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
                 colors: [HexColor("#F52059"), HexColor("#D91916")],
               ),
             ),
             child: Stack(
               children: [
                 Positioned(
                   right: 0,
                   bottom: 0,
                   top: 0,
                   child: Image.asset(
                     "assets/parcel_wel.png",
                     fit: BoxFit.contain,
                   ),
                 ),
                 Positioned(
                   top: 12,
                   left: 12,
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.start,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const SizedBox(height: 30),
                       const Text(
                         "Deliver parcels & earn with flexible \ntimings",
                         style: TextStyle(
                           color: Colors.white,
                           fontWeight: FontWeight.w400,
                           fontSize: 14,
                         ),
                       ),
                       const SizedBox(height: 10),
                       _continueButton(
                         label: "Continue Parcel Delivery",
                         onTap: () {
                           final controller = Get.find<OnboardingController>();
                           controller.serviceType.value = 'parcel';
                           pushTo(context, const ParcelBasicDetailsScreen());
                         },
                       ),
                     ],
                   ),
                 ),
               ],
             ),
           ),

           const SizedBox(height: 16),
         ],
       ),
      ),
    );
  }
}
