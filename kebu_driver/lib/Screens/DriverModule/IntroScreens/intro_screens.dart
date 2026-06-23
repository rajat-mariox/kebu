import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/LoginScreen/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class IntroScreens extends StatefulWidget {
  const IntroScreens({super.key});

  @override
  State<IntroScreens> createState() => _IntroScreensState();
}

class _IntroScreensState extends State<IntroScreens> {
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

            const SizedBox(height: 80,),

            Container(
              width: MediaQuery.of(context).size.width - 100,
              height: MediaQuery.of(context).size.width - 100,
              decoration: BoxDecoration(
                color: HexColor("#D9D9D9"),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(80),
              margin: const EdgeInsets.only(left: 30, right: 20),
                child: Image.asset("assets/gallery_icon.png", height: 100,)
            ),

            const SizedBox(height: 30,),

            // Heading
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child:  Text(
                "Making your drive best is our responsibility",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Lorem ipsum dolor sit amet, consectetur",
                style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w400),
              ),
            ),

          const Spacer(),

          InkWell(
            onTap: (){
              pushTo(context, const LoginScreen());
            },
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(0),
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.only(left: 20, right: 20),
              height: 50,
              decoration: BoxDecoration(
                  color: HexColor("#015EA3"),
                  borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 40,),
                  Spacer(),
                  Text(
                      "Get Started",
                    style:
                        TextStyle(
                            color:Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                  ),

                  Spacer(),

                  Icon(Icons.arrow_forward, size: 30,color: Colors.white,),

                  SizedBox(width: 10,)
                ],
              ),
            ),
          ),

            const SizedBox(height: 20,),

            Container(
              margin: const EdgeInsets.only(left: 20, right: 20),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  children: [
                    const TextSpan(text: "By continuing, you agree that you have read and accept our ",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w400, fontSize: 14),
                    ),
                    TextSpan(
                      text: "T&Cs ",
                      style: TextStyle(color: HexColor('#607080'), fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    TextSpan(
                      text: "and",
                      style: TextStyle(color: HexColor('#607080'), fontWeight: FontWeight.w400, fontSize: 14),
                    ),
                    TextSpan(
                      text: " Privacy Policy",
                      style: TextStyle(color: HexColor('#607080'), fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20,),
          ],
        ),
      ),
    );
  }
}
