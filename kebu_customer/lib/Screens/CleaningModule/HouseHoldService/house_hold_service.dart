import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/CleaningModule/AcRepairScreen/ac_repair_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/PreBookingForCleaning/pre_booking_for_cleaning.dart';
import 'package:kebu_customer/Screens/CleaningModule/SubCategoryScreen/sub_category_screen.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';
import 'package:kebu_customer/Services/household_api_service.dart';


class HouseHoldService extends StatefulWidget {
  const HouseHoldService({super.key});
  @override
  State<HouseHoldService> createState() => _HouseHoldServiceState();
}

class _HouseHoldServiceState extends State<HouseHoldService> {

  List<dynamic> categories = [];
  List<Map<String, dynamic>> householdBanners = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      HouseholdApiService.getCategories(),
      CustomerFeaturesApiService.getOffers(type: 'HOUSEHOLD'),
    ]);
    if (!mounted) return;
    setState(() {
      final catRes = results[0];
      if (catRes.success && catRes.data != null) {
        categories = catRes.data['categories'] ?? [];
      }
      final offerRes = results[1];
      if (offerRes.success && offerRes.data != null) {
        final list = (offerRes.data['offers'] as List?) ?? const [];
        householdBanners = list
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .where((o) {
              final a = (o['applicableOn'] ?? '').toString().toUpperCase();
              return a == 'HOUSEHOLD' || a == 'ALL';
            })
            .toList();
      }
      isLoading = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    // This screen is placed inside DashboardScreen's Scaffold.body as an
    // overlay — the outer Scaffold owns the BottomNavigationBar. Don't wrap
    // in our own Scaffold (it would fight over viewInsets and let content
    // slip behind the nav bar). Use ColoredBox + a trailing spacer sized off
    // viewPadding.bottom so the last grid row and videos clear the 72dp
    // bold-label nav bar and system inset.
    final mq = MediaQuery.of(context);
    final trailingSpace = mq.viewPadding.bottom + 120;
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Stack(
          children: [

            cleaningAppBar(
                height : 160,
                context : context,
                child: Container(
                  padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: (){
                          Navigator.pop(context);
                        },
                        child: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(left: 5),
                              child: const Icon(Icons.arrow_back_ios, size: 20,color: Colors.white,),
                            ),

                            const SizedBox(width: 10,),
                          ],
                        ),
                      ),

                      const Spacer(),

                      const Text("Household service", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),),

                      const Spacer(),


                      const NotificationIconButton(),
                    ],
                  ),
                )
            ),

            Container(
              margin: const EdgeInsets.only(top: 120),
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10,),

                  // Latest Offers
                  Row(
                    children: [
                      Image.asset("assets/cleaning.png", width: 40,fit: BoxFit.cover,),

                      const SizedBox(width: 15,),

                      const Text("Cleaning", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),),
                    ],
                  ),

                  const SizedBox(height: 10),

                  const Text("From rooms to kitchens, select the spaces you need cleaned and get your transparent cleaning estimate instantly with Kebu One.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w400, fontSize: 13),),

                  const SizedBox(height: 15),

                  // Offer Banners (admin-managed, household-specific)
                  if (householdBanners.isNotEmpty) ...[
                    SizedBox(
                      height: 130,
                      width: MediaQuery.of(context).size.width,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: householdBanners.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _bannerTile(householdBanners[i]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Popular Services
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Our Popular service",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "View All",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: HexColor("#2369CF"),
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: HexColor("#2369CF")

                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Grid Services (dynamic from API)
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (categories.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.home_repair_service_outlined, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(
                            "No services available right now",
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Please check back later",
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.9,
                      children: categories.map<Widget>((cat) {
                        final name = (cat['name'] ?? '').toString();
                        final imageUrl = (cat['image'] ?? '').toString();
                        final icon = (cat['icon'] ?? '').toString();
                        final id = (cat['_id'] ?? '').toString();
                        final rawSubs = cat['subCategories'];
                        final subs = (rawSubs is List)
                            ? rawSubs
                                .whereType<Map>()
                                .map((m) => Map<String, dynamic>.from(m))
                                .toList()
                            : <Map<String, dynamic>>[];
                        return ServiceTile(
                          name: name,
                          image: imageUrl.isNotEmpty
                              ? imageUrl
                              : _fallbackAssetFor(name),
                          icon: icon,
                          categoryId: id,
                          subCategories: subs,
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),

                  // Videos Section
                  Text(
                    "Videos",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 150,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _videoTile("assets/video_thumbnail.png"),
                        const SizedBox(width: 10),
                        _videoTile("assets/video_thumbnail.png"),
                        const SizedBox(width: 10),
                        _videoTile("assets/video_thumbnail.png"),
                      ],
                    ),
                  ),

                  SizedBox(height: trailingSpace),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  String _fallbackAssetFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('ac')) return 'assets/ac.png';
    if (n.contains('plumb')) return 'assets/plumber.png';
    if (n.contains('electric')) return 'assets/electrician.png';
    if (n.contains('tv') || n.contains('television')) return 'assets/television.png';
    if (n.contains('refriger') || n.contains('fridge')) return 'assets/refrigerator.png';
    if (n.contains('chimney')) return 'assets/chimney.png';
    if (n.contains('cooler')) return 'assets/air_cooler.png';
    if (n.contains('washing')) return 'assets/washing_machine.png';
    if (n.contains('geyser')) return 'assets/geyser.png';
    if (n.contains('microwave')) return 'assets/microwave.png';
    if (n.contains('purifier') && n.contains('air')) return 'assets/air_purifier.png';
    if (n.contains('ro') || n.contains('water')) return 'assets/water_filter.png';
    if (n.contains('gas') || n.contains('stove')) return 'assets/gas_stove.png';
    if (n.contains('mixer') || n.contains('grinder')) return 'assets/mixer.png';
    if (n.contains('clean')) return 'assets/cleaning_tools.png';
    if (n.contains('carpent')) return 'assets/carpenter.png';
    return 'assets/cleaning.png';
  }

  Widget _bannerTile(Map<String, dynamic> offer) {
    final banner = (offer['bannerImage'] ?? offer['image'] ?? '').toString();
    final title = (offer['title'] ?? '').toString();
    final subtitle = (offer['subtitle'] ?? offer['description'] ?? '').toString();
    return InkWell(
      onTap: () {
        pushTo(context, const PreBookingForCleaning());
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 280,
          height: 100,
          child: banner.isNotEmpty
              ? Image.network(
                  banner,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _bannerFallback(title, subtitle),
                )
              : _bannerFallback(title, subtitle),
        ),
      ),
    );
  }

  Widget _bannerFallback(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [HexColor('#E61978'), HexColor('#461E98')],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _videoTile(String image) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            image,
            height: 150,
            width: 130,
            fit: BoxFit.cover,
          ),
        ),
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 36),
        ),
      ],
    );
  }
}

