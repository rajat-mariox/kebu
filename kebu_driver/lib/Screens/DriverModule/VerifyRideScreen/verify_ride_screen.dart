import 'dart:ui';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/google_map_widget.dart';
import 'package:kebu_driver/CommonWidgets/slider_button_widget.dart';
import 'package:kebu_driver/Screens/DriverModule/CollectedCaseScreen/collected_case_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/Controller/driver_booking_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Utils/AppColors/app_colors.dart';
import 'package:pinput/pinput.dart';

class VerifyRideScreen extends StatefulWidget {
  const VerifyRideScreen({super.key});
  @override
  State<VerifyRideScreen> createState() => _VerifyRideScreenState();
}

class _VerifyRideScreenState extends State<VerifyRideScreen> {
  String pinValue = "";
  final DriverBookingController _bc = Get.find<DriverBookingController>();

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFFBFD87D);
    const Color cardBorder = Color(0xFFE6EEF2);


    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      decoration: BoxDecoration(
        //  color: HexColor("#158DFE").withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );


    final focusedPinTheme = PinTheme(
      width: 45,
      height: 45,
      textStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      decoration: BoxDecoration(
            color: HexColor("#F5F5F5"),
        borderRadius: BorderRadius.circular(6),
      //  border: Border.all(color: HexColor("#D3DDE7"), width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.grey,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [

            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Obx(() => GoogleMapWidget(
                centerLat: _bc.currentLat.value != 0 ? _bc.currentLat.value : null,
                centerLng: _bc.currentLng.value != 0 ? _bc.currentLng.value : null,
                pickupLat: _bc.pickupLat.value,
                pickupLng: _bc.pickupLng.value,
              )),
            ),

            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black.withOpacity(0.1),
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 5),
                decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                    color: Colors.white
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: MediaQuery.of(context).size.width * 0.18,),
                        const Column(
                          children: [
                            Text(
                              "Please Enter the OTP",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),

                            Text(
                              "to confirm your ride.",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),


                        const SizedBox(width: 10,),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.yelloColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "#12345678",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    Container(
                      width: MediaQuery.of(context).size.width,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        "Enter OTP",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: Pinput(
                        length: 6,
                        defaultPinTheme: focusedPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        onChanged: (value){
                          pinValue = value;
                          setState(() {
                          });
                        },
                        onCompleted: (pin) => print("Entered OTP: $pin"),
                      ),
                    ),

                    const SizedBox(height: 15),

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

                    Padding(
                      padding:  const EdgeInsets.only(left: 0, right: 0),
                      child: SliderButtonWidget(text: "At Pickup",
                        backgroundColor: AppColors.yelloColor,
                        arrowColor: AppColors.yelloColor,
                        textColor: AppColors.blackColor,
                        onTap: ()
                        {
                          pushTo(context, const AmountToBeCollectedScreen());
                        },
                      ),
                    ),

                    const SizedBox(height: 7),

                  ],
                ),
              ),
            )
          ],
        ),
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
            Image.asset(icon, width: 24,),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Color(0xFF7EBF5C), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
