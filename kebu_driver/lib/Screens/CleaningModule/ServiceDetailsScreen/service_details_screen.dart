import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/CommonWidgets/pick_salfie.dart';
import 'package:kebu_driver/CommonWidgets/slider_button_widget.dart';
import 'package:kebu_driver/Screens/DriverModule/ServiceDetailsScreen/service_details_1_screen.dart';


class ServiceDetailsScreen extends StatefulWidget {
  const ServiceDetailsScreen({super.key});
  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
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
                  color: Colors.white,
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
                            border: Border.all(color: HexColor("#275FC8"), width: 1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            "Reached",
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2F5AE3),
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
                              fontSize: 14,
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
                padding:  const EdgeInsets.all(14),
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
                width: MediaQuery.of(context).size.width,
                alignment: Alignment.topLeft,
                child: const Text(
                  "Job details 1 item",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.only(left: 10, right: 10, top: 17, bottom: 17),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        SizedBox(width: 10,),
                        Text(
                          "Book an ac technician.",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        Spacer(),

                        Text(
                          "1",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        Spacer(),

                        Text(
                          "₹ 239",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        SizedBox(width: 10,),
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
                            fontSize: 15,
                            color: Colors.black87,
                            fontWeight: FontWeight.w400,
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

                    Divider(color: Colors.grey[300],),

                    const SizedBox(height: 4,),

                    Row(
                      children: [
                        const SizedBox(width: 10,),
                        const Text(
                          "Visiting Charges",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            fontWeight: FontWeight.w400,
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

                    Divider(color: Colors.grey[300],),

                    const SizedBox(height: 4,),


                    Row(
                      children: [
                        const SizedBox(width: 10,),
                        const Text(
                          "Total Amount",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          "₹1255",
                          style: TextStyle(
                            fontSize: 15,
                            color: HexColor("#2C54C1"),
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(width: 10,),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 13,),

              Container(
                margin: const EdgeInsets.only(left: 2),
                width: MediaQuery.of(context).size.width,
                child: Text(
                  "Upload your own photo",
                  style: TextStyle(
                    fontSize: 13,
                    color: HexColor("#000000"),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 7,),

              pickSelfie(context),

              const SizedBox(height: 50),

              Container(
                width: MediaQuery.of(context).size.width,
                padding:  const EdgeInsets.only(left: 0, right: 0),
                child: SliderButtonWidget(text: "Start the service",
                  backgroundColor: HexColor("#D3D3D3"),
                  textColor: HexColor("000000"),
                  arrowColor: HexColor("#D3D3D3"),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  onTap: ()
                  {
                    pushTo(context, const ServiceDetails1Screen());
                  },
                ),
              ),

            ],
                    ),
                  ),
          )
        ],
      ),
    );
  }
}
