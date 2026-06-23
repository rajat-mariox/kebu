import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/Screens/Screens/HomeScreen/home_screen.dart';
import 'package:kebu_customer/Screens/Screens/OffersScreen/offers_screen.dart';
import 'package:kebu_customer/Screens/Screens/OrderHistory/order_history_screen.dart';
import 'package:kebu_customer/Screens/Screens/ProfileScreen/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}



class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  Widget? _serviceOverlay;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(
        onServiceSelected: _showService,
        onServiceBack: _clearService,
      ),
      const OffersScreen(),
      const OrderHistoryScreen(),
      const ProfileScreen(),
    ];
  }

  void _showService(Widget screen) {
    setState(() => _serviceOverlay = screen);
  }

  void _clearService() {
    setState(() => _serviceOverlay = null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _serviceOverlay == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _serviceOverlay != null) {
          _clearService();
        }
      },
      child: Scaffold(
        body: _serviceOverlay ?? _pages[_currentIndex],
        // Hide the bottom nav while a service (e.g. Book a Ride) is open so it
        // takes over the full screen.
        bottomNavigationBar: _serviceOverlay != null ? null : _bottomNav(),
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(0, 'assets/nav_home.svg', 'Home'),
              _navItem(1, 'assets/nav_promos.svg', 'Promos'),
              _navItem(2, 'assets/nav_activity.svg', 'Activity'),
              _navItem(3, 'assets/nav_account.svg', 'Account'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, String iconAsset, String label) {
    final selected = _currentIndex == index;
    final activeColor = HexColor("#FD6B22");
    final inactiveColor = HexColor("#ABB7C2");
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _serviceOverlay = null;
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(
              selected ? activeColor : inactiveColor,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w400,
              color: selected ? Colors.black : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}