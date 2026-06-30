import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/CleaningModule/SelectDateScreen/select_date_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/ServiceDetailsScreen/service_details_screen.dart';
import 'package:kebu_customer/Services/household_api_service.dart';
import 'package:kebu_customer/Services/user_api_service.dart';

/// Informational screen shown when a service tile is tapped (Figma node
/// 783:34670). Lists what the expert is trained to do, what the service
/// excludes and what the customer must provide — fully backend-driven via
/// GET /services/categories/:categoryId/service-types. "Book Now" / "Pre Book"
/// hand off to the existing booking flow.
class ServiceInfoScreen extends StatefulWidget {
  final String categoryId;
  final String? initialSlug;
  const ServiceInfoScreen({
    super.key,
    required this.categoryId,
    this.initialSlug,
  });

  @override
  State<ServiceInfoScreen> createState() => _ServiceInfoScreenState();
}

class _ServiceInfoScreenState extends State<ServiceInfoScreen> {
  // ===== Design tokens (Figma node 783:34670) =====
  static final Color _pink = HexColor('#E61978');
  static final Color _purple = HexColor('#461E98');
  static final Color _tabSel = HexColor('#D8197B');
  static final Color _tabBg = HexColor('#FFE5F2');
  static final Color _trainedBg = HexColor('#FAFFFC');
  static final Color _excludeBg = HexColor('#FFF4F4');
  static final Color _cardBorder = HexColor('#DFDFDF');
  static final Color _bookBorder = HexColor('#4A1E97');
  static final Color _green = HexColor('#1FA45A');
  static final Color _red = HexColor('#E0341E');

  bool isLoading = true;
  List<Map<String, dynamic>> services = [];
  int selectedIndex = 0;

  // Admin-configured Single/Multiple booking options (backend: GET
  // /services/booking-types) used by the "Prebook For Convenience" sheet.
  Map<String, dynamic>? singleBookingConfig;
  Map<String, dynamic>? multipleBookingConfig;

  String _addressLabel = '';

  @override
  void initState() {
    super.initState();
    _resolveAddress();
    _load();
  }

  void _resolveAddress() {
    try {
      final bc = Get.find<BookingController>();
      final addr = bc.pickupAddress.value.trim();
      if (addr.isNotEmpty) {
        _addressLabel = addr.split(',').first.trim();
      }
    } catch (_) {/* controller not registered */}
  }

