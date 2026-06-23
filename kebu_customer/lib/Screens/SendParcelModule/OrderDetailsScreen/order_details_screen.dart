import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/parcel_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/Screens/OrderPlaced/order_placed_screen.dart';
import 'package:kebu_customer/Services/delivery_api_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  // Booking context carried from the Confirm Location → Loading Point flow.
  final String vehicleTypeId;
  final String deliveryMode;
  final int workers;
  final String? scheduledAt;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropLat;
  final double dropLng;
  final String dropAddress;
  const OrderDetailsScreen({
    super.key,
    this.vehicleTypeId = '',
    this.deliveryMode = 'INSTANT',
    this.workers = 0,
    this.scheduledAt,
    this.pickupLat = 0,
    this.pickupLng = 0,
    this.pickupAddress = 'Current location',
    this.dropLat = 0,
    this.dropLng = 0,
    this.dropAddress = 'Destination',
  });
  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {

  bool isCreating = false;

  Future<void> _createDelivery() async {
    if (isCreating) return;
    setState(() => isCreating = true);
    // Real pickup/drop chosen on the Confirm Location screen. Contact details
    // are required by the backend; we send the customer's own as a sensible
    // default until a dedicated contact form is added.
    final pickup = {
      'lat': widget.pickupLat,
      'lng': widget.pickupLng,
      'address': widget.pickupAddress,
      'contactName': 'Customer',
      'contactPhone': '0000000000',
    };
    final drops = [
      {
        'lat': widget.dropLat,
        'lng': widget.dropLng,
        'address': widget.dropAddress,
        'contactName': 'Recipient',
        'contactPhone': '0000000000',
      }
    ];
    final response = await DeliveryApiService.createDelivery(
      pickup: pickup,
      drops: drops,
      vehicleTypeId:
          widget.vehicleTypeId.isNotEmpty ? widget.vehicleTypeId : 'CARGO_BIKE',
      deliveryMode: widget.deliveryMode,
      workers: widget.workers,
      scheduledAt: widget.scheduledAt,
      packageDescription: 'Parcel delivery',
    );
    if (!mounted) return;
    setState(() => isCreating = false);
    if (response.success) {
      pushTo(context, const OrderPlacedScreen());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? "Could not place order")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
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

                      const Text("Order Details", style: TextStyle(color: Colors.white, fontSize: 16),),

                      const Spacer(),

                      const NotificationIconButton(),
                    ],
                  ),
                )
            ),

            Container(
              padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
              margin: const EdgeInsets.only(top: 120),
              decoration: BoxDecoration(
                color: HexColor("#F6F6F6"),
                borderRadius: const BorderRadius.only(topRight: Radius.circular(20), topLeft: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                child: Image.asset(
                                  'assets/order_map_view.png',
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "1.2 km",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    height : 20,
                                    width: 20,
                                    decoration: BoxDecoration(
                                      border: Border.all(width: 6, color: Colors.black),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.pickupAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Icon(Icons.more_vert, size: 18),
                              ),
                              Row(
                                children: [
                                  Image.asset("assets/star_with_location.png", width: 22,height: 22,fit: BoxFit.cover,),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.dropAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Order Details Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Order Details",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Image.asset("assets/edit_squres.png",height: 16,width: 16,)
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        const SizedBox(height: 20,),

                        Column(
                          children: [
                            Row(
                              children: [

                                const SizedBox(width: 20,),

                                Container(
                                  height: 70,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEAEA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/truck_gg.png',
                                      height: 30,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Mini Truck",
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        "~ 1.8 Ton, 9 Feet",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "₹22",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(width: 20,),
                              ],
                            ),

                            const SizedBox(height: 16),

                            const Divider(),

                            const SizedBox(height: 20),
                            _buildRow("Worker/Labours (2)", "₹20"),

                            const SizedBox(height: 20),

                            const Divider(),

                            const SizedBox(height: 16),
                            _buildRow("Service Charge", "₹2"),
                            const SizedBox(height: 16),

                            Row(
                              children: [

                                const SizedBox(width: 20,),

                                Row(
                                  children: [
                                    Text("Promo Code ",
                                      style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),),

                                    const SizedBox(width: 5,),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: HexColor("#EBFCEF"),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "A9CCXJP",
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: HexColor('#56C364'),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.close, color: HexColor('#56C364'), size: 13),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                Text(
                                  "-₹20",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),

                                const SizedBox(width: 20,),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            Row(
                              children: [

                                const SizedBox(width: 20,),

                                Text(
                                  "Total",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600
                                  ),
                                ),

                                const SizedBox(width: 6,),

                                Text(
                                  "(Estimated Cost)",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                  ),
                                ),

                                const Spacer(),

                                Text(
                                  "₹56",
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(width: 20,),
                              ],
                            ),

                            const SizedBox(height: 25),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Payment Selection
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Image.asset("assets/bank_card.png", height: 35,width: 45,),
                              const SizedBox(height: 8),
                              Text(
                                "Online Payment",
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black,
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Image.asset("assets/case_icon.png", height: 35, width: 45,),
                              const SizedBox(height: 8),
                              Text(
                                "Cash",
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w500
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE43D30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: isCreating ? null : _createDelivery,
                      child: isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              "Confirm (₹15)",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),


                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      children: [

        const SizedBox(width: 20,),

        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),

        const Spacer(),

        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(width: 20,),
      ],
    );
  }
}