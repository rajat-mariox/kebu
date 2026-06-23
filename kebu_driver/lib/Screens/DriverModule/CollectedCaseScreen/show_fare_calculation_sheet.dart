import 'package:kebu_driver/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

void showFareCalculationSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return const FareCalculationSheet();
    },
  );
}

class FareCalculationSheet extends StatelessWidget {
  const FareCalculationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF14233B);
    const lightGreen = Color(0xFFBFD87D);
    const dividerColor = Color(0xFFE6EEF2);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Blurred background
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),

        // Bottom Sheet
        DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              child: Stack(
                children: [
                  // Sheet content
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                    margin: const EdgeInsets.only(top: 60),
                    child: ListView(
                      controller: scrollController,
                      children: [
                        const Center(
                          child: Text(
                            "Fare Calculations",
                            style: TextStyle(
                              color: darkBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _fareRow("Driver Fee:", "+ ₹430.8"),
                        _fareRow("Convenience Fee:", "+ ₹111.94"),
                        _fareRow("GoChauffeurs Secure Fee:", "+ ₹15.0"),
                        _fareRow("GST:", "+ ₹22.85"),

                        const SizedBox(height: 10),
                        const Divider(color: dividerColor, thickness: 1),

                        _fareRow("Sub Total:",
                            "₹580.59", isBold: true, color: HexColor('#015EA3')),

                        _fareRow("Rounding Up:", "+ ₹0.41"),
                        const SizedBox(height: 10),
                        const Divider(color: dividerColor, thickness: 1),

                        _fareRow("Grand Total:",
                            "₹581", isBold: true, color: AppColors.greenColor),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),

                  // Close Button
                  Positioned(
                    top: 0,
                    left : 0,
                    right : 0,
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: const BoxDecoration(
                        color: darkBlue,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _fareRow(String title, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: color ?? const Color(0xFF14233B),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color ?? const Color(0xFF14233B),
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
