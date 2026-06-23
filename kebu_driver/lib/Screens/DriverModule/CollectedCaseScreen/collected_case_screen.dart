import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/slider_button_widget.dart';
import 'package:kebu_driver/Screens/DriverModule/CollectedCaseScreen/show_fare_calculation_sheet.dart';
import 'package:kebu_driver/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';

class AmountToBeCollectedScreen extends StatelessWidget {
  const AmountToBeCollectedScreen({super.key});


  @override
  Widget build(BuildContext context) {

    const Color cardBorder = Color(0xFFE6EEF2);
    const Color darkBlue = Color(0xFF14233B);
    const Color buttonGreen = Color(0xFFBFD87D);


    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // for Android
      statusBarBrightness: Brightness.dark, // for iOS
    )
    );

    return Scaffold(
      backgroundColor: Colors.white,
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
                      "Summary",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                  ],
                ),
              )
          ),

          // Top green section
          Container(
            width: double.infinity,
            color: HexColor("#08875D"),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: const Column(
              children: [
                Text(
                  "Amount to be Collected",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "₹489.56",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                )
              ],
            ),
          ),


          // Duration Section
          Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.only(top: 16, bottom: 16, left: 30, right: 30),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HexColor("#2F6FED")),
            ),
            child:  Column(
              children: [
                Text(
                  "DURATION OF USE",
                  style: TextStyle(
                    color: HexColor("#2F6FED"),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "1 Hr 58 Mins",
                  style: TextStyle(
                    color: HexColor("#2F6FED"),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),



          const Text(
            "QR Code",
            style: TextStyle(
              color: darkBlue,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            "Scan & Pay",
            style: TextStyle(
              color: darkBlue,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 14),

          Image.asset("assets/qr_code.png",
            width: 150,
            height: 150,
          ),

          const Spacer(),

          Row(
            children: [
              const SizedBox(width: 20,),
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HexColor("#E1E6EF")),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_in_talk, color: AppColors.yelloColor, size: 19,),
                      const SizedBox(width: 6),
                      Text('Contact', style: TextStyle(color: AppColors.yelloColor)),
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
              const SizedBox(width: 20,),
            ],
          ),

          const SizedBox(height: 16),


          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: SliderButtonWidget(text: "Collected Cash",
              backgroundColor: AppColors.yelloColor,
              arrowColor: AppColors.yelloColor,
              textColor: AppColors.blackColor,
              onTap: (){
                showFareCalculationSheet(context);
              },),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
