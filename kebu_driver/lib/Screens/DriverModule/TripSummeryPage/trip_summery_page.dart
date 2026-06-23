import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';


class TripSummeryPage extends StatefulWidget {
  const TripSummeryPage({super.key});

  @override
  State<TripSummeryPage> createState() => _TripSummeryPageState();
}

class _TripSummeryPageState extends State<TripSummeryPage> {
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color boxBorder = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      body: SingleChildScrollView(
        child: Column(
          children: [
            commonAppBar(
                height : 100,
                context : context,
                child: Container(
                  padding: const EdgeInsets.only(top: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: ()
                        {
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.only(left: 16),
                          width: 40,
                          height: 35,
                          alignment: Alignment.center,
                          child: Image.asset("assets/back_arrow.png", color: Colors.black,),
                        ),
                      ),

                      const SizedBox(width: 8,),

                      const Text(
                        "#0CAC6C64",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                    ],
                  ),
                )
            ),

            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: HexColor("#E1E6EF")),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("PICKUP & DESTINATION",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue.shade800)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.radio_button_checked, color: Colors.green),
                          Container(width: 2, height: 30, color: Colors.grey),
                          const Icon(Icons.location_on, color: Colors.red),
                        ],
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Started : 01 Jan 202, 11:47AM",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("Bus Sta Upas, Majestic, Bengaluru, Karnataka 560009"),
                            SizedBox(height: 12),
                            Text("Ended : 01 Jan 202, 01:14 PM",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("M.G. Railway Colony, Majestic, Bengaluru, Karnataka 560023"),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 3),

            // BASIC DETAILS
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: HexColor("#E1E6EF")),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("BASIC DETAILS",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue.shade800)),
                  const SizedBox(height: 12),
                  infoRow("Trip ID:", "#0CAC6C64"),
                  infoRow("Trip Type:", "Round Trip"),
                  infoRow("Trip Distance:", "89.36 km"),
                  infoRow("Trip Duration:", "3h 00min"),
                  infoRow("Vehicle Type:", "Automatic - Sedan"),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ESTIMATED FARE DETAILS
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: HexColor("#E1E6EF")),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ESTIMATED FARE DETAILS",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue.shade800)),
                  const SizedBox(height: 12),
                  infoRow("Estimated Total Fare:", "₹1500"),
                  const Divider(),
                  const Center(
                    child: Column(
                      children: [
                        Text("Earned money from trip:",
                            style: TextStyle(color: Colors.blue)),
                        SizedBox(height: 4),
                        Text("₹250",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w400))),
        ],
      ),
    );
  }
}