  Future<void> _load() async {
    final catId = widget.categoryId.isNotEmpty ? widget.categoryId : 'default';
    final results = await Future.wait([
      HouseholdApiService.getServiceTypes(catId),
      HouseholdApiService.getBookingTypeConfigs(),
    ]);
    if (!mounted) return;
    setState(() {
      final res = results[0];
      if (res.success && res.data != null) {
        services = ((res.data['serviceTypes'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (widget.initialSlug != null) {
          final i = services.indexWhere(
              (s) => (s['slug'] ?? '').toString() == widget.initialSlug);
          if (i >= 0) selectedIndex = i;
        }
      }
      final cfgRes = results[1];
      if (cfgRes.success && cfgRes.data != null) {
        final list = (cfgRes.data['bookingTypes'] as List?) ?? const [];
        for (final raw in list) {
          if (raw is! Map) continue;
          final cfg = Map<String, dynamic>.from(raw);
          final key = (cfg['bookingType'] ?? '').toString().toUpperCase();
          if (key == 'SINGLE') singleBookingConfig = cfg;
          if (key == 'MULTIPLE') multipleBookingConfig = cfg;
        }
      }
      isLoading = false;
    });
  }

  Map<String, dynamic>? get _selected =>
      services.isNotEmpty && selectedIndex < services.length
          ? services[selectedIndex]
          : null;

  String _name(Map<String, dynamic> s) =>
      (s['serviceType'] ?? s['name'] ?? '').toString();

  List<String> _stringList(dynamic raw) =>
      ((raw as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final gradientH = topInset + 96;
    final cardTop = topInset + 70;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _bottomBar(),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Gradient header background
            Container(
              height: gradientH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_pink, _purple],
                ),
              ),
            ),
            // White sheet
            Container(
              margin: EdgeInsets.only(top: cardTop),
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - cardTop,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  _tabs(),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_selected == null)
                    _emptyState()
                  else ...[
                    _trainedCard(),
                    const SizedBox(height: 16),
                    _excludesCard(),
                    const SizedBox(height: 16),
                    _requirementsCard(),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            // Header row (back, address, change) over the gradient
            Positioned(
              top: topInset + 6,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _addressLabel.isEmpty
                          ? 'Select address'
                          : 'Home | $_addressLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _openAddressPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Text('Change',
                          style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.4)),
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

  // ==================== TABS ====================

  Widget _tabs() {
    if (services.isEmpty) return const SizedBox(height: 0);
    return SizedBox(
      height: 33,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => setState(() => selectedIndex = i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? _tabSel : _tabBg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _name(services[i]),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : Colors.black,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== CARDS ====================

  Widget _trainedCard() {
    final items = _stringList(_selected!['inclusions']);
    return _listCard(
      title: 'The Expert Is Trained To',
      bg: _trainedBg,
      items: items,
      emptyText: 'Details coming soon',
      leading: Icon(Icons.check_circle, size: 16, color: _green),
    );
  }

  Widget _excludesCard() {
    final items = _stringList(_selected!['exclusions']);
    return _listCard(
      title: 'Service Excludes',
      bg: _excludeBg,
      items: items,
      emptyText: 'Nothing excluded',
      leading: Icon(Icons.cancel, size: 16, color: _red),
    );
  }

  Widget _listCard({
    required String title,
    required Color bg,
    required List<String> items,
    required String emptyText,
    required Widget leading,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(emptyText,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade600)),
            )
          else
            ...items.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: leading,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          t,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _requirementsCard() {
    final reqs = ((_selected!['customerRequirements'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What We Need From You',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
          const SizedBox(height: 12),
          if (reqs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Nothing required from your side',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade600)),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: reqs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 11),
                itemBuilder: (_, i) => _requirementTile(reqs[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _requirementTile(Map<String, dynamic> req) {
    final name = (req['name'] ?? '').toString();
    final icon = (req['icon'] ?? '').toString();
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _cardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: _requirementImage(icon, name),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.2,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolve a requirement thumbnail. An admin-uploaded URL wins; otherwise we
  /// pair the requirement name with a bundled Figma illustration; the few
  /// kitchen/dish items without artwork get a themed brand icon so the row is
  /// always complete (never a broken/blank image).
  Widget _requirementImage(String icon, String name) {
    if (icon.startsWith('http')) {
      return Image.network(icon,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _requirementAssetOrIcon(name));
    }
    return _requirementAssetOrIcon(name);
  }

  Widget _requirementAssetOrIcon(String name) {
    final asset = _reqAsset(name);
    if (asset.isNotEmpty) {
      // Bundled illustrations are line icons on a transparent canvas, so pad +
      // contain (cover would crop the strokes).
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(asset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _reqIconBox(name)),
      );
    }
    return _reqIconBox(name);
  }

  Widget _reqIconBox(String name) =>
      Center(child: Icon(_reqIcon(name), size: 28, color: _tabSel));

  /// Map a requirement name to its bundled Figma illustration ('' if none).
  String _reqAsset(String name) {
    final n = name.toLowerCase();
    if (n.contains('mop') || n.contains('bucket')) {
      return 'assets/req_mop_bucket.png';
    }
    if (n.contains('dustpan')) return 'assets/req_dustpan.png';
    if (n.contains('broom')) return 'assets/req_broom.png';
    // brush / scrubber / sponge / toilet brush → brush illustration
    if (n.contains('brush') ||
        n.contains('scrub') ||
        n.contains('sponge') ||
        n.contains('toilet')) {
      return 'assets/req_cleaning_brush.png';
    }
    if (n.contains('cloth') || n.contains('dust')) {
      return 'assets/req_dusting_cloth.png';
    }
    // surface / all-purpose / dish soap / liquid / supplies → spray cleaner
    if (n.contains('surface') ||
        n.contains('purpose') ||
        n.contains('cleaner') ||
        n.contains('soap') ||
        n.contains('liquid') ||
        n.contains('suppl')) {
      return 'assets/req_surface_cleaner.png';
    }
    return '';
  }

  /// Themed fallback icon for kitchen/dish items that have no illustration.
  IconData _reqIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('knife')) return Icons.restaurant;
    if (n.contains('board') || n.contains('chop')) return Icons.kitchen;
    if (n.contains('bowl')) return Icons.dinner_dining;
    if (n.contains('rack')) return Icons.dry_cleaning;
    if (n.contains('ladder') || n.contains('step')) return Icons.stairs;
    if (n.contains('ingredient')) return Icons.shopping_basket;
    if (n.contains('instruction') || n.contains('machine')) {
      return Icons.menu_book;
    }
    return Icons.cleaning_services;
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.home_repair_service_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Service details coming soon',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ==================== BOTTOM BAR ====================

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 12, 19, 12),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selected == null ? null : _showBookingSheet,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _bookBorder),
                  ),
                  child: Text('Book Now',
                      style: GoogleFonts.dmSans(
                          color: _bookBorder,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _selected == null ? null : _showBookingSheet,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_pink, _purple],
                    ),
                  ),
                  child: Text('Pre Book',
                      style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Prebook For Convenience" chooser (Figma node 798:33948). Tapping either
  /// bottom button opens this sheet so the user first picks Single vs Multiple
  /// booking; each choice then continues into the matching booking flow.
  void _showBookingSheet() {
    final showSingle = singleBookingConfig == null
        ? true
        : (singleBookingConfig!['isActive'] != false);
    final showMultiple = multipleBookingConfig == null
        ? true
        : (multipleBookingConfig!['isActive'] != false);

    final tiles = <Widget>[];
    if (showSingle) {
      tiles.add(_bookingOption(
        title: _configTitle(singleBookingConfig, 'Single\nBooking'),
        icon: 'assets/red_alarm.png',
        onTap: () => _goToBooking(multiple: false),
      ));
    }
    if (showMultiple) {
      if (tiles.isNotEmpty) tiles.add(const SizedBox(width: 11));
      tiles.add(_bookingOption(
        title: _configTitle(multipleBookingConfig, 'Multiple\nBooking'),
        icon: 'assets/blue_calender.png',
        onTap: () => _goToBooking(multiple: true),
      ));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prebook For Convenience',
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Tap To Select Your Slot',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, color: Colors.black87)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close,
                          size: 24, color: Color(0xFF27272A)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (tiles.isNotEmpty) Row(children: tiles),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _configTitle(Map<String, dynamic>? config, String fallback) {
    final raw = (config?['title'] as String?)?.trim();
    return (raw != null && raw.isNotEmpty) ? raw.replaceAll(' ', '\n') : fallback;
  }

  Widget _bookingOption({
    required String title,
    required String icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HexColor('#D50069')),
            color: Colors.white.withOpacity(0.5),
          ),
          child: Row(
            children: [
              Image.asset(icon, width: 44, height: 44, fit: BoxFit.contain),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w500, height: 1.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToBooking({required bool multiple}) {
    final s = _selected!;
    final slug = (s['slug'] ?? '').toString();
    final serviceId = (s['_id'] ?? '').toString();
    final name = _name(s);
    final categoryId = (s['categoryId'] ?? widget.categoryId).toString();
    Navigator.pop(context); // close the chooser sheet first
    if (multiple) {
      // Multiple Booking → multi-date picker.
      pushTo(
        context,
        SelectDateScreen(
          categoryId: categoryId.isNotEmpty ? categoryId : null,
          serviceType: slug.isNotEmpty ? slug : null,
          serviceName: name.isNotEmpty ? name : null,
        ),
      );
    } else {
      // Single Booking → date/duration/time picker for one session.
      pushTo(
        context,
        ServiceDetailsScreen(
          categoryId: categoryId.isNotEmpty ? categoryId : null,
          serviceId: serviceId.isNotEmpty ? serviceId : null,
          serviceType: slug.isNotEmpty ? slug : null,
          serviceName: name.isNotEmpty ? name : null,
          bookingType: 'SINGLE',
        ),
      );
    }
  }

  // ==================== ADDRESS PICKER ====================

  Future<void> _openAddressPicker() async {
    final res = await UserApiService.getAddresses();
    final list = (res.success && res.data != null)
        ? ((res.data['data'] ?? res.data['addresses'] ?? const []) as List?)
        : null;
    final addresses = (list ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (!mounted) return;
    if (addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved addresses found')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Select address',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...addresses.map((a) {
              final type = (a['addressType'] ?? 'Home').toString();
              final area =
                  (a['area'] ?? a['city'] ?? a['address'] ?? '').toString();
              return ListTile(
                leading: Icon(
                  type.toLowerCase() == 'work'
                      ? Icons.work_outline
                      : Icons.home_outlined,
                  color: _tabSel,
                ),
                title: Text(type,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(area,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.black54)),
                onTap: () {
                  setState(() => _addressLabel =
                      area.isNotEmpty ? area.split(',').first.trim() : type);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
