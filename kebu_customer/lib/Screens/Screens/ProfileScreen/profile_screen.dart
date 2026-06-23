import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/Screens/ContactUsScreen/contact_us_screen.dart';
import 'package:kebu_customer/Screens/Screens/ProfileScreen/payment_methods_screen.dart';
import 'package:kebu_customer/Screens/Screens/ReferAFriend/refer_a_friend_screen.dart';
import 'package:kebu_customer/Screens/Screens/SavedAddresses/saved_addresses_screen.dart';
import 'package:kebu_customer/Screens/Screens/SocialAccountScreen/social_account_screen.dart';
import 'package:kebu_customer/Screens/Screens/ManagePlanScreen/manage_plan_screen.dart';
import 'package:kebu_customer/Services/user_api_service.dart';
import 'package:kebu_customer/Screens/Screens/ProfileScreen/edit_profile_screen.dart';
import 'package:kebu_customer/Screens/LoginScreen/login_screen.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String fullName = "";
  String email = "";
  String profileImage = "";
  bool pushNotifications = true;
  bool promoNotifications = true;

  final Color _pink = HexColor("#FF3B59");
  final Color _dark = HexColor("#1B1D21");

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final response = await UserApiService.getProfile();
    if (response.success && response.data != null && mounted) {
      setState(() {
        fullName = response.data['fullName'] ?? "";
        email = response.data['email'] ?? "";
        profileImage = response.data['profileImage'] ?? "";
      });
    }
  }

  Future<void> _toggleNotification() async {
    await UserApiService.toggleNotification();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.dmSans()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performLogout();
            },
            child: Text('Logout',
                style:
                    GoogleFonts.dmSans(color: _pink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _performLogout() {
    Prefs.clear();
    replaceRoute(context, const LoginScreen());
  }

  Widget _buildProfileAvatar() {
    final imageUrl = profileImage.trim();
    const double size = 84;
    final radius = BorderRadius.circular(26);

    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          imageUrl,
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset('assets/profile_image.png',
              height: size, width: size, fit: BoxFit.cover),
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.asset('assets/profile_image.png',
          height: size, width: size, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Gradient header
            commonAppBar(
              height: 160,
              context: context,
              child: Container(
                padding: const EdgeInsets.only(top: 55, left: 12, right: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.arrow_back_ios_new,
                            size: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Profile",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const NotificationIconButton(height: 33),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 110),
              child: Container(
                width: MediaQuery.of(context).size.width,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---------- PROFILE TOP ----------
                    const SizedBox(height: 30),
                    Center(
                      child: Column(
                        children: [
                          _buildProfileAvatar(),
                          const SizedBox(height: 12),
                          Text(
                            fullName.isNotEmpty ? fullName : 'User',
                            style: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email.isNotEmpty ? email : 'No email set',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              letterSpacing: -0.3,
                              color: _pink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () async {
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(
                                    fullName: fullName,
                                    email: email,
                                    profileImage: profileImage,
                                  ),
                                ),
                              );
                              if (updated == true) _loadProfile();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 25, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: _pink, width: 1.5),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Text(
                                "Edit",
                                style: GoogleFonts.dmSans(
                                  color: _dark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---------- GENERAL ----------
                    _sectionTitle("GENERAL"),
                    _tile(Icons.credit_card, "Payment Methods",
                        "Add your credit & debit cards",
                        () => pushTo(context, const PaymentMethodsScreen())),
                    _divider(),
                    _tile(Icons.location_on_outlined, "Locations",
                        "Add your home & work locations",
                        () => pushTo(context, const SavedAddressesScreen())),
                    _divider(),
                    _tile(Icons.camera_alt_outlined, "Add Social Account",
                        "Add Facebook, Instagram, Twitter etc",
                        () => pushTo(context, const SocialAccountScreen())),
                    _divider(),
                    _tile(Icons.ios_share_rounded, "Refer to Friends",
                        "Invite friends & earn rewards",
                        () => pushTo(context, const ReferAFriendScreen())),
                    _divider(),
                    _tile(Icons.workspace_premium_rounded,
                        "Upgrade to Kebu One Pass",
                        "Price Lock, Zero Wait & more benefits",
                        () => pushTo(context, const ManagePlanScreen())),

                    const SizedBox(height: 18),

                    // ---------- NOTIFICATIONS ----------
                    _sectionTitle("NOTIFICATIONS"),
                    _toggleTile(
                      "Push Notifications",
                      "For daily update and others.",
                      pushNotifications,
                      (val) async {
                        setState(() => pushNotifications = val);
                        await _toggleNotification();
                      },
                    ),
                    _divider(),
                    _toggleTile(
                      "Promotional Notifications",
                      "New Campaign & Offers",
                      promoNotifications,
                      (val) async {
                        setState(() => promoNotifications = val);
                        await _toggleNotification();
                      },
                    ),

                    const SizedBox(height: 18),

                    // ---------- MORE ----------
                    _sectionTitle("MORE"),
                    _tile(Icons.call_outlined, "Contact Us",
                        "For more information",
                        () => pushTo(context, const ContactUsScreen())),
                    _divider(),
                    _tile(Icons.logout, "Logout", null, _showLogoutDialog),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- HELPERS ----------

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Text(
          title,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.8,
            color: Colors.black,
          ),
        ),
      );

  Widget _divider() => Padding(
        padding: const EdgeInsets.only(left: 56, right: 20),
        child: Container(height: 1, color: const Color(0x33CAC8DA)),
      );

  Widget _tile(IconData icon, String title, String? subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.black.withOpacity(0.64)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      color: _dark,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.28,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        color: Colors.black.withOpacity(0.5),
                        fontSize: 14,
                        letterSpacing: -0.28,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 18, color: Colors.black.withOpacity(0.84)),
          ],
        ),
      ),
    );
  }

  Widget _toggleTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 24, color: Colors.black.withOpacity(0.64)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: _dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.28,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    color: Colors.black.withOpacity(0.5),
                    fontSize: 14,
                    letterSpacing: -0.28,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: _pink,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
