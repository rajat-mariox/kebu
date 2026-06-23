import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
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
                Text("Booking History", style: TextStyle(color: Colors.white,fontSize: 15, fontWeight: FontWeight.w500),),

                Spacer()
              ],
            ),
          ),

          const SizedBox(height: 20,),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Container(
              child: Row(
                children: [
                  const SizedBox(width: 20,),
                  _buildTabButton("On Going", true),
                  const SizedBox(width: 12,),
                  _buildTabButton("Pending", false),
                  const SizedBox(width: 12,),
                  _buildTabButton("Completed", false),
                  const SizedBox(width: 20,),
                ],
              ),
            ),
          ),

          // Service Card
         Expanded(
           child: ListView.builder(
             padding: const EdgeInsets.all(10),
             itemCount: 5,
               itemBuilder: (context, index){
                     return  Container(
                       margin: const EdgeInsets.symmetric(horizontal: 12,vertical: 8),
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: HexColor("#EBEBEB"), width: 1)
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text(
                                 "Electronic Device Fixing",
                                 style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                               ),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: HexColor("#2D52C0"),
                                   borderRadius: BorderRadius.circular(100),
                                 ),
                                 child: const Text("#123",
                                     style: TextStyle(
                                         color: Colors.white,
                                         fontSize: 13,
                                         fontWeight: FontWeight.bold
                                     )
                                 ),
                               ),
                             ],
                           ),
                           const SizedBox(height: 10),

                           Row(
                             children: [
                               Text(
                                 "₹120",
                                 style: TextStyle(
                                     fontSize: 18,
                                     color: HexColor("#2D52C0"),
                                     fontWeight: FontWeight.bold
                                 ),
                               ),

                               const SizedBox(width: 6,),

                               Text(
                                 "21% Off",
                                 style: TextStyle(
                                     fontSize: 13,
                                     color: HexColor("#3CAE5C"),
                                     fontWeight: FontWeight.w500
                                 ),
                               ),
                             ],
                           ),

                           const SizedBox(height: 10),
                           _infoRow("assets/location.png", "3517 W. Gray St. Utica, Pennsylvania 57867"),
                           const SizedBox(height: 8),
                           _infoRow("assets/calendar_2.png", "28 February, 2022 At 8:30 AM"),
                           const SizedBox(height: 8),
                           _infoRow("assets/person_icon.png", "Wiley Waites"),
                         ],
                       ),
                     );
              }),
         )

        ],
      ),
    );
  }

  static Widget _infoRow(String icon, String text) {
    return Row(
      children: [
        Image.asset(icon, height: 20,width: 20,color: Colors.black,),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: HexColor("#6C757D")
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildTabButton(String label, bool isActive) {
    return Expanded(
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isActive ? HexColor("#2E50BF") :  const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                color: isActive ? Colors.white : Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 13
            ),
          ),
        ),
      ),
    );
  }
}
