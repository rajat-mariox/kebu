import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/Screens/OrderHistory/order_history_screen.dart';
import 'package:kebu_customer/Screens/SendParcelModule/ConfirmLocation/confirm_location_screen.dart';
import 'package:kebu_customer/Screens/SendParcelModule/DeliveryModeSheet/delivery_mode_sheet.dart';
import 'package:kebu_customer/Services/delivery_api_service.dart';

class SendParcelScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SendParcelScreen({super.key, this.onBack});

  @override
  State<SendParcelScreen> createState() => _SendParcelScreenState();
}

class _VehicleCard {
  // title/subtitle default to the design and are overwritten with backend
  // data (name / description) once the vehicle types load.
  String title;
  String subtitle;
  final String icon;
  final double imgH; // per-vehicle image height to match the Figma proportions
  final String matchName; // stable key used to match the backend vehicle type
  // Real backend vehicleType _id, resolved from the API (null until loaded).
  String? backendId;
  _VehicleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.imgH,
    required this.matchName,
  });
}

class _SendParcelScreenState extends State<SendParcelScreen> {
  static const Color _brandRed = Color(0xFFDE1A21);

  // Static cards keep the exact design; backendId is filled from the API so
  // the real vehicleType _id is sent when booking. "Custom Order" has no
  // backing vehicle type (it's a custom request).
  final List<_VehicleCard> _vehicles = [
    _VehicleCard(
        title: "Cargo Bike",
        subtitle: "10kg, 2 Feet",
        icon: "assets/figma_cargo_bike.png",
        imgH: 72,
        matchName: "Cargo Bike"),
    _VehicleCard(
        title: "Pickup",
        subtitle: "~ 1.2 Ton, 7 Feet",
        icon: "assets/figma_pickup.png",
        imgH: 70,
        matchName: "Pickup"),
    _VehicleCard(
        title: "Large Truck",
        subtitle: "~ 5 Ton, 14 Feet",
        icon: "assets/figma_large_truck.png",
        imgH: 60,
        matchName: "Large Truck"),
    _VehicleCard(
        title: "Custom Order",
        subtitle: "+8 Ton, 20 Feet",
        icon: "assets/add.png",
        imgH: 58,
        matchName: "Custom Order"),
  ];

  // Pickup is selected by default to match the design.
  int _selectedVehicle = 1;

