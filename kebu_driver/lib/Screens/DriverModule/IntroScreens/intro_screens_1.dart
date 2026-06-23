import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/LoginScreen/login_screen.dart';


class IntroScreens extends StatefulWidget {
  const IntroScreens({super.key});

  @override
  State<IntroScreens> createState() => _IntroScreensState();
}

class _IntroScreensState extends State<IntroScreens> {

  int selectedIndex = 0;
  Timer? timer;
  List<TitleModel> list = [];

  // Design tokens (Figma: kebu-one / Splash Screen)
  static final Color _bgColor = HexColor("#F8FAFC");
  static final Color _headingColor = HexColor("#132235");
  static final Color _subtitleColor = HexColor("#364B63");
  static final Color _dotActiveColor = HexColor("#FFD015");
  static final Color _dotInactiveColor = HexColor("#D3DDE7");
  static final Color _linkColor = HexColor("#364B63");
  static final Color _tncColor = HexColor("#607080");

  @override
  void initState() {
    list.add(TitleModel(
      image: "assets/intro_driver_hero.png",
      title: "Making your drive best is our responsibility",
      description: "Reliable rides, fair earnings and full support on every trip.",
    ));
    list.add(TitleModel(
      image: "assets/intro_image_2.png",
      title: "Send Parcels Hassle-Free",
      description: "From small packets to big shipments — track your delivery live, secure & on time.",
    ));
    list.add(TitleModel(
      image: "assets/intro_image_3.png",
      title: "Trusted Professionals at Your Doorstep",
      description: "Electricians, cleaners, beauticians & more — verified experts just a tap away.",
    ));

    timerData();
    super.initState();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  timerData() {
    timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      selectedIndex = (selectedIndex + 1) % list.length;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Hero illustration with rounded frame
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: width * 0.82,
                  height: width * 0.82,
                  child: Image.asset(
                    list[selectedIndex].image,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Heading + subtitle
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    list[selectedIndex].title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      height: 41 / 34,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.bold,
                      color: _headingColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    list[selectedIndex].description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w400,
                      color: _subtitleColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Page indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(list.length, (index) {
                  final bool active = index == selectedIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.only(right: index == list.length - 1 ? 0 : 8),
                    height: 10,
                    width: active ? 32 : 10,
                    decoration: BoxDecoration(
                      color: active ? _dotActiveColor : _dotInactiveColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  );
                }),
              ),

              const Spacer(flex: 3),

              // Get Started button
              _GetStartedButton(
                onTap: () => pushTo(context, const LoginScreen()),
              ),

              const SizedBox(height: 16),

              // Terms & Privacy
              _termsText(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termsText() {
    final TextStyle linkStyle = GoogleFonts.nunito(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
      color: _linkColor,
      decoration: TextDecoration.underline,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.nunito(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w400,
          color: _tncColor,
        ),
        children: [
          const TextSpan(
            text: "By continuing, you agree that you have read and accept our ",
          ),
          TextSpan(text: "T&Cs", style: linkStyle),
          const TextSpan(text: " and "),
          TextSpan(text: "Privacy Policy", style: linkStyle),
        ],
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GetStartedButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [HexColor("#FFD546"), HexColor("#FF155E")],
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Get Started",
              style: TextStyle(
                fontSize: 17,
                height: 22 / 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward, size: 22, color: Colors.white),
          ],
        ),
      ),
    );
  }
}


class TitleModel {
  String image;
  String title;
  String description;

  TitleModel({required this.image, required this.title, required this.description});
}
