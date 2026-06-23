import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';


class ServiceDetailsBottomSheet extends StatelessWidget {
  const ServiceDetailsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding:
            const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close Button

                const SizedBox(height: 6,),

                Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: HexColor("#2369CF").withOpacity(0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Icon(Icons.close,
                          color: HexColor("#2369CF"), size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Header
                Text(
                  "Service Details",
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),

                // Service card
                Image.asset("assets/form_jet_ac_service.png",fit: BoxFit.cover,),

                const SizedBox(height: 12,),

                _buildCheckItem("Indoor unit Cleaning"),

                const SizedBox(height: 7,),

                _buildCheckItem("Outdoor unit Cleaning"),

                const SizedBox(height: 7,),

                _buildCheckItem("Best for all mediun household and small offices."),

                const SizedBox(height: 20),

                // How it works
                Text(
                  "How it works",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                _buildHowItWorksItem(
                  title: "Pre-Service Inspection:",
                  desc:
                  "We begin with a thorough check-up of your AC, including a complimentary gas level assessment.",
                ),
                const SizedBox(height: 12),
                _buildHowItWorksItem(
                  title: "Mess-Free Service Jacket:",
                  desc:
                  "Our AC is draped with a protective jacket to ensure no spills occur during servicing.",
                ),
                const SizedBox(height: 12),
                _buildHowItWorksItem(
                  title: "Indoor & Outdoor Unit Cleaning:",
                  desc: "",
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckItem(String text) {
    return Row(
      children: [
        const SizedBox(width: 10,),

        const Icon(Icons.check_circle,
            color: Color(0xFF36A84E), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksItem({required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF36A84E), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: "$title ",
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: desc,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}