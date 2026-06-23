import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/CleaningModule/CleaningOrderPlaced/cleaning_order_placed.dart';
import 'package:kebu_customer/Screens/CleaningModule/Controller/household_booking_controller.dart';
import 'package:kebu_customer/Services/household_api_service.dart';


class CleaningOrderDetailsScreen extends StatefulWidget {
  const CleaningOrderDetailsScreen({super.key});

  @override
  State<CleaningOrderDetailsScreen> createState() => _CleaningOrderDetailsScreenState();
}

class _CleaningOrderDetailsScreenState extends State<CleaningOrderDetailsScreen> {

  String paymentMode = 'online';
  bool isBooking = false;
  final controller = Get.find<HouseholdBookingController>();

  Future<void> _confirmBooking() async {
    setState(() => isBooking = true);
    final response = await HouseholdApiService.createBooking(
      categoryId: controller.categoryId.value.isNotEmpty ? controller.categoryId.value : 'default',
      serviceType: controller.serviceType.value.isNotEmpty ? controller.serviceType.value : 'CLEANING',
      preferredDate: controller.selectedDate.value?.toIso8601String() ?? DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      preferredTimeSlot: controller.selectedTimeSlot.value.isNotEmpty ? controller.selectedTimeSlot.value : '14:00',
      address: {
        'address': controller.selectedAddress.value.isNotEmpty ? controller.selectedAddress.value : 'Address not set',
        'lat': controller.selectedLat.value,
        'lng': controller.selectedLng.value,
      },
      paymentMethod: paymentMode,
    );
    if (mounted) {
      setState(() => isBooking = false);
      if (response.success) {
        controller.reset();
        pushTo(context, const CleaningOrderPlaced());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
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
                        onTap: () {
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

                      const Text("Order Details", style: TextStyle(color: Colors.white, fontSize: 16),),

                      const Spacer(),

                      const NotificationIconButton(),
                    ],
                  ),
                )
            ),

            Container(
              padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
              margin: const EdgeInsets.only(top: 120),
              decoration: BoxDecoration(
                color: HexColor("#F6F6F6"),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(20), topLeft: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                child: Image.asset(
                                  'assets/order_map_view.png',
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "1.2 km",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Image.asset("assets/star_with_location.png", width: 22,height: 22,fit: BoxFit.cover,color: HexColor("#531E96"),),
                                  const SizedBox(width: 8),
                                  Text(
                                    controller.selectedAddress.value.isNotEmpty
                                        ? controller.selectedAddress.value
                                        : "Select an address",
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Order Details Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Order Details",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Image.asset("assets/edit_squres.png",height: 16,width: 16,)
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        const SizedBox(height: 20,),

                        Column(
                          children: [
                            Row(
                              children: [

                                const SizedBox(width: 20,),

                                Container(
                                  height: 70,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEAEA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/electrician.png',
                                      height: 45,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "2 Cleaner",
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            "+₹5 for baby room",
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),

                                          const Spacer(),

                                          Text(
                                            "₹5/hr",
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),


                                const SizedBox(width: 20,),
                              ],
                            ),

                            const SizedBox(height: 16),

                            const Divider(),

                            const SizedBox(height: 20),
                            _buildRow("Working Hour", "₹20"),

                            const SizedBox(height: 20),

                            const Divider(),

                            const SizedBox(height: 16),
                            _buildRow("Service Charge", "₹2"),
                            const SizedBox(height: 16),

                            Row(
                              children: [

                                const SizedBox(width: 20,),

                                Row(
                                  children: [
                                    Text("Promo Code ",
                                      style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),),

                                    const SizedBox(width: 5,),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: HexColor("#0052CC").withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "A9CCXJP",
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: HexColor('#0052CC'),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.close, color: HexColor('#0052CC'), size: 13),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                Text(
                                  "-₹20",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                      color: HexColor("#1B1D21").withOpacity(0.5)
                                  ),
                                ),

                                const SizedBox(width: 20,),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            Row(
                              children: [

                                const SizedBox(width: 20,),

                                Text(
                                  "Total",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600
                                  ),
                                ),

                                const SizedBox(width: 6,),

                                Text(
                                  "(Estimated Cost)",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                  ),
                                ),

                                const Spacer(),

                                Text(
                                  "₹56",
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(width: 20,),
                              ],
                            ),

                            const SizedBox(height: 25),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Payment Selection
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Image.asset("assets/bank_card.png", height: 35,width: 45,),
                              const SizedBox(height: 8),
                              Text(
                                "Online Payment",
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black,
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Image.asset("assets/case_icon.png", height: 35, width: 45,),
                              const SizedBox(height: 8),
                              Text(
                                "Cash",
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w500
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HexColor("#531E96"),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: isBooking ? null : () {
                        _confirmBooking();
                      },
                      child: Text(
                        "Confirm (₹15)",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),


                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      children: [

        const SizedBox(width: 20,),

        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),

        const Spacer(),

        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: HexColor("#1B1D21").withOpacity(0.5)
          ),
        ),

        const SizedBox(width: 20,),
      ],
    );
  }
}