class ServiceTile extends StatelessWidget {
  final String name;
  final String image;
  final String? icon;
  final String? categoryId;
  final List<Map<String, dynamic>> subCategories;

  const ServiceTile({
    super.key,
    required this.name,
    required this.image,
    this.icon,
    this.categoryId,
    this.subCategories = const [],
  });

  bool get _isNetwork => image.startsWith('http://') || image.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (subCategories.isNotEmpty) {
          pushTo(
            context,
            SubCategoryScreen(
              parentName: name,
              parentIcon: icon,
              parentImage: _isNetwork ? image : null,
              subCategories: subCategories,
            ),
          );
        } else {
          pushTo(
            context,
            AcRepairScreen(serviceName: name, categoryId: categoryId),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            SizedBox(
              height: 50,
              child: _isNetwork
                  ? Image.network(
                      image,
                      height: 50,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _iconFallback(),
                    )
                  : Image.asset(
                      image,
                      height: 50,
                      errorBuilder: (_, __, ___) => _iconFallback(),
                    ),
            ),
            const SizedBox(height: 8),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _iconFallback() {
    if (icon != null && icon!.isNotEmpty) {
      return Center(
        child: Text(icon!, style: const TextStyle(fontSize: 36)),
      );
    }
    return Icon(Icons.home_repair_service_outlined, size: 40, color: Colors.grey.shade400);
  }
}