  bool _loadingHistory = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
    _loadHistory();
  }

  Future<void> _loadVehicleTypes() async {
    final response = await DeliveryApiService.getVehicleTypes();
    if (!mounted || !response.success || response.data == null) return;
    final types = (response.data['vehicleTypes'] as List?) ?? [];
    setState(() {
      for (final card in _vehicles) {
        final match = types.firstWhere(
          (t) => (t['name'] ?? '').toString().toLowerCase() ==
              card.matchName.toLowerCase(),
          orElse: () => null,
        );
        if (match != null) {
          card.backendId = match['_id']?.toString();
          // Drive the labels from backend data.
          final name = (match['name'] ?? '').toString();
          final desc = (match['description'] ?? '').toString();
          if (name.isNotEmpty) card.title = name;
          if (desc.isNotEmpty) card.subtitle = desc;
        }
      }
    });
  }

  Future<void> _loadHistory() async {
    final response = await DeliveryApiService.getDeliveryHistory(limit: 3);
    if (!mounted) return;
    setState(() {
      _loadingHistory = false;
      if (response.success && response.data != null) {
        _history = response.data['deliveries'] ?? [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandRed,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF52059), Color(0xFFD91916)],
            stops: [0.0, 0.19],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                          children: [
                            _titleRow(),
                            const SizedBox(height: 10),
                            Text(
                              "Choose vehicle type as your need, we’ll calculate the cost for you.",
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                height: 1.45,
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _promoBanner(),
                            const SizedBox(height: 16),
                            _vehicleGrid(),
                            const SizedBox(height: 20),
                            _historySection(),
                          ],
                        ),
                      ),
                      _proceedButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.pop(context);
              }
            },
            child: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
          ),
          Expanded(
            child: Text(
              "Send Parcel",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const NotificationIconButton(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Title row ("🛵 Vehicle")
  // ---------------------------------------------------------------------------
  Widget _titleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset("assets/figma_cargo_bike.png", width: 64, height: 50,
            fit: BoxFit.contain),
        const SizedBox(width: 6),
        Text(
          "Vehicle",
          style: GoogleFonts.dmSans(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B1D21),
            letterSpacing: -1.4,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Promo banner (horizontally scrolling offer cards)
  // ---------------------------------------------------------------------------
  Widget _promoBanner() {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _promoCard(
            gradient: const LinearGradient(
              colors: [Color(0xFF61628B), Color(0xFF1E1F48)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            pillText: "Limited Offer",
            discount: "20% OFF",
            caption: "On Vehicle Service",
          ),
          const SizedBox(width: 12),
          _promoCard(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD546), Color(0xFFFF155E)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            pillText: "New User",
            discount: "10% Off",
            caption: "Online Payment",
          ),
        ],
      ),
    );
  }

  Widget _promoCard({
    required Gradient gradient,
    required String pillText,
    required String discount,
    required String caption,
  }) {
    return Container(
      width: 272,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: 2,
            child: Image.asset("assets/figma_promo_truck.png", height: 112,
                fit: BoxFit.contain),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      image: const DecorationImage(
                        image: AssetImage("assets/circular_app_icon.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Kebu One",
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "CABS · DELIVERIES · HOUSE HELP",
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pillText,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                discount.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Vehicle grid (2 x 2, selectable)
  // ---------------------------------------------------------------------------
  Widget _vehicleGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _vehicleCard(0)),
            const SizedBox(width: 18),
            Expanded(child: _vehicleCard(1)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _vehicleCard(2)),
            const SizedBox(width: 18),
            Expanded(child: _vehicleCard(3)),
          ],
        ),
      ],
    );
  }

  Widget _vehicleCard(int index) {
    final vehicle = _vehicles[index];
    final isSelected = _selectedVehicle == index;
    final isCustom = vehicle.matchName == "Custom Order";

    return GestureDetector(
      onTap: () => setState(() => _selectedVehicle = index),
      child: Container(
        height: 154,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFFFF6F9),
          borderRadius: BorderRadius.circular(isSelected ? 22 : 10),
          border: isSelected
              ? Border.all(color: const Color(0xFFF62059), width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: isCustom
                    ? Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add,
                            size: 30, color: Color(0xFFF62059)),
                      )
                    : SizedBox(
                        height: vehicle.imgH,
                        width: double.infinity,
                        child: Image.asset(vehicle.icon, fit: BoxFit.contain),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            if (!isCustom)
              Container(
                height: 1,
                width: 119,
                color: const Color(0xFFEDEDED),
              ),
            const SizedBox(height: 8),
            Text(
              vehicle.title,
              style: GoogleFonts.dmSans(
                color: const Color(0xFF1B1D21),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              vehicle.subtitle,
              style: GoogleFonts.dmSans(
                color: Colors.black.withOpacity(0.2),
                fontWeight: FontWeight.bold,
                fontSize: 9,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------
  Widget _historySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "History",
              style: GoogleFonts.dmSans(
                color: const Color(0xFF111111),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            GestureDetector(
              onTap: () => pushTo(context, const OrderHistoryScreen()),
              child: Text(
                "View all",
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF2D3134),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _brandRed),
              ),
            ),
          )
        else if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "No deliveries yet",
              style: GoogleFonts.dmSans(
                color: const Color(0xFF545454),
                fontSize: 12,
              ),
            ),
          )
        else
          ..._history.map((item) => _historyCard(item)),
      ],
    );
  }

  Widget _historyCard(dynamic item) {
    final drops = (item['drops'] as List?) ?? [];
    final dropOff = drops.isNotEmpty ? drops.last : null;
    final recipient = dropOff?['contactName'] ?? 'N/A';
    final address = dropOff?['address'] ?? '-';
    final orderId = _orderDisplayId(item['_id']);
    final status = (item['status'] ?? '').toString();
    final date = _formatDate(item['createdAt']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDCE8E9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderId,
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF2D3134),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    "Recipient: $recipient",
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF545454),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on,
                  size: 16, color: Color(0xFFF62059)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Drop off",
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF545454),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF2D3134),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF545454),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case "DELIVERED":
        color = const Color(0xFF4FBF67);
        label = "Completed";
        break;
      case "CANCELLED":
        color = const Color(0xFFE53935);
        label = "Cancelled";
        break;
      default:
        color = const Color(0xFFF5A623);
        label = "In Progress";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Proceed button
  // ---------------------------------------------------------------------------
  Widget _proceedButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 8, 36, 14),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandRed,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () async {
            final selected = _vehicles[_selectedVehicle];
            // Ask the user how they want to deliver, then carry that choice
            // into the location/scheduling screen.
            final mode = await showDeliveryModeSheet(context);
            if (mode == null || !mounted) return;
            pushTo(
              context,
              ConfirmLocationScreen(
                vehicleTypeId: selected.backendId ?? '',
                vehicleName: selected.title,
                deliveryMode:
                    mode == DeliveryMode.instant ? 'INSTANT' : 'SCHEDULED',
              ),
            );
          },
          child: Text(
            "Proceed",
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _orderDisplayId(dynamic id) {
    final s = id?.toString() ?? '';
    if (s.length < 4) return "ORDB";
    return "ORD${s.substring(s.length - 4).toUpperCase()}";
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return '';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final local = date.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour < 12 ? 'am' : 'pm';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour12:$minute$ampm';
  }
}
