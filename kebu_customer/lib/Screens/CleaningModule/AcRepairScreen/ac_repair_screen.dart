import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/CleaningModule/AcRepairScreen/widgets/card_bottom_sheet.dart';
import 'package:kebu_customer/Screens/CleaningModule/AcRepairScreen/widgets/service_details_bottom_sheet.dart';
import 'package:kebu_customer/Services/household_api_service.dart';


class AcRepairScreen extends StatefulWidget {
  final String? serviceName;
  final String? categoryId;
  const AcRepairScreen({super.key, this.serviceName, this.categoryId});

  @override
  State<AcRepairScreen> createState() => _AcRepairScreenState();
}

class _AcRepairScreenState extends State<AcRepairScreen> {

  final List<int> counts = [2, 0, 0];
  final List<bool> selected = [true, false, false];
  List<dynamic> serviceTypes = [];

  @override
  void initState() {
    super.initState();
    _loadServiceTypes();
  }

  Future<void> _loadServiceTypes() async {
    final response = await HouseholdApiService.getServiceTypes(widget.categoryId ?? 'default');
    if (response.success && response.data != null && mounted) {
      setState(() {
        serviceTypes = response.data['serviceTypes'] ?? [];
      });
    }
  }


  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => const CartBottomSheet(),
    );
  }


  void _showServiceBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => const ServiceDetailsBottomSheet(),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
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

                    Text(widget.serviceName ?? "Ac Repair", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),),

                    const Spacer(),

                    const NotificationIconButton(),
                  ],
                ),
              )
          ),

          // Scroll content
          Container(
            margin: const EdgeInsets.only(top: 110),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topRight: Radius.circular(32), topLeft: Radius.circular(32))
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Preview
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/ac_repaire_video.png',
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.fill,
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
                  ),

                  const SizedBox(height: 12),

                  // Quick info row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoItem(Icons.access_time, "Instant Service with in 30mins"),
                      _infoItem(Icons.verified, "Verified Professionals"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Service Category Title
                  Text(
                    "Our service that we offer",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category scroll list
                  SizedBox(
                    height: 100,
                    child: ListView(
                      padding: const EdgeInsets.only(left: 0),
                      scrollDirection: Axis.horizontal,
                      children: [
                        _categoryTile(
                          image: 'assets/discount.png',
                          title: 'Packages',
                          selected: true,
                        ),
                        _categoryTile(
                          image: 'assets/ac_1.png',
                          title: 'Ac Service'
                        ),
                        _categoryTile(
                          image: 'assets/ac_2.png',
                          title: 'Ac Repair & Gas Refill',
                        ),
                        _categoryTile(
                          image: 'assets/ac_3.png',
                          title: 'Ac Installation',
                        ),
                        _categoryTile(
                          image: 'assets/ac_1.png',
                          title: 'Ac Service',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Packages
                  Text(
                    "Packages",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _packageCard(
                    units: "2",
                    title: "Power Saver Service (2 AC Units)",
                    price: "₹999",
                    count: counts[0],
                    isCountSelected: selected[0],
                    onAddPressed: () {
                      setState(() => selected[0] = true);
                    },
                    onIncrement: () {
                      setState(() => counts[0]++);
                    },
                    onDecrement: () {
                      setState(() {
                        if (counts[0] > 0) counts[0]--;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  _packageCard(
                    units: "3",
                    title: "Power Saver Service (3 AC Units)",
                    price: "₹999",
                    count: counts[1],
                    isCountSelected: selected[1],
                    onAddPressed: () {
                      setState(() => selected[1] = true);
                    },
                    onIncrement: () {
                      setState(() => counts[1]++);
                    },
                    onDecrement: () {
                      setState(() {
                        if (counts[1] > 0) counts[1]--;
                      });
                    },
                  ),

                  const SizedBox(height: 90,)
                ],
              ),
            ),
          ),


          Positioned(
            bottom: 0,
              left: 0,
              right: 0,
              child: _cartItem())
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 18),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 9, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _categoryTile({
    required String image,
    required String title,
    bool selected = false,
  }) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            height: 60,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEDF3FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? const Color(0xFF0052D4) : Colors.grey.shade200,
                ),
              ),
              child: Image.asset(image, height: 35)
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: selected ? const Color(0xFF0052D4) : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _packageCard({
    required String units,
    required String title,
    required String price,
    required int count,
    required bool isCountSelected,
    required VoidCallback onAddPressed,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            blurRadius: 5,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left gradient box
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        HexColor("#E61978"),
                        HexColor("#461E98")
                      ],
                      transform: const GradientRotation(7)
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        units,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "AC Units",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 7),
          // Right details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4,),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "30 mins",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.star, color: Colors.orangeAccent, size: 14),
                    Text(
                      "5.1 (100+)",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "• Applicable for both Split & Window",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),


                Text(
                  "• Best for small households",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [

                    if(isCountSelected == false)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onAddPressed,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0052D4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                        ),
                        child: Text(
                          "Add",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF0052D4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),



                    if(isCountSelected == true)
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF0052D4)),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: onDecrement,
                                child: Container(
                                  padding: const EdgeInsets.only(left: 9, right: 5, top: 3, bottom: 3),
                                  child: Text(
                                    "-",
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      color: const Color(0xFF0052D4),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),

                              const Spacer(),

                              Text(
                                "$count",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF0052D4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const Spacer(),

                              InkWell(
                                onTap: onIncrement,
                                child: Container(
                                  padding: const EdgeInsets.only(left: 5, right: 9, top: 3, bottom: 3),
                                  child: Text(
                                    "+",
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      color: const Color(0xFF0052D4),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(width: 7),

                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _showServiceBottomSheet(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0052D4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          "View Details",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF0052D4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _cartItem() {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // gradient box
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    HexColor("#E61978"),
                    HexColor("#461E98")
                  ],
                  transform: const GradientRotation(7)
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "2",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "AC Units",
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Power Saver Service (2 Acs)",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "₹499",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // view cart button
          InkWell(
            onTap: (){
              _showCartBottomSheet(context);
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                      HexColor("#531E96"),
                      HexColor("#531E96")
                    ],
                    transform: const GradientRotation(7)
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
              child: Center(
                child: Text(
                  "View Cart\n2",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),
        ],
      ),
    );
  }

}
