import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/google_map_widget.dart';
import 'package:kebu_driver/CommonWidgets/slider_button_widget.dart';
import 'package:kebu_driver/Screens/DriverModule/Controller/driver_booking_controller.dart';
import 'package:kebu_driver/Screens/DriverModule/VerifyRideScreen/verify_ride_screen.dart';
import 'package:kebu_driver/Utils/AppColors/app_colors.dart';
import 'package:get/get.dart';

class BookingDetailPage extends StatelessWidget {
  const BookingDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DriverBookingController bc = Get.find<DriverBookingController>();
    // Colors matched to screenshot
    const Color primaryGreen = Color(0xFFBFD87D);
    const Color cardBorder = Color(0xFFE6EEF2);

    return Scaffold(
      backgroundColor: Colors.grey,
      body: Column(
        children: [
          commonAppBar(
              height : 100,
              context : context,
              child: Container(
                padding: const EdgeInsets.only(top: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: ()
                      {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.only(left: 16),
                        width: 40,
                        height: 35,
                        alignment: Alignment.center,
                        child: Image.asset("assets/back_arrow.png", color: Colors.black,),
                      ),
                    ),

                    const SizedBox(width: 8,),

                    const Text(
                      "On Route",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    Image.asset("assets/filter_1.png", width: 30,),

                    const SizedBox(width: 10,)

                  ],
                ),
              )
          ),

          Expanded(
            child: Stack(
              children: [

                const GoogleMapWidget(interactive: true),

                // My Location button
                Positioned(
                  left: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () => bc.detectCurrentLocation(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD546),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location, size: 14, color: Colors.black87),
                          SizedBox(width: 4),
                          Text("My Location", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
              //      height: 550,
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 5),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                      color: Colors.white
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        // Top icon / badge area (small car icon in screenshot)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            Container(width: MediaQuery.of(context).size.width * 0.25,),

                            const Column(
                              children: [
                                Text(
                                  "One Way",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),

                                Text(
                                  "Manual - Hatchback",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),

                            Container(width: MediaQuery.of(context).size.width * 0.03,),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.yelloColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.flash_on, color:  Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    "Grab now",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Info Card: Start In / Customer Name / Address
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Row: Start In and time
                              Row(
                                children: [
                                  SizedBox(
                                    height: 27,
                                    width: 27,
                                    child: Image.asset("assets/clock.png", height: 27, width: 27,fit: BoxFit.cover,color: AppColors.yelloColor,),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Start In', style: TextStyle(color: Colors.black,fontWeight: FontWeight.w600, fontSize: 12)),
                                  const SizedBox(width: 10),
                                  const Spacer(),
                                  Text('10:15 PM', style: TextStyle(color: HexColor("#364B63"), fontSize: 12)),
                                ],
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 10, bottom: 10),
                                color: Colors.grey,
                                height: 0.4,
                                width: MediaQuery.of(context).size.width - 50,
                              ),

                              // Row: Customer name
                              Row(
                                children: [
                                  SizedBox(
                                    height: 27,
                                    width: 27,
                                    child: Image.asset("assets/profile_circle.png", height: 27, width: 27,fit: BoxFit.cover,color: AppColors.yelloColor,),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Customer Name', style: TextStyle(color: Colors.black,fontWeight: FontWeight.w600, fontSize: 12)),
                                  const Spacer(),
                                  Text('Chandrashekar Reddy', style: TextStyle(color: HexColor("#364B63"), fontSize: 12,)),
                                ],
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 10, bottom: 10),
                                color: Colors.grey,
                                height: 0.4,
                                width: MediaQuery.of(context).size.width - 50,
                              ),
                              // Address row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.place, color: AppColors.yelloColor,),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                        'My Home mangala road, KMR Estates, Kondapur, Hyderabad, Telangana, India',
                                        style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500)
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Actions Row: Contact / Get Directions / ID Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: const Row(
                            children: [
                              _ActionTile(icon: "assets/call_icon.png", label: 'Contact'),
                              _ActionTile(icon: "assets/get_direction.png", label: 'Get Directions'),
                              _ActionTile(icon: "assets/user_tag.png", label: 'ID Card'),
                            ],
                          ),
                        ),

                      //  const SizedBox(height: 8),

                        const SizedBox(height: 7),
                        // Earnings card
                        Container(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: HexColor("#E1E6EF")),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(Icons.currency_rupee, color: AppColors.yelloColor, size: 20),
                                          const SizedBox(width: 4),
                                          const Text(
                                            "1,500",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Text(
                                        "Your estimated earnings",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),

                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:  [
                                  Text(
                                    "+150",
                                    style: TextStyle(
                                      color: AppColors.yelloColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.call, color: AppColors.yelloColor, size: 19,),
                                    const SizedBox(width: 6),
                                    Text('Help & Support', style: TextStyle(color: HexColor("#015EA3"))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset("assets/raise_ticket_icon.png", height: 20,),
                                    const SizedBox(width: 8),
                                    const Text('Raise Ticket', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        Padding(
                          padding: const EdgeInsets.only(left: 0, right: 0),
                          child: SliderButtonWidget(text: "At Pickup",
                            backgroundColor: AppColors.yelloColor,
                            textColor: AppColors.blackColor,
                            arrowColor: AppColors.yelloColor,
                            onTap: (){
                              pushTo(context, const VerifyRideScreen());
                            },),
                        ),

                        const SizedBox(height: 7),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String icon;
  final String label;
  const _ActionTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    const Color cardBorder = Color(0xFFE6EEF2);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: cardBorder, width: 1)),
        ),
        child: Column(
          children: [
            Image.asset(icon, width: 24,color: AppColors.yelloColor,),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Color(0xFF7EBF5C), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
