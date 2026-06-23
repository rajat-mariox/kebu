import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/button_widget.dart';
import 'package:kebu_customer/Screens/LoginScreen/login_screen.dart';

class IntroScreens extends StatefulWidget {
  const IntroScreens({super.key});

  @override
  State<IntroScreens> createState() => _IntroScreensState();
}

class _IntroScreensState extends State<IntroScreens> {

  int selectedIndex = 0;
  Timer? timer;
  List<TitleModel> list = [];

  @override
  void initState() {
    list.add(TitleModel(title: "Ride Anytime, Anywhere", description: "Book cabs, autos, or bikes in seconds with real-time tracking and transparent fares."));
    list.add(TitleModel(title: "Send Parcels Hassle-Free", description: "From small packets to big shipments — track your delivery live, secure & on time."));
    list.add(TitleModel(title: "Trusted Professionals at Your Doorstep", description: "Electricians, cleaners, beauticians & more — verified experts just a tap away."));


    timerData();
    super.initState();
  }


  timerData(){
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if(selectedIndex == 0)
      {
        selectedIndex = 1;
      }
      else if(selectedIndex == 1)
      {
        selectedIndex = 2;
      }
      else
      {
        selectedIndex = 0;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [

            const SizedBox(height: 55,),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 13, right: 13, top: 3, bottom: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black, width: 1)
                  ),
                  child: const Text("Skip", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w500),),
                ),

                const SizedBox(width: 20,)
              ],
            ),

            const SizedBox(height: 10,),

            Center(
              child: Image.asset(
                "assets/logo/kebu_logo_horizontal_light.png",
                height: 60,
                fit: BoxFit.contain,
              ),
            ),



            Container(
              width: MediaQuery.of(context).size.width - 100,
              height: MediaQuery.of(context).size.width - 100,
              margin: const EdgeInsets.only(left: 30, right: 20),
                child: Image.asset(selectedIndex == 0 ? "assets/intro_image_1.png" : selectedIndex == 1 ? "assets/intro_image_2.png" : "assets/intro_image_3.png")
            ),

            const SizedBox(height: 30,),

            // Heading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child:  Text(
                list[selectedIndex].title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                  list[selectedIndex].description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w400),
              ),
            ),

           const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 9,
                  width: 9,
                  decoration: BoxDecoration(
                    color: selectedIndex == 0 ? HexColor("#006C02") : HexColor("#BBBBBB"),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),

                const SizedBox(width: 8,),

                Container(
                  height: 9,
                  width: 9,
                  decoration: BoxDecoration(
                    color: selectedIndex == 1 ? HexColor("#006C02") : HexColor("#BBBBBB"),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),

                const SizedBox(width: 8,),

                Container(
                  height: 9,
                  width: 9,
                  decoration: BoxDecoration(
                    color: selectedIndex == 2 ? HexColor("#006C02") : HexColor("#BBBBBB"),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ],
            ),

            const Spacer(),

            Container(
                margin: const EdgeInsets.only(left: 20, right: 20),
                child: ButtonWidget(
                  onTap: (){
                    pushTo(context, const LoginScreen());
                  },
                  text: "Login",height: 50,borderRadius: BorderRadius.circular(10),)),

            const SizedBox(height: 20,),

            Container(
              margin: const EdgeInsets.only(left: 20, right: 20),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  children: [
                    TextSpan(text: "By continuing you agree to our ",
                      style: TextStyle(color: HexColor("#A6A6A6"), fontWeight: FontWeight.w400, fontSize: 14),
                    ),
                    TextSpan(
                      text: "Terms of Services ",
                      style: TextStyle(color: HexColor('#0082DF'), fontWeight: FontWeight.w400, fontSize: 16),
                    ),
                    TextSpan(
                      text: "and ",
                      style: TextStyle(color: HexColor('#A6A6A6'), fontWeight: FontWeight.w400, fontSize: 14),
                    ),
                    TextSpan(
                      text: "Privacy Policy",
                      style: TextStyle(color: HexColor('#0082DF'), fontWeight: FontWeight.w400, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30,),
          ],
        ),
      ),
    );
  }
}


class TitleModel{
  String title;
  String description;

  TitleModel({required this.title, required this.description});
}
