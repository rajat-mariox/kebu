import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';


class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [

            cleaningAppBar(
                height : 160,
                context : context,
                child: Container(
                  padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
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

                            const SizedBox(width: 6,),
                          ],
                        ),
                      ),

                      const Text("Update Booking", style: TextStyle(color: Colors.white, fontSize: 16),),

                      const Spacer(),
                    ],
                  ),
                )
            ),

            Container(
              margin: const EdgeInsets.only(top: 120),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                color: Colors.white
              ),
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: Column(
                children: [

                  const SizedBox(height: 20,),

                  Row(
                    children: [
                      const Text(
                        'Booking ID',
                        style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                      ),

                      const Spacer(),

                      Text(
                        '#123',
                        style: TextStyle(color: HexColor("#2C54C1"), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15,),

                  Divider(color: HexColor("#EBEBEB"),height: 1,),

                  const SizedBox(height: 15,),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Television',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text(
                                'Date :  ',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                              Text(
                                '26 Jan, 2022',
                                style: TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: HexColor("#6C757D")),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                'Time :  ',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                              Text(
                                '04:00 PM',
                                style: TextStyle(fontWeight: FontWeight.w400, fontSize: 12, color: HexColor("#6C757D")),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/television_image.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: const Text(
                      'About Customer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Customer Card
                  Container(
                    decoration: BoxDecoration(
                      color: HexColor("#F6F7F9"),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.only(left: 25, right: 25, top: 25, bottom: 25),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            // Customer Image
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: NetworkImage(
                                  'https://randomuser.me/api/portraits/women/68.jpg'),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rose Customer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.email_outlined,
                                          size: 16, color: Colors.black),
                                      SizedBox(width: 6),
                                      Text('example@gmail.com',
                                        style: TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.location_on_outlined,
                                          size: 16, color: Colors.black),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text('1901 Thornridge Cirav...',
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 25),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon:  const Icon(Icons.call_outlined, size: 18, color: Colors.white,),
                                label: const Text('Call', style: TextStyle(color: Colors.white, fontSize: 14),),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2F5AE3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon:  const Icon(Icons.chat_outlined, size: 18, color: Colors.black),
                                label:  const Text('Chat', style: TextStyle(color: Colors.black, fontSize: 14),),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.grey),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),



                  const SizedBox(height: 25),

                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Payment Details Card
                  Container(
                    decoration: BoxDecoration(
                      color: HexColor("#F6F7F9"),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildPaymentRow('ID', '#123', isLink: true),

                        Container(
                          margin: const EdgeInsets.only(left: 20, right: 20),
                            child: Divider(height: 1, color: HexColor("#EBEBEB"),)),

                        _buildPaymentRow('Method', 'Cash'),

                        Container(
                            margin: const EdgeInsets.only(left: 20, right: 20),
                            child: Divider(height: 1, color: HexColor("#EBEBEB"),
                            )
                        ),

                        _buildPaymentRow('Status', 'Pending', color: Colors.green),

                        const SizedBox(height: 12),
                        Container(
                          height: 45,
                          width: double.infinity,
                          margin: const EdgeInsets.only(left: 20, right: 20),
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD9534F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Cancel Booking',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                   SizedBox(
                     width: MediaQuery.of(context).size.width,
                     child: const Text(
                      'Price Detail',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                                       ),
                   ),
                  const SizedBox(height: 10),

                  // Price Details
                  Container(
                    decoration: BoxDecoration(
                      color: HexColor("#F6F7F9"),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [

                        const SizedBox(height: 10,),

                        _buildPriceRow('Rate', '₹45.00', color: HexColor("#6C757D")),

                        Container(
                            margin: const EdgeInsets.only(left: 25, right: 25),
                            child: Divider(height: 1, color: HexColor("#EBEBEB"),
                            )
                        ),

                        _buildPriceRow('Quantity', '*2',color: HexColor("#6C757D")),

                        Container(
                            margin: const EdgeInsets.only(left: 25, right: 25),
                            child: Divider(height: 1, color: HexColor("#EBEBEB"),
                            )
                        ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text(
                              "Discount",
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(width: 10,),

                            Text(
                              "(5% off)",
                              style: TextStyle(
                                color: HexColor("#3BA859"),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),

                            const Spacer(),

                            Text(
                              "- ₹23.66",
                              style: TextStyle(
                                color: HexColor("#3BA859"),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                        Container(
                            margin: const EdgeInsets.only(left: 25, right: 25),
                            child: Divider(height: 1, color: HexColor("#EBEBEB"),
                            )
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const Text(
                                "Coupon",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),

                              const SizedBox(width: 8,),

                              Text(
                                "(AB45789A)",
                                style: TextStyle(
                                  color: HexColor("#2C54C1"),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),

                              const Spacer(),

                              Text(
                                "- ₹23.66",
                                style: TextStyle(
                                  color: HexColor("#3BA859"),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                            margin: const EdgeInsets.only(left: 25, right: 25),
                            child: Divider(height: 1, color: HexColor("#EBEBEB"),
                            )
                        ),

                        _buildPriceRow('Subtotal', '₹459',color: HexColor("#6C757D")),

                        Container(
                            margin: const EdgeInsets.only(left: 25, right: 25),
                            child: Divider(height: 1, color: HexColor("#EBEBEB"),
                            )
                        ),

                        _buildPriceRow('Total Amount', '₹1255',
                            isBold: true, color: const Color(0xFF2F5AE3)),

                        const SizedBox(height: 10,),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Reviews Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Reviews",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "View All",
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Reviews List
                  _buildReview("Donna Bins", "02 Dec"),
                  _buildReview("Ashutosh Pandey", "25 Jan"),
                  _buildReview("Kristin Watson", "30 Jan"),
                  _buildReview("Jerome Bell", "25 Feb"),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String title, String value,
      {bool isLink = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.black, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: color ??
                  (isLink ? const Color(0xFF2F5AE3) : Colors.black87),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildReview(String name, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            child: Image.asset("assets/review_image.png"
              ,width: 42,
              height: 42,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, )),
                    Text(date, style:  TextStyle(color: HexColor("#6C757D"), fontSize: 13,)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, color: HexColor("#FFBD00"), size: 16),
                    Icon(Icons.star, color: HexColor("#FFBD00"), size: 16),
                    Icon(Icons.star, color: HexColor("#FFBD00"), size: 16),
                    Icon(Icons.star, color: HexColor("#FFBD00"), size: 16),
                    Icon(Icons.star_half, color: HexColor("#FFBD00"), size: 16),
                    const SizedBox(width: 6),
                    const Text("4.5", style: TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Amet minim mollit non deserunt ullamco est sit aliqua dolor do amet.",
                  style: TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String title, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.black87,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.black87,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}