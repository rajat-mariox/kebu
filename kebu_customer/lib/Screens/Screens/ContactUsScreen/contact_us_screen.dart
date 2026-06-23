import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/Screens/FaqScreen/faq_screen.dart';
import 'package:kebu_customer/Screens/Screens/SupportChatScreen/support_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  static const String supportEmail = "admin@kebu.com";
  static const String supportPhone = "+911800000000";

  Future<void> _launch(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _toast("Could not open ${uri.scheme}");
      }
    } catch (_) {
      _toast("Could not open ${uri.scheme}");
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Gradient header
          commonAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 55, left: 12, right: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back_ios_new,
                          size: 18, color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Contact Us",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const NotificationIconButton(height: 33),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(top: 120),
            width: MediaQuery.of(context).size.width,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Contact Us",
                  style: GoogleFonts.dmSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.4,
                    color: HexColor("#040415"),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please choose what types of support do you need and let us know.",
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    height: 1.6,
                    letterSpacing: -0.35,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 26),

                // 2x2 grid
                Row(
                  children: [
                    Expanded(
                      child: _card(
                        icon: Icons.chat_bubble_rounded,
                        tint: HexColor("#4FBF67"),
                        title: "Support Chat",
                        subtitle: "24x7 Online Support",
                        onTap: () =>
                            pushTo(context, const SupportChatScreen()),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: _card(
                        icon: Icons.call_rounded,
                        tint: HexColor("#FF6628"),
                        title: "Call Center",
                        subtitle: "24x7 Customer Service",
                        onTap: () =>
                            _launch(Uri(scheme: 'tel', path: supportPhone)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _card(
                        icon: Icons.mail_rounded,
                        tint: HexColor("#9B51E0"),
                        title: "Email",
                        subtitle: supportEmail,
                        onTap: () =>
                            _launch(Uri(scheme: 'mailto', path: supportEmail)),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: _card(
                        icon: Icons.help_rounded,
                        tint: HexColor("#FFCF19"),
                        title: "FAQ",
                        subtitle: "+50 Answers",
                        onTap: () => pushTo(context, const FaqScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // Go to Homepage
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: HexColor("#D9D9D9")),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Go to Homepage",
                          style: GoogleFonts.dmSans(
                            color: HexColor("#1B1D21"),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.arrow_forward,
                            size: 16, color: HexColor("#1B1D21")),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required Color tint,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: HexColor("#E6E8EC")),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tint.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: tint, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                letterSpacing: -0.3,
                color: HexColor("#23262F"),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                letterSpacing: -0.2,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
