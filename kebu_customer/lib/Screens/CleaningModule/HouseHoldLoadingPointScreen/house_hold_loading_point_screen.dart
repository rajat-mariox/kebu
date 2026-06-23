import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/CleaningModule/CleaningDetailsScreen/cleaning_order_details_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/Controller/household_booking_controller.dart';
import 'package:kebu_customer/Screens/Screens/SavedAddresses/add_address_screen.dart';
import 'package:kebu_customer/Services/user_api_service.dart';
import 'package:kebu_customer/Services/maps_api_service.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';


class HouseHoldLoadingPointScreen extends StatefulWidget {
  const HouseHoldLoadingPointScreen({super.key});

  @override
  State<HouseHoldLoadingPointScreen> createState() => _HouseHoldLoadingPointScreenState();
}

class _HouseHoldLoadingPointScreenState extends State<HouseHoldLoadingPointScreen> {

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

                      const Text("Loading Point", style: TextStyle(color: Colors.white, fontSize: 16),),

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
                            color: HexColor('#531E96'),
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
                          Image.asset("assets/star_with_location.png", height: 30,color: HexColor('#531E96'),),

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

                          ..._buildSavedAddressButtons(),

                          InkWell(
                            onTap: () async {
                              await pushTo(context, const AddAddressScreen());
                              _loadAddresses();
                            },
                            child: Column(
                              children: [
                                Container(
                                  height : 60,
                                  decoration: BoxDecoration(
                                      color: HexColor("#EFEFEF"),
                                      borderRadius: BorderRadius.circular(100)
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Image.asset('assets/location_add.png', height: 60,color: HexColor('#531E96'),),
                                ),

                                const SizedBox(height: 10,),

                                const Text("Add New", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500),)
                              ],
                            ),
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
                            backgroundColor: HexColor('#531E96'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final controller = Get.find<HouseholdBookingController>();
                            controller.setAddress(selectedAddress, selectedLat, selectedLng);
                            pushTo(context, const CleaningOrderDetailsScreen());
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

  List<Widget> _buildSavedAddressButtons() {
    final List<Widget> buttons = [];
    for (final addr in savedAddresses) {
      final type = (addr['addressType'] ?? '').toString();
      final label = type.isNotEmpty ? type : 'Saved';
      final icon = type.toLowerCase() == 'work' ? 'assets/work.png' : 'assets/home.png';
      buttons.add(
        InkWell(
          onTap: () {
            setState(() {
              selectedAddress = addr['address'] ?? '';
              selectedLat = (addr['latitude'] ?? 0).toDouble();
              selectedLng = (addr['longitude'] ?? 0).toDouble();
            });
          },
          child: Column(
            children: [
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: HexColor("#EFEFEF"),
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.all(14),
                child: Image.asset(icon, height: 60, color: HexColor('#531E96')),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
      buttons.add(const SizedBox(width: 30));
    }
    if (buttons.isEmpty) {
      // Show default Home/Work placeholders when no saved addresses
      buttons.addAll([
        Column(
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(color: HexColor("#EFEFEF"), borderRadius: BorderRadius.circular(100)),
              padding: const EdgeInsets.all(14),
              child: Image.asset('assets/home.png', height: 60, color: HexColor('#531E96')),
            ),
            const SizedBox(height: 10),
            const Text("Home", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(width: 30),
        Column(
          children: [
            Container(
              height: 60,
              decoration: BoxDecoration(color: HexColor("#EFEFEF"), borderRadius: BorderRadius.circular(100)),
              padding: const EdgeInsets.all(16),
              child: Image.asset('assets/work.png', height: 60, color: HexColor("#531E96")),
            ),
            const SizedBox(height: 10),
            const Text("Work", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(width: 30),
      ]);
    }
    return buttons;
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
