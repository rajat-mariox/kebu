import 'package:flutter/material.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/CleaningModule/BookingHistoryScreen/booking_history_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/EarningScreen/earning_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/NotificationScreen/notification_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/SecurityKitScreen/security_kit_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TrainingScreen/training_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 🔵 Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 25, left: 20, right: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF2F5AE3), // Blue header background
            ),
            child: Row(
              children: [
                // Profile Image
                Stack(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundImage: NetworkImage(
                        'https://randomuser.me/api/portraits/men/75.jpg',
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 15),
                // User Info
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Mithu De...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "+91 96565 56569",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),

          // ⚪ Menu Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  _buildMenuItem("assets/user.png", "Profile", (){}),
                  _buildMenuItem("assets/history.png", "Booking history", (){
                    pushTo(context, const BookingHistoryScreen());
                  }),
                  _buildMenuItem("assets/rupee.png", "Payment/Earnings", (){
                    pushTo(context, const EarningScreen());
                  }),
                  _buildMenuItem("assets/security.png", "Security & Kit", (){
                    pushTo(context, const SecurityKitScreen());
                  }),
                  _buildMenuItem("assets/onboarding.png", "Training", (){
                    pushTo(context, const TrainingScreen());
                  }),
                  _buildMenuItem("assets/bell.png", "Notification", (){
                    pushTo(context, const NotificationScreen());
                  }),
                  _buildMenuItem("assets/privacy_policy.png", "Privacy Policy.", (){}),
                  _buildMenuItem("assets/terms.png", "Terms of use", (){}),
                  _buildMenuItem("assets/help.png", "Help/Support", (){}),

                  // ❌ Delete Account
                  ListTile(
                    leading: Image.asset("assets/bin.png", height: 21,),
                    title: const Text(
                      "Delete My Account",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {},
                  ),

                  // 🔁 Log out
                  ListTile(
                    leading: Image.asset("assets/logout.png", height: 21,),
                    title: const Text(
                      "Log out",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Common Menu Item Builder
  Widget _buildMenuItem(String icon, String title, VoidCallback onTap) {
    return ListTile(

      leading: Image.asset(
        icon,
        color: Colors.black,
        height: 21,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.black54,
      ),
      onTap: onTap,
    );
  }
}
