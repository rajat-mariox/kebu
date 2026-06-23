import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class EarningScreen extends StatefulWidget {
  const EarningScreen({super.key});
  @override
  State<EarningScreen> createState() => _EarningScreenState();
}

class _EarningScreenState extends State<EarningScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
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

                  Text("Payment /Earningy", style: TextStyle(color: Colors.white,fontSize: 15, fontWeight: FontWeight.w500),),

                  Spacer()
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset("assets/calendar.png", height: 25,width: 25,),
                          const SizedBox(width: 6),
                          const Text(
                            "Oct 2025",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 35,
                        padding: const EdgeInsets.all(6),
                        child: Image.asset("assets/filter_1.png"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Stats Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard("₹1259", "Total Earning", HexColor("#2C54C1"), HexColor("#133DAF")),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard("₹1259", "Total Due", HexColor("#F0443E"), HexColor("#133DAF")),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _buildStatCard("₹1259", "Total Payout Amount", HexColor("#3CAE5C"), HexColor("#168235")),

                  const SizedBox(height: 24),

                  // 🔹 Payment Transfer Title
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Payment Transfer",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18),
                            const SizedBox(width: 6),
                            const Text(
                              "Oct 2025",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              height: 35,
                              padding: const EdgeInsets.all(6),
                              child: Image.asset("assets/filter_1.png"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Payment List
                  _buildPaymentCard(
                    name: "Alexis Lockman",
                    bookingId: "#123",
                    id: "#12",
                    status: "Pending",
                    method: "Cash",
                    amount: "₹1500",
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentCard(
                    name: "Maryse Kirlin",
                    bookingId: "#124",
                    id: "#14",
                    status: "Pending",
                    method: "Cash",
                    amount: "₹1500",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20,),
          ],
        ),
      ),
    );
  }



  // 🔹 Stat Card Widget
  Widget _buildStatCard(String value, String title, Color color, Color bg,) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            width: 36,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bg.withOpacity(0.3),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Image.asset("assets/discount.png", height: 25,),
          ),
        ],
      ),
    );
  }

  // 🔹 Payment Card Widget
  Widget _buildPaymentCard({
    required String name,
    required String bookingId,
    required String id,
    required String status,
    required String method,
    required String amount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name and Booking ID Row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  bookingId,
                  style: TextStyle(
                    color: HexColor("#2D52C0"),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildDetailRow("ID", id),
          _buildDetailRow("Status", status),
          _buildDetailRow("Method", method),
          _buildDetailRow("Amount Paid", amount, bold: true, color: HexColor("#2D52C0")),
        ],
      ),
    );
  }

  // 🔹 Row for Details
  Widget _buildDetailRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 10, right: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.black87,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}