import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/CommonWidgets/pick_salfie.dart';
import 'package:kebu_driver/Screens/CleaningModule/CollectedCleaningCaseScreen/collected_cleaning_case_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/UpdateConfigScreen/update_config_screen.dart';


class OngoingServices extends StatefulWidget {
  const OngoingServices({super.key});
  @override
  State<OngoingServices> createState() => _OngoingServicesState();
}

class _OngoingServicesState extends State<OngoingServices> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          cleaningAppBar(
              height : 160,
              context : context,
              child: Container(
                padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
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

                          const SizedBox(width: 6,),
                        ],
                      ),
                    ),

                    const Text("Service details", style: TextStyle(color: Colors.white, fontSize: 16),),

                    const Spacer(),
                  ],
                ),
              )
          ),


          SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.only(top: 120),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 7,),

                  // Total amount section
                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 10, top: 17, bottom: 17),
                    decoration: BoxDecoration(
                      border: Border.all(color: HexColor("#000000").withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 10,),
                            const Text(
                              "Today 12:39 PM",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                            ),

                            const SizedBox(width: 7,),

                            Container(
                              padding: const EdgeInsets.only(left: 15, right: 15, top: 4, bottom: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: HexColor("#06A14E"), width: 1),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                "Reached",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: HexColor("#06A14E"),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(width: 10,),
                          ],
                        ),

                        const SizedBox(height: 4),

                        const Row(
                          children:  [
                            SizedBox(width: 10,),
                            Text(
                              "Your service number is #2699",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500
                              ),
                            ),

                            Spacer(),

                            SizedBox(width: 10,),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(left: 7, right: 7),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:  [
                        Row(
                          children: [
                            Text(
                              "AC",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          "AC service in (area) (city)&nbsp;Book nearby AC service in (area) (city) within 30 minutes. Get verified experts at your doorstep at the most affordable price range, At Number Dekho, we al... more",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  Container(
                    width: double.infinity,
                    padding:  const EdgeInsets.only(left: 7, right: 7),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:  [
                        Row(
                          children: [
                            Text(
                              "Customer Address.",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Tower 4, Assotech Business Cresterra, 714, Sector 135, Noida, Bajidpur, Uttar Pradesh India",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    margin: const EdgeInsets.only(left: 5),
                    width: MediaQuery.of(context).size.width,
                    alignment: Alignment.topLeft,
                    child: const Text(
                      "Finished Work Photo",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 7,),

                  pickSelfie(context),

                  const SizedBox(height: 13),

                  Container(
                    margin: const EdgeInsets.only(left: 2),
                    width: MediaQuery.of(context).size.width,
                    child: Row(
                      children: [
                        const SizedBox(width: 3,),

                        Text(
                          "Estimate Time",
                          style: TextStyle(
                            fontSize: 13,
                            color: HexColor("#000000"),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          "1Hrs 45 min",
                          style: TextStyle(
                            fontSize: 11,
                            color: HexColor("#000000"),
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(width: 7,)
                      ],
                    ),
                  ),

                  const SizedBox(height: 6,),

                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 10, top: 17, bottom: 17),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 10,),
                            const Text(
                              "Subtotal",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const Spacer(),

                            Text(
                              "₹279",
                              style: TextStyle(
                                fontSize: 14,
                                color: HexColor("#6C757D"),
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(width: 10,),
                          ],
                        ),

                        const SizedBox(height: 4,),

                        Divider(color: Colors.grey[300],),

                        const SizedBox(height: 4,),

                        Row(
                          children: [
                            const SizedBox(width: 10,),
                            const Text(
                              "Service charge.",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const Spacer(),

                            Text(
                              "₹49.23",
                              style: TextStyle(
                                fontSize: 13,
                                color: HexColor("#6C757D"),
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(width: 10,),
                          ],
                        ),

                        const SizedBox(height: 4,),
                      ],
                    ),
                  ),


                  const SizedBox(height: 50),

                  Container(
                    width: MediaQuery.of(context).size.width,
                    margin: const EdgeInsets.only(left: 5, right: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: ()
                            {
                              pushTo(context, const UpdateConfigScreen());
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: HexColor("#2C54C1"),),
                                borderRadius: BorderRadius.circular(15)
                              ),
                              height: 50,
                              child: Center(
                                child: Text("Extra amount", style: TextStyle(
                                    color: HexColor("#2C54C1"),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500
                                ),),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 15,),

                        Expanded(
                          child: InkWell(
                            onTap: ()
                            {
                              pushTo(context, const CollectedCleaningCaseScreen());
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                  color: HexColor("#E3EAFF")
                              ),
                              height: 50,
                              child: Center(
                                child: Text("End work", style: TextStyle(
                                    color: HexColor("#2C54C1"),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )

                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
