import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/CommonWidgets/pick_salfie.dart';
import 'package:kebu_driver/CommonWidgets/slider_button_widget.dart';
import 'package:kebu_driver/Screens/DriverModule/OngoingServices/ongoing_services.dart';


class ServiceDetails1Screen extends StatefulWidget {
  const ServiceDetails1Screen({super.key});

  @override
  State<ServiceDetails1Screen> createState() => _ServiceDetails1ScreenState();
}

class _ServiceDetails1ScreenState extends State<ServiceDetails1Screen> {
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

          Container(
            margin: const EdgeInsets.only(top: 120),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [

                const SizedBox(height: 7,),

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

                const SizedBox(height: 5,),

                pickSelfie(context),


                const SizedBox(height: 12,),

                Container(
                  margin: const EdgeInsets.only(left: 2),
                  width: MediaQuery.of(context).size.width,
                  child: Text(
                    "Upload device photo",
                    style: TextStyle(
                      fontSize: 13,
                      color: HexColor("#000000"),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 5,),

                pickSelfie(context),

                const SizedBox(height: 12,),

                Container(
                  margin: const EdgeInsets.only(left: 2),
                  width: MediaQuery.of(context).size.width,
                  child: Text(
                    "Upload a photo of the device serial no",
                    style: TextStyle(
                      fontSize: 13,
                      color: HexColor("#000000"),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 5,),

                pickSelfie(context),


                const SizedBox(height: 12,),

                Container(
                  margin: const EdgeInsets.only(left: 2),
                  width: MediaQuery.of(context).size.width,
                  child: Text(
                    "Upload other photo (optional)",
                    style: TextStyle(
                      fontSize: 13,
                      color: HexColor("#000000"),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 5,),

                pickSelfie(context),

                const Spacer(),

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
                      pushTo(context, const OngoingServices());
                    },
                  ),
                ),

              ],
            ),
          )
        ],
      ),
    );
  }
}
