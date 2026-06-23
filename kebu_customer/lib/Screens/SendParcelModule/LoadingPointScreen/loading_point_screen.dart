import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/parcel_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';
import 'package:kebu_customer/Services/maps_api_service.dart';
import 'package:kebu_customer/Services/user_api_service.dart';
import 'package:geolocator/geolocator.dart';

class LoadingPointScreen extends StatefulWidget {
  // Title shown in the header ("Loading Point" or "Unloading Point").
  // On Confirm the screen pops with {lat, lng, address} of the chosen point.
  final String title;
  const LoadingPointScreen({super.key, this.title = 'Loading Point'});

  @override
  State<LoadingPointScreen> createState() => _LoadingPointScreenState();
}

class _LoadingPointScreenState extends State<LoadingPointScreen> {

  String selectedAddress = 'Detecting location...';
  double selectedLat = 0;
  double selectedLng = 0;
  List<dynamic> savedAddresses = [];

  @override
  void initState() {
    super.initState();
    _detectCurrentLocation();
    _loadAddresses();
  }

  Future<void> _detectCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }
      if (permission == LocationPermission.denied) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final res = await MapsApiService.reverseGeocode(
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (res.success && res.data != null && mounted) {
        setState(() {
          selectedLat = pos.latitude;
          selectedLng = pos.longitude;
          selectedAddress = res.data['address'] ?? res.data['display_name'] ?? '${pos.latitude}, ${pos.longitude}';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAddresses() async {
    final response = await UserApiService.getAddresses();
    if (response.success && response.data != null && mounted) {
      setState(() {
        savedAddresses = response.data['addresses'] ?? [];
        if (savedAddresses.isNotEmpty) {
          selectedAddress = savedAddresses.first['address'] ?? selectedAddress;
        }
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    final response = await MapsApiService.reverseGeocode(lat: lat, lng: lng);
    if (response.success && response.data != null && mounted) {
      setState(() {
        selectedAddress = response.data['address'] ?? selectedAddress;
      });
    }
  }
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

                      Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16),),

                      const Spacer(),

                      const NotificationIconButton(),
                    ],
                  ),
                )
            ),

            Container(
              margin: const EdgeInsets.only(top: 120),
              height: 300,
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                child: Stack(
                  children: [
                    selectedLat != 0
                        ? GoogleMapWidget(
                            pickupLat: selectedLat,
                            pickupLng: selectedLng,
                            centerLat: selectedLat,
                            centerLng: selectedLng,
                            zoom: 15,
                          )
                        : Image.asset("assets/map_view.png"),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: GestureDetector(
                        onTap: _detectCurrentLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: HexColor("#FF3B59"),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text("My Location", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 320,
                  margin: const EdgeInsets.only(top: 120),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
                  ),
                  child: Column(
                    children: [

                      const SizedBox(height: 30,),

                      Row(
                        children: [

                          const SizedBox(width: 30,),
                          Image.asset("assets/star_with_location.png", height: 30,),

                          const SizedBox(width: 15,),

                          Expanded(child: Text(selectedAddress, style: const TextStyle(color: Colors.black, fontSize: 13), overflow: TextOverflow.ellipsis,)),

                          const Spacer(),

                          const Icon(Icons.close, size: 19,),

                          const SizedBox(width: 30,),
                        ],
                      ),

                      const SizedBox(height: 20,),

                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 30, right: 30),
                        width: MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        color: Colors.grey.withOpacity(0.3),
                      ),

                      const SizedBox(height: 30,),

                      Row(
                        children: [

                          const Spacer(),

                          Column(
                            children: [
                              Container(
                                height : 60,
                                decoration: BoxDecoration(
                                  color: HexColor("#EFEFEF"),
                                  borderRadius: BorderRadius.circular(100)
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Image.asset('assets/home.png', height: 60,),
                              ),

                              const SizedBox(height: 10,),

                              const Text("Home", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500),)
                            ],
                          ),

                          const SizedBox(width: 30,),

                          Column(
                            children: [
                              Container(
                                height : 60,
                                decoration: BoxDecoration(
                                    color: HexColor("#EFEFEF"),
                                    borderRadius: BorderRadius.circular(100)
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Image.asset('assets/work.png', height: 60,),
                              ),

                              const SizedBox(height: 10,),

                              const Text("Work", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500),)
                            ],
                          ),


                          const SizedBox(width: 30,),

                          Column(
                            children: [
                              Container(
                                height : 60,
                                decoration: BoxDecoration(
                                    color: HexColor("#EFEFEF"),
                                    borderRadius: BorderRadius.circular(100)
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Image.asset('assets/location_add.png', height: 60,),
                              ),

                              const SizedBox(height: 10,),

                              const Text("Add New", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500),)
                            ],
                          ),

                          const Spacer()
                        ],
                      ),

                      const SizedBox(height: 20,),

                      // Proceed Button
                      Container(
                        width: double.infinity,
                        height: 55,
                        margin: const EdgeInsets.only(left: 30, right: 30),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context, {
                              'lat': selectedLat,
                              'lng': selectedLng,
                              'address': selectedAddress,
                            });
                          },
                          child: Text(
                            'Confirm',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                    ],
                  ),
                )
            )
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
