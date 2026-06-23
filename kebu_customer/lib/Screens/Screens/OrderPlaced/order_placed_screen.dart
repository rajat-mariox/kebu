import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/parcel_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';

class OrderPlacedScreen extends StatefulWidget {
  const OrderPlacedScreen({super.key});
  @override
  State<OrderPlacedScreen> createState() => _OrderPlacedScreenState();
}

class _OrderPlacedScreenState extends State<OrderPlacedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [

            sendParcelAppBar(
                height : 160,
                context : context,
                child: Container(
                  padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
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
                              child: const Icon(Icons.arrow_back_ios, size: 20,color: Colors.white,),
                            ),

                            const SizedBox(width: 10,),
                          ],
                        ),
                      ),

                      const Spacer(),

                      const Text("Order Placed", style: TextStyle(color: Colors.white, fontSize: 16),),

                      const Spacer(),

                      const NotificationIconButton(),
                    ],
                  ),
                )
            ),

            Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.only(top: 120),
            //  padding: EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  const SizedBox(height: 30,),

                  Image.asset("assets/order_placed.png", height: 200,),

                  const SizedBox(height: 20,),

                  const Text(
                    "Order Placed",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      text: 'Your order has been Successfully placed,\n For any info call',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                      children: [
                        TextSpan(
                          text: '(+1) 999 999 999 ',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFE53935),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  Container(
                    height: 1,
                    width: MediaQuery.of(context).size.width,
                    color: Colors.grey.withOpacity(0.3),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    "YOUR DRIVER",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey.withOpacity(0.4)
                    ),
                  ),

                  const SizedBox(height: 3),

                  const Text(
                    "Working Hour : 7PM - 9AM",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.only(top: 20, bottom: 20),
                    margin: const EdgeInsets.only(left: 40, right: 40, top: 20),
                    decoration: BoxDecoration(
                      color: HexColor("#E8E8E8").withOpacity(0.4),
                      borderRadius: BorderRadius.circular(30)
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset("assets/profile_image.png", height: 60, width: 60,),

                            const SizedBox(width: 12,),

                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Gabriel Payne", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 15),),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, size: 15,color: HexColor("#FFAA1B"),),
                                    Icon(Icons.star, size: 15,color: HexColor("#FFAA1B"),),
                                    Icon(Icons.star, size: 15,color: HexColor("#FFAA1B"),),
                                    Icon(Icons.star, size: 15,color: HexColor("#FFAA1B"),),
                                    Icon(Icons.star, size: 15,color: HexColor("#04041533").withOpacity(0.2),),

                                    const SizedBox(width: 5,),

                                    Container(
                                      child: Text("(32 reviews)", style: TextStyle(
                                        color: HexColor("#04041533").withOpacity(0.2),
                                        fontSize: 11
                                      ),),
                                    )
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),

                        const SizedBox(height: 20,),

                        Container(
                          height: 1,
                          color: Colors.grey.withOpacity(0.3),
                        ),

                        const SizedBox(height: 20,),
                        
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset("assets/call_i.png", width: 50,),

                            const SizedBox(width: 25,),

                            Image.asset("assets/message_i.png", width: 50,),

                            const SizedBox(width: 25,),

                            Image.asset("assets/bbt.png", width: 50,),
                          ],
                        )
                      ],
                    ),
                  ),


                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}
