import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/CleaningModule/BookingHistoryScreen/booking_history_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/EarningScreen/earning_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/NotificationScreen/notification_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/SecurityKitScreen/security_kit_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TrainingScreen/training_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/IntroScreens/intro_screens_1.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Utils/PrefsManager/prefs_manager.dart';

/// Partner profile / drawer screen.
///
/// Fully backend-driven: the name, phone and avatar are fetched from
/// `/driver/app/profile`; the edit pen picks a new photo and uploads it via
/// `/driver/app/profile-image`. Matches the Figma "Profile" design.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static final Color _headerBlue = HexColor("#2C54C1");
  static final Color _danger = HexColor("#E02D3C");

  String _name = '';
  String _phone = '';
  String _avatar = '';
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final res = await DriverApiService.getDriverProfile();
    if (!mounted || !res.success || res.data is! Map) return;
    final data = Map<String, dynamic>.from(res.data as Map);
    final code = (data['countryCode'] ?? '').toString();
    final number = (data['mobileNumber'] ?? '').toString();
    setState(() {
      _name = (data['fullName'] ?? '').toString();
      _phone = number.isEmpty ? '' : '$code $number'.trim();
      _avatar = (data['profileImage'] ?? '').toString();
    });
  }

  /// Pick a new profile photo and upload it, then refresh the avatar.
  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return;
      setState(() => _uploadingPhoto = true);
      final res = await DriverApiService.uploadProfileImage(File(picked.path));
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      if (res.success) {
        // Use the URL the server returns; otherwise re-fetch the profile.
        final url = (res.data is Map)
            ? (res.data['profileImage'] ?? '').toString()
            : '';
        if (url.isNotEmpty) {
          setState(() => _avatar = url);
        } else {
          _loadProfile();
        }
      } else {
        Fluttertoast.showToast(
            msg: res.message.isNotEmpty ? res.message : 'Could not update photo');
      }
    } catch (_) {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  _menuItem("assets/user.png", "Profile", () {}),
                  _menuItem("assets/history.png", "Booking history",
                      () => pushTo(context, const BookingHistoryScreen())),
                  _menuItem("assets/rupee.png", "Payment/Earnings",
                      () => pushTo(context, const EarningScreen())),
                  _menuItem("assets/security.png", "Security & Kit",
                      () => pushTo(context, const SecurityKitScreen())),
                  _menuItem("assets/onboarding.png", "Training",
                      () => pushTo(context, const TrainingScreen())),
                  _menuItem("assets/bell.png", "Notification",
                      () => pushTo(context, const NotificationScreen())),
                  _menuItem("assets/privacy_policy.png", "Privacy Policy.", () {}),
                  _menuItem("assets/terms.png", "Terms of use", () {}),
                  _menuItem("assets/help.png", "Help/Support", () {}),
                  _menuItem("assets/bin.png", "Delete My Account", () {},
                      danger: true, showChevron: false),
                  _menuItem("assets/logout.png", "Log out", _onLogout,
                      danger: true, showChevron: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header (Figma: #2C54C1, 73px avatar + edit pen) ──
  Widget _header() {
    return Container(
      width: double.infinity,
      color: _headerBlue,
      padding: const EdgeInsets.only(top: 53, bottom: 22, left: 23, right: 20),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            _avatarWithPen(),
            const SizedBox(width: 21),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _name.isEmpty ? '—' : _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _phone,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarWithPen() {
    return SizedBox(
      width: 73,
      height: 73,
      child: Stack(
        children: [
          Container(
            width: 73,
            height: 73,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: _avatar.isNotEmpty
                ? Image.network(
                    _avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarFallback(),
                  )
                : _avatarFallback(),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _changePhoto,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: _uploadingPhoto
                    ? SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: _headerBlue),
                      )
                    : Icon(Icons.edit, size: 11, color: HexColor("#1C1F34")),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Image.asset("assets/person_icon.png", height: 34, width: 34),
      );

  // ── Menu row (24px icon + chevron, Figma spacing) ──
  Widget _menuItem(
    String icon,
    String title,
    VoidCallback onTap, {
    bool danger = false,
    bool showChevron = true,
  }) {
    final color = danger ? _danger : HexColor("#1C1F34");
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Image.asset(icon, height: 24, width: 24, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right, size: 22, color: HexColor("#1C1F34")),
          ],
        ),
      ),
    );
  }

  Future<void> _onLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout', style: TextStyle(color: _danger)),
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
      if (mounted) replaceRoute(context, const IntroScreens());
    }
  }
}
