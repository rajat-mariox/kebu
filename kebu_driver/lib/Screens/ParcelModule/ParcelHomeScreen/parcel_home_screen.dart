import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Screens/ParcelModule/Controller/parcel_booking_controller.dart';
import 'package:kebu_driver/Screens/ParcelModule/ParcelDeliveryDetailScreen/parcel_delivery_detail_screen.dart';
import 'package:kebu_driver/Screens/ParcelModule/ParcelHistoryScreen/parcel_history_screen.dart';

/// Parcel partner home/dashboard — implements Figma node 157:10827.
/// Backend-driven: partner info, available balance and the live "New jobs"
/// list of incoming parcel requests all come from the controller.
class ParcelHomeScreen extends StatefulWidget {
  const ParcelHomeScreen({super.key});

  @override
  State<ParcelHomeScreen> createState() => _ParcelHomeScreenState();
}

class _ParcelHomeScreenState extends State<ParcelHomeScreen> {
  final ParcelBookingController c = Get.put(ParcelBookingController());

  static final Color _primary = HexColor("#F32054");
  static final Color _gradTop = HexColor("#F52059");
  static final Color _gradBottom = HexColor("#D91916");

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _bottomNav(),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: () async {
          await c.fetchDashboard();
          await c.refreshJobs();
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(),
            const SizedBox(height: 16),
            _balanceCard(),
            const SizedBox(height: 16),
            _locationBox(),
            const SizedBox(height: 20),
            _newJobsHeader(),
            const SizedBox(height: 8),
            _jobsList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _header() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gradTop, _gradBottom],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Welcome Back",
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.white)),
                    Obx(() => Text(
                          c.partnerName.value.isEmpty
                              ? "Partner"
                              : c.partnerName.value,
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.white),
                        )),
                  ],
                ),
              ),
              const Icon(Icons.notifications_none, color: Colors.white, size: 24),
              const SizedBox(width: 14),
              _avatar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    return Obx(() {
      final img = c.profileImage.value;
      if (img.isNotEmpty) {
        return CircleAvatar(radius: 16, backgroundImage: NetworkImage(img));
      }
      return CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white,
        child: Text(
          c.partnerInitials.value.isEmpty ? "" : c.partnerInitials.value,
          style: GoogleFonts.poppins(
              fontSize: 14, color: _primary, fontWeight: FontWeight.w600),
        ),
      );
    });
  }

  // ── Balance card ──
  Widget _balanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_gradTop, _gradBottom],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Available balance",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
          const SizedBox(height: 4),
          Obx(() => Row(
                children: [
                  Text(
                    c.balanceHidden.value
                        ? "₹ ••••"
                        : "₹ ${c.availableBalance.value.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: c.toggleBalanceVisibility,
                    child: Icon(
                      c.balanceHidden.value
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  // ── Current location ──
  Widget _locationBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your current location",
              style:
                  GoogleFonts.poppins(fontSize: 12, color: HexColor("#111111"))),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: HexColor("#FEF4F6"),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _primary, width: 2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Obx(() => Text(
                        c.currentLocationLabel.value.isEmpty
                            ? "Fetching location…"
                            : c.currentLocationLabel.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: HexColor("#AFAFAF")),
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── New jobs ──
  Widget _newJobsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("New jobs",
              style:
                  GoogleFonts.poppins(fontSize: 14, color: HexColor("#111111"))),
          GestureDetector(
            onTap: () => Get.to(() => const ParcelHistoryScreen()),
            child: Text("View all bookings >",
                style: GoogleFonts.poppins(fontSize: 12, color: _primary)),
          ),
        ],
      ),
    );
  }

  Widget _jobsList() {
    return Obx(() {
      if (c.isLoading.value && c.jobs.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: _primary)),
        );
      }
      if (c.jobs.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined,
                  size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text(
                c.isOnline.value
                    ? "No new jobs right now.\nYou'll be alerted when a request comes in."
                    : "You're offline. Go online to receive parcel requests.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        );
      }
      return Column(
        children: c.jobs.map((job) => _jobCard(job)).toList(),
      );
    });
  }

  Widget _jobCard(Map<String, dynamic> job) {
    final deliveryId = job['deliveryId']?.toString() ?? '';
    final category = (job['category'] ?? 'Delivery').toString();
    final recipient = (job['recipientName'] ?? '').toString();
    final dropAddress = (job['dropAddress'] ?? '').toString();
    final fare = job['fare'];

    return GestureDetector(
      onTap: deliveryId.isEmpty
          ? null
          : () => Get.to(() =>
              ParcelDeliveryDetailScreen(deliveryId: deliveryId)),
      child: Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HexColor("#DCE8E9"))),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: HexColor("#130F26"))),
                    const SizedBox(height: 6),
                    Text(
                      recipient.isEmpty
                          ? "Recipient: —"
                          : "Recipient: $recipient",
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: HexColor("#545454")),
                    ),
                  ],
                ),
              ),
              if (fare != null)
                Text("₹ $fare",
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primary)),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(Icons.two_wheeler, size: 28, color: _primary),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 12, color: HexColor("#130F26")),
                        const SizedBox(width: 5),
                        Text("Drop off",
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: HexColor("#130F26"))),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dropAddress.isEmpty ? "—" : dropAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: HexColor("#545454")),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => c.reject(deliveryId),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("Reject",
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _primary)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  // Open the full request details (Figma 158:13699) where the
                  // partner reviews and confirms the job.
                  onTap: deliveryId.isEmpty
                      ? null
                      : () => Get.to(() =>
                          ParcelDeliveryDetailScreen(deliveryId: deliveryId)),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("Accept",
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  // ── Bottom nav ──
  Widget _bottomNav() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        boxShadow: [
          BoxShadow(color: Color(0x12000000), blurRadius: 30, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, "Home", active: true, onTap: () {}),
          _navItem(Icons.account_balance_wallet_outlined, "Earnings",
              onTap: () => _comingSoon("Earnings")),
          _navItem(Icons.calendar_today_outlined, "Bookings",
              onTap: () => Get.to(() => const ParcelHistoryScreen())),
          _navItem(Icons.person_outline, "Profile",
              onTap: () => _comingSoon("Profile")),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label,
      {bool active = false, required VoidCallback onTap}) {
    final color = active ? _primary : HexColor("#C0C5C2");
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }

  void _comingSoon(String what) {
    Get.snackbar(what, "$what screen is coming soon.",
        snackPosition: SnackPosition.BOTTOM);
  }
}
