import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_customer/Screens/CleaningModule/ServiceDetailsScreen/service_details_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/SelectTimingScreen/select_timing_screen.dart';

class CleaningInstructionScreen extends StatefulWidget {
  const CleaningInstructionScreen({super.key});
  @override
  State<CleaningInstructionScreen> createState() => _CleaningInstructionScreenState();
}

class _CleaningInstructionScreenState extends State<CleaningInstructionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: SingleChildScrollView(
          child: Stack(
            children: [
              cleaningAppBar(
                  height : 160,
                  context : context,
                  child: Container(
                    padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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

                              const SizedBox(width: 10,),
                            ],
                          ),
                        ),


                        const Text("Home | Noida 62", style: TextStyle(color: Colors.white, fontSize: 16),),

                        const Spacer(),

                        Container(
                            padding: const EdgeInsets.only(left: 15, right: 15, top: 5,bottom: 5),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1)
                            ),
                            child: const Text("Change", style: TextStyle(color: Colors.white),)
                        ),
                      ],
                    ),
                  )
              ),


              Container(
                margin: const EdgeInsets.only(top: 120),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30,),
                    SizedBox(
                      height: 45,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          const SizedBox(width: 10,),
                          _tabButton("Everyday Cleaning", true),
                          const SizedBox(width: 8),
                          _tabButton("Weekly Cleaning", false),
                          const SizedBox(width: 8),
                          _tabButton("Laundry", false),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _sectionCard(
                      title: "The Expert Is Trained To",
                      items: const [
                        "Sweep & Mop Accessible Areas",
                        "Dry Dust/Wet Wipe Furniture. Fixtures. Wardrobes",
                        "Dry Dust Walls, Fans, Ceilings, Window Grills Curtains. Etc",
                        "Change Or Rearrange The Bedding",
                        "Dispose Of Wet & Dry Waste",
                      ],
                      icon: Icons.check_circle,
                      iconColor: Colors.green,
                    ),

                    const SizedBox(height: 20),

                    _sectionCard(
                      title: "Service Excludes",
                      items: const [
                        "Sweeping & Mopping Inaccessible Areas",
                        "Moving Heavy Furniture",
                        "Cleaning Outside Windows Or Areas",
                        "Needing A Ladder",
                        "Washing Bed Sheets. Pillow Covers, Blankets. Etc",
                      ],
                      icon: Icons.cancel,
                      iconColor: Colors.red,
                    ),

                    const SizedBox(height: 20),

                    _itemsNeededSection(),

                    const SizedBox(height: 30),

                    Row(
                      children: [
                        const SizedBox(width: 20,),

                        Expanded(
                          child: InkWell(
                            onTap: (){
                              pushTo(context, const ServiceDetailsScreen());
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: HexColor("#4A1E97")),
                              ),
                              child: Center(
                                child: Text(
                                  "Book Now",
                                  style: TextStyle(fontSize: 16, color: HexColor("#4A1E97"), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: (){
                              pushTo(context, const SelectTimingScreen());
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFB71CFF), Color(0xFFEE2A7B)],
                                ),
                              ),
                              child:const Center(
                                child: Text(
                                  "Pre Book",
                                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20,),
                      ],
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String text, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE91E63) : const Color(0xFFFFE8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  

  Widget _sectionCard({required String title, required List<String> items, required IconData icon, required Color iconColor}) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: title == "Service Excludes" ? HexColor("#D8197B").withOpacity(0.07) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HexColor("#DFDFDF"))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (var item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w400)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _itemsNeededSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(left: 20, right: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HexColor("#DFDFDF"))
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What We Need From You",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NeededItem(label: "Mop & Bucket", icon: "assets/mob_and_bucket.png"),
              _NeededItem(label: "Surface Cleaner", icon: "assets/surface_cleaner.png"),
              _NeededItem(label: "Dusting Cloth", icon: "assets/dusting_cleaner.png"),
              _NeededItem(label: "Cleaner", icon: "assets/surface_cleaner.png"),
            ],
          )
        ],
      ),
    );
  }
}

class _NeededItem extends StatelessWidget {
  final String label;
  final String icon;
  const _NeededItem({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(icon, height: 50,),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
      ],
    );
  }
}
