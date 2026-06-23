import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/DriverModule/DriverProfileApp/driver_profile_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/FaqScreen/faq_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/WalletModule/my_wallet_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/TripHistoryPage/trip_history_page.dart';
import 'package:kebu_driver/Screens/DriverModule/driver_instruction_screen/driver_instructions_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/IntroScreens/intro_screens_1.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Utils/PrefsManager/prefs_manager.dart';

/// Figma "Profile" (131:11103) — yellow header with back + title + tappable
/// profile row, a 3-column stats strip, and a menu list (History, My Wallet,
/// Refer and Earn, Help, Driver Instructions, Logout). All driver data is
/// bound to [DriverApiService.getDashboard] (backend).
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  // Design tokens
  static final _yellow = HexColor('#FFD546');
  static final _gray1 = HexColor('#132235');
  static final _gray2 = HexColor('#364B63');
  static final _gray4 = HexColor('#94A3B3');
  static final _border = HexColor('#E1E6EF');
  static final _red = HexColor('#E02D3C');
  static final _bg = HexColor('#F0F5FA');

  String _driverName = '';
  String _mobileNumber = '';
  String _profileImage = '';
  double _totalEarnings = 0;
  int _totalRides = 0;
  double _totalLoginHrs = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final res = await DriverApiService.getDashboard();
    if (res.success && res.data != null && mounted) {
      final driver = res.data['driver'] ?? {};
      final weekly = res.data['weekly'] ?? {};
      setState(() {
        _driverName = (driver['fullName'] ?? '').toString();
        _mobileNumber = (driver['mobileNumber'] ?? '').toString();
        _profileImage = (driver['profileImage'] ?? '').toString();
        _totalEarnings = (weekly['totalEarnings'] ?? 0).toDouble();
        _totalRides = (driver['totalRides'] ?? 0) as int;
        _totalLoginHrs = (driver['totalLoginHours'] ?? 0).toDouble();
      });
    }
  }

  // ─────────────── helpers ───────────────

  String _money(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '₹$buf.${parts[1]}';
  }

  String _loginHrsText() {
    if (_totalLoginHrs <= 0) return '0 Hrs';
    final v = _totalLoginHrs % 1 == 0
        ? _totalLoginHrs.toStringAsFixed(0)
        : _totalLoginHrs.toStringAsFixed(1);
    return '$v Hrs';
  }

  String _formatPhone(String phone) {
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length > 10 && d.startsWith('91')) d = d.substring(d.length - 10);
    if (d.length == 10) return '+91 ${d.substring(0, 5)} ${d.substring(5)}';
    return d.isEmpty ? '' : '+91 $d';
  }

  // ─────────────── build ───────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _header(),
          const SizedBox(height: 8),
          _statsStrip(),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _divider(),
                  _menuItem(
                    icon: 'assets/clock.png',
                    label: 'History',
                    onTap: () => pushTo(context, const TripHistoryPage()),
                  ),
                  _divider(),
                  _menuItem(
                    icon: 'assets/profile_circle.png',
                    label: 'My Wallet',
                    onTap: () => pushTo(context, const MyWalletScreen()),
                  ),
                  _divider(),
                  _menuItem(
                    icon: 'assets/share.png',
                    label: 'Refer and Earn',
                    onTap: () {},
                  ),
                  _divider(),
                  _menuItem(
                    icon: 'assets/message_question.png',
                    label: 'Help',
                    onTap: () => pushTo(context, const FaqScreen()),
                  ),
                  _divider(),
                  _menuItem(
                    icon: 'assets/task_square.png',
                    label: 'Driver Instructions',
                    onTap: () =>
                        pushTo(context, const DriverInstructionsScreen()),
                  ),
                  _divider(),
                  _menuItem(
                    icon: 'assets/logout.png',
                    label: 'Logout',
                    isLogout: true,
                    showArrow: false,
                    onTap: _onLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── header ───────────────

  Widget _header() {
    return Container(
      color: _yellow,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(99),
                    child: Icon(Icons.arrow_back, size: 26, color: _gray1),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'Profile',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 25 / 20,
                      color: _gray1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _profileRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRow() {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
        );
        _fetchData();
      },
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 56,
              height: 56,
              child: _profileImage.isNotEmpty
                  ? Image.network(
                      _profileImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                          'assets/profile_pic.png',
                          fit: BoxFit.cover),
                    )
                  : Image.asset('assets/profile_pic.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driverName.isNotEmpty ? _driverName : 'Driver',
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 22 / 17,
                    color: _gray1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPhone(_mobileNumber),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: _gray1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 16, color: _gray1),
        ],
      ),
    );
  }

  // ─────────────── stats strip ───────────────

  Widget _statsStrip() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _statCol('Total Earning', _money(_totalEarnings))),
            _statDivider(),
            Expanded(child: _statCol('Total Trips', '$_totalRides')),
            _statDivider(),
            Expanded(
                child: _statCol('Total LogIn Hrs', _loginHrsText())),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, color: _border);

  Widget _statCol(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 18 / 13,
            color: _gray2,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 22 / 17,
              color: _gray1,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────── menu ───────────────

  Widget _divider() => Padding(
        padding: const EdgeInsets.only(left: 52),
        child: Container(height: 1, color: _border),
      );

  Widget _menuItem({
    required String icon,
    required String label,
    required VoidCallback onTap,
    bool isLogout = false,
    bool showArrow = true,
  }) {
    final color = isLogout ? _red : _gray1;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.asset(
              icon,
              width: 24,
              height: 24,
              color: isLogout ? _red : _yellow,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 21 / 16,
                  color: color,
                ),
              ),
            ),
            if (showArrow)
              Icon(Icons.arrow_forward_ios, size: 14, color: _gray4),
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
            child: Text('Logout', style: TextStyle(color: _red)),
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
