import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/book_a_ride_appbar.dart';
import 'package:kebu_customer/Screens/BookARideModule/DestinationSummeryScreen/destination_summery_screen.dart';
import 'package:kebu_customer/Services/booking_api_service.dart';
import 'package:kebu_customer/Services/socket_service.dart';


class BookACab extends StatefulWidget {
  const BookACab({super.key});

  @override
  State<BookACab> createState() => _BookACabState();
}

class _BookACabState extends State<BookACab> {

  String driverName = 'Ramesh Yadav';
  String vehicleName = 'Toyota Corolla';
  String vehicleNumber = 'DL09 EV8987';
  double driverRating = 4.7;
  String fare = '328';
  String eta = '3 mins';
  String? bookingId;
  bool isBooking = true;

  @override
  void initState() {
    super.initState();
    _createBooking();
    _listenToSocket();
  }

  Future<void> _createBooking() async {
    final response = await BookingApiService.createBooking(
      pickupLat: 28.6139,
      pickupLng: 77.2090,
      pickupAddress: 'My current location',
      dropLat: 28.5355,
      dropLng: 77.3910,
      dropAddress: '3517 W. Gray St. Utica, Pennsylvania 57867',
      vehicleTypeId: 'NORMAL',
    );
    if (response.success && response.data != null && mounted) {
      final booking = response.data['booking'] ?? response.data;
      setState(() {
        bookingId = booking['_id'];
        driverName = booking['driver']?['name'] ?? driverName;
        vehicleName = booking['driver']?['vehicleName'] ?? vehicleName;
        vehicleNumber = booking['driver']?['vehicleNumber'] ?? vehicleNumber;
        driverRating = (booking['driver']?['rating'] ?? 4.7).toDouble();
        fare = '${booking['fare'] ?? booking['estimatedFare'] ?? 328}';
        isBooking = false;
      });
    } else if (mounted) {
      setState(() => isBooking = false);
    }
  }

