import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class SecurityKitScreen extends StatefulWidget {
  const SecurityKitScreen({super.key});

  @override
  State<SecurityKitScreen> createState() => _SecurityKitScreenState();
}

class _SecurityKitScreenState extends State<SecurityKitScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              height: 120,
              padding: const EdgeInsets.only(top: 30),
              decoration: BoxDecoration(
                  color: HexColor("#2C54C1")
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  SizedBox(width: 5,),

                  SizedBox(
                    width: 25,
                    height: 25,
                    child: Icon(Icons.arrow_back, color: Colors.white,),
                  ),

                  SizedBox(width: 10,),

                  Text("Security Kit", style: TextStyle(color: Colors.white,fontSize: 15, fontWeight: FontWeight.w500),),

                  Spacer()
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.only(left: 20, right: 20, top: 15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Security Kit",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Hey! You have to purchase this security kit to start getting leads",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🔹 Package card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B5BBC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Basic Package",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "₹1400",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🔹 Package details
                  _buildRow("T-Shirt", "₹500 (Qty-2)"),
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 4),
                  _buildRow("I-Card", "₹200"),
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 4),
                  _buildRow("ID Activation", "₹200"),
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 4),
                  _buildRow("Security Amount", "₹500"),
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 4),
                  _buildRow("Total Amount", "₹1400",
                      bold: true, color: HexColor("#2C54C1"), size: 16,),
                  const SizedBox(height: 24),

                  const Text(
                    "Select Delivery Address Type*",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 🔹 Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("-- -- -- --"),
                        items: const [
                          DropdownMenuItem(
                              value: "home", child: Text("Home Address")),
                          DropdownMenuItem(
                              value: "office", child: Text("Office Address")),
                        ],
                        onChanged: (value) {},
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔹 Search icon row
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.search, size: 20, color: Colors.black54),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 🔹 Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF3B5BBC)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              color: Color(0xFF3B5BBC),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B5BBC),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Pay",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // 🔹 Row for each detail
  Widget _buildRow(String label, String value,
      {bool bold = false, Color? color, double? size}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.black87,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              fontSize: size ?? 13,
            ),
          ),
        ],
      ),
    );
  }
}