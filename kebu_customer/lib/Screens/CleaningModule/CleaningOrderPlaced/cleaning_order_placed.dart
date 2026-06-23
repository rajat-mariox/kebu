import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/CleaningModule/HouseholdLiveTracking/household_live_tracking_screen.dart';
import 'package:kebu_customer/Screens/Screens/DashboardScreen/dashboard_screen.dart';
import 'package:kebu_customer/Services/socket_service.dart';


class CleaningOrderPlaced extends StatefulWidget {
  const CleaningOrderPlaced({super.key});

  @override
  State<CleaningOrderPlaced> createState() => _CleaningOrderPlacedState();
}

class _CleaningOrderPlacedState extends State<CleaningOrderPlaced> {
  StreamSubscription<Map<String, dynamic>>? _acceptedSub;
  Map<String, dynamic>? _provider;
  Map<String, dynamic>? _booking;

  @override
  void initState() {
    super.initState();
    SocketService().connect();
    _acceptedSub = SocketService().onServiceBookingAccepted.listen((data) {
      if (!mounted) return;
      final provider = data['provider'];
      final booking = data['booking'];
      if (provider is Map) {
        setState(() => _provider = Map<String, dynamic>.from(provider));
      }
      if (booking is Map) {
        setState(() => _booking = Map<String, dynamic>.from(booking));
      }
    });
  }

  @override
  void dispose() {
    _acceptedSub?.cancel();
    super.dispose();
  }

  void _openTracking() {
    final booking = _booking;
    final provider = _provider;
    if (booking == null || provider == null) return;
    final bookingId = booking['_id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return;
    final address = (booking['address'] is Map)
        ? Map<String, dynamic>.from(booking['address'])
        : const <String, dynamic>{};
    final lat = (address['lat'] as num?)?.toDouble();
    final lng = (address['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    pushTo(
      context,
      HouseholdLiveTrackingScreen(
        bookingId: bookingId,
        provider: provider,
        destinationLat: lat,
        destinationLng: lng,
        destinationAddress: (address['fullAddress'] ?? '').toString(),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          cleaningAppBar(
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

                Image.asset("assets/clening_orderPlaced.png", height: 200,),

                const SizedBox(height: 20,),

                Text(
                  _provider == null ? "Finding a Provider..." : "Provider Assigned",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  margin: const EdgeInsets.only(left: 15, right: 15),
                  child: _provider == null
                      ? Text(
                          "Your order has been placed. We're searching for a nearby professional — this usually takes under a minute.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: HexColor("#808080"),
                            fontSize: 12,
                          ),
                        )
                      : Column(
                          children: [
                            Text(
                              (_provider!['fullName'] ?? 'Your provider').toString(),
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (_provider!['mobileNumber'] ?? '').toString(),
                              style: GoogleFonts.poppins(
                                color: HexColor("#4FBF67"),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 60),

                const Text(
                  "Today at 2 PM",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black
                  ),
                ),

                const SizedBox(height: 10,),

                Container(
                  padding: const EdgeInsets.only(left: 18, right: 18, top: 7, bottom: 7),
                  decoration: BoxDecoration(
                    color: HexColor("#E1F4E5"),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    "ADD TO CALENDER",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: HexColor("#4FBF67")
                    ),
                  ),
                ),

                const SizedBox(height: 3),

                const Spacer(),

                Divider(color: HexColor("#000000").withOpacity(0.07),),

                const SizedBox(height: 24,),

                if (_provider != null && _booking != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HexColor("#531E96"),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _openTracking,
                      child: const Text(
                        'Track Provider',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // Go to Homepage Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: Colors.black12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      replaceRoute(context, const DashboardScreen());
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Go to Homepage ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(Icons.arrow_forward, color: Colors.black, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30,)


              ],
            ),
          ),
        ],
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