  void _listenToSocket() {
    SocketService().onRideAccepted.listen((data) {
      if (mounted) {
        setState(() {
          driverName = data['driver']?['name'] ?? driverName;
          vehicleNumber = data['driver']?['vehicleNumber'] ?? vehicleNumber;
        });
      }
    });

    SocketService().onRideCompleted.listen((data) {
      if (mounted) {
        pushTo(context, const DestinationSummeryScreen());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          bookARideAppBar(
              height : 160,
              context : context,
              child: Container(
                padding: const EdgeInsets.only(top: 55, left: 15, right: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: (){
                        Navigator.pop(context);
                      },
                      child: Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(left: 5),
                            child: const Icon(Icons.arrow_back_ios, size: 20,color: Colors.black,),
                          ),

                          const SizedBox(width: 3,),

                          const Text("Book a cab", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),),

                        ],
                      ),
                    ),


                    const Spacer(),

                    Container(
                      child: Image.asset("assets/ride_notification_icon.png", height: 28,),
                    ),
                  ],
                ),
              )
          ),

          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            child: Container(
              margin: const EdgeInsets.only(top: 120),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
              ),
             child: Stack(
               children: [

                 Image.asset("assets/freepik__expand.png"),

                 Positioned(
                   top: 60,
                     left: 0,
                     right: 0,
                     child: Image.asset("assets/route_image.png", height: 200,)),

                 Column(
                   children: [

                     Expanded(child: Container()),

                     /// ✅ Bottom Ride Info Card
                     Align(
                       alignment: Alignment.bottomCenter,
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           /// Green “Reaching in 3 mins” bar
                           Container(
                             height: 50,
                             width: MediaQuery.of(context).size.width - 60,
                             padding: const EdgeInsets.symmetric(vertical: 10),
                             decoration: const BoxDecoration(
                               color: Color(0xFF4CAF50),
                               borderRadius: BorderRadius.only(topRight: Radius.circular(20), topLeft: Radius.circular(20))
                             ),
                             child: Center(
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   const Icon(Icons.bolt, color: Colors.white, size: 18),
                                   const SizedBox(width: 6),
                                   Text(
                                     "Reaching in 3 mins",
                                     style: GoogleFonts.poppins(
                                       fontSize: 14,
                                       color: Colors.white,
                                       fontWeight: FontWeight.w500,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                           ),

                           /// 🟨 Main Driver Card
                           Container(
                             width: double.infinity,
                             decoration: const BoxDecoration(
                               color: Color(0xFFFFE271),
                               borderRadius:
                               BorderRadius.vertical(top: Radius.circular(22)),
                             ),
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 /// Header Row
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.start,
                                   children: [

                                     const SizedBox(width: 34,),

                                     Text(
                                       "To Pay",
                                       style: GoogleFonts.poppins(
                                         fontSize: 13,
                                         color: Colors.black,
                                         fontWeight: FontWeight.w500,
                                       ),
                                     ),

                                     const Spacer(),

                                     Text(
                                       "\u20B9$fare",
                                       style: GoogleFonts.poppins(
                                         fontSize: 17,
                                         color: Colors.black,
                                         fontWeight: FontWeight.w700,
                                       ),
                                     ),

                                     const SizedBox(width: 30,),
                                   ],
                                 ),
                                 const SizedBox(height: 10),

                                 /// Car Info Row
                                 Container(
                                   margin: const EdgeInsets.only(left: 15, right: 15,),
                                   padding: const EdgeInsets.only(left: 10, top: 15, bottom: 15),
                                   decoration: BoxDecoration(
                                     color: Colors.white,
                                     borderRadius: BorderRadius.circular(12),
                                   ),
                                   child: Row(
                                     children: [
                                       Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text(
                                             vehicleName,
                                             style: GoogleFonts.poppins(
                                               fontSize: 13,
                                               fontWeight: FontWeight.w500,
                                               color: Colors.black,
                                             ),
                                           ),
                                           Text(
                                             vehicleNumber,
                                             style: GoogleFonts.poppins(
                                               fontSize: 14,
                                               fontWeight: FontWeight.w700,
                                               color: HexColor("#0F6992"),
                                             ),
                                           ),
                                           const SizedBox(height: 4),
                                           Container(
                                             padding: const EdgeInsets.symmetric(
                                                 horizontal: 10, vertical: 3),
                                             decoration: BoxDecoration(
                                               color: HexColor("#FFD546"),
                                               borderRadius: BorderRadius.circular(6),
                                             ),
                                             child: Text(
                                               "208 kg CO₂ Saved",
                                               style: GoogleFonts.poppins(
                                                 fontSize: 12,
                                                 color: Colors.black,
                                                 fontWeight: FontWeight.w500,
                                               ),
                                             ),
                                           ),
                                         ],
                                       ),
                                       const Spacer(),
                                       Image.asset(
                                         "assets/toyota.png",
                                         height: 60,
                                         fit: BoxFit.contain,
                                       ),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(height: 14),

                                 /// Driver Row
                                 Container(
                                   margin: const EdgeInsets.only(left: 15, right: 15,),
                                   child: Row(
                                     children: [
                                       ClipRRect(
                                         borderRadius: BorderRadius.circular(8),
                                         child: Image.asset(
                                           "assets/driver_icon.png",
                                           height: 45,
                                           width: 45,
                                           fit: BoxFit.cover,
                                         ),
                                       ),
                                       const SizedBox(width: 12),
                                       Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text(
                                             driverName,
                                             style: GoogleFonts.poppins(
                                               fontSize: 13,
                                               fontWeight: FontWeight.w600,
                                             ),
                                           ),
                                           Row(
                                             children: [
                                               Text(
                                                 "$driverRating",
                                                 style: GoogleFonts.poppins(
                                                   fontSize: 12,
                                                   color: Colors.black87,
                                                   fontWeight: FontWeight.w400,
                                                 ),
                                               ),
                                               const SizedBox(width: 4),
                                               const Icon(Icons.star,
                                                   color: Colors.white, size: 16),
                                               const SizedBox(width: 4),
                                               Text(
                                                 " |  ",
                                                 style: GoogleFonts.poppins(
                                                   fontSize: 12,
                                                   color: HexColor("#BFBFBF"),
                                                   fontWeight: FontWeight.w400,
                                                 ),
                                               ),

                                               Text(
                                                 "2000+ ",
                                                 style: GoogleFonts.poppins(
                                                   fontSize: 12,
                                                   color: Colors.black87,
                                                   fontWeight: FontWeight.w600,
                                                 ),
                                               ),

                                               Text(
                                                 "Rides",
                                                 style: GoogleFonts.poppins(
                                                   fontSize: 12,
                                                   color: Colors.black87,
                                                   fontWeight: FontWeight.w400,
                                                 ),
                                               )
                                             ],
                                           ),
                                         ],
                                       ),
                                     ],
                                   ),
                                 ),

                                 const SizedBox(height: 20),

                                 Divider(color: HexColor("#015EA3"), height: 0.3,),

                                 const SizedBox(height: 20),

                                 /// Buttons Row
                                 Container(
                                   margin: const EdgeInsets.only(left: 15, right: 15,),
                                   child: Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                     children: [
                                       Expanded(
                                         child: _bottomButton(
                                           icon: Icons.call,
                                           text: "Call",
                                           color: Colors.green.shade600,
                                         ),
                                       ),

                                       const SizedBox(width: 14,),

                                       Expanded(
                                         child: _bottomButton(
                                           icon: Icons.chat_bubble_outline,
                                           text: "Chat",
                                           color: Colors.blue.shade800,
                                         ),
                                       ),

                                       const SizedBox(width: 14,),

                                       Expanded(
                                         child: _bottomButton(
                                           icon: Icons.share_outlined,
                                           text: "Share",
                                           color: Colors.black,
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(height: 14),

                                 /// Footer Note
                                 Center(
                                   child: Text(
                                     "Use Electric, Save Nature",
                                     style: GoogleFonts.poppins(
                                       fontSize: 13,
                                       color: Colors.black87,
                                       fontWeight: FontWeight.w600,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                     ),
                   ],
                 ),


                 Positioned(
                   top: 15,
                   left: 16,
                   right: 16,
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Container(
                         padding:
                         const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                         decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(12),
                           boxShadow: const [
                             BoxShadow(
                               color: Colors.black12,
                               blurRadius: 5,
                               offset: Offset(0, 2),
                             ),
                           ],
                         ),
                         child: Text(
                           "OTP-565",
                           style: GoogleFonts.poppins(
                             fontSize: 11,
                             fontWeight: FontWeight.w600,
                             color: Colors.black,
                           ),
                         ),
                       ),
                       Container(
                         padding:
                         const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                         decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(12),
                           boxShadow: const [
                             BoxShadow(
                               color: Colors.black12,
                               blurRadius: 5,
                               offset: Offset(0, 2),
                             ),
                           ],
                         ),
                         child: Row(
                           children: [
                             const Icon(Icons.close, color: Colors.redAccent, size: 17),
                             const SizedBox(width: 4),
                             Text(
                               "Cancel Ride",
                               style: GoogleFonts.poppins(
                                 fontSize: 11,
                                 fontWeight: FontWeight.w600,
                                 color: Colors.redAccent,
                               ),
                             ),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
               ],
             ),
           ),
         )
        ],
      ),
    );
  }

  Widget _bottomButton(
      {required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}