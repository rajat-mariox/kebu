import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/Screens/CleaningModule/ProfileScreen/profile_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/incoming_service_bottom_sheet.dart';
import 'package:kebu_driver/Services/socket_service.dart';



class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  StreamSubscription<Map<String, dynamic>>? _newBookingSub;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();

    _newBookingSub = SocketService().onNewServiceBooking.listen((data) {
      if (!mounted || _sheetOpen) return;
      final booking = (data['booking'] is Map)
          ? Map<String, dynamic>.from(data['booking'])
          : Map<String, dynamic>.from(data);
      if (booking.isEmpty) return;

      _sheetOpen = true;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (_) => IncomingServiceBottomSheet(booking: booking),
      ).whenComplete(() => _sheetOpen = false);
    });
  }

  @override
  void dispose() {
    _newBookingSub?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [

            cleaningAppBar(
                height : 160,
                context : context,
                child: Container(
                  padding: const EdgeInsets.only( left: 12, right: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: ()
                        {
                          pushTo(context, const ProfileScreen());
                        },
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: Image.asset("assets/person_icon.png", height: 26,width: 26,),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Offline",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),

                      const Spacer(),

                      Container(width: 55,)
                    ],
                  ),
                )
            ),

            Container(
              margin: const EdgeInsets.only(top: 120),
              padding: const EdgeInsets.only(left: 20, right: 20),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(topRight: Radius.circular(32), topLeft: Radius.circular(32)),
                color: Colors.white
              ),
              child: Column(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Stats Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatCard("₹1259", "Total Earning", "assets/discount_icon.png"),
                          _buildStatCard("1589", "Total Service", "assets/documents_icon.png"),
                          _buildStatCard("15", "Upcoming\nServices", "assets/documents_icon.png"),
                          _buildStatCard("05", "Today's\nService", "assets/documents_icon.png"),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 25,),

                  // Monthly Revenue Chart
                   Container(
                     width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Align(
                      alignment: Alignment.center,
                      child: Text(
                        "Monthly Revenue Rupee",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        maxY: 15000,
                        minY: 0,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false,),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 55,
                              interval: 5000,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles:
                          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles:
                          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const months = [
                                  'Jan',
                                  'Feb',
                                  'Mar',
                                  'Apr',
                                  'May',
                                  'Jun',
                                  'Jul',
                                  'Aug'
                                ];
                                if (value.toInt() < months.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      months[value.toInt()],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          makeGroupData(0, 5000),
                          makeGroupData(1, 10000),
                          makeGroupData(2, 0),
                          makeGroupData(3, 0),
                          makeGroupData(4, 0),
                          makeGroupData(5, 0),
                          makeGroupData(6, 0),
                          makeGroupData(7, 0),
                        ],
                        alignment: BarChartAlignment.spaceAround,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Container(
                      child: Row(
                        children: [
                          _buildTabButton("On Going", true),
                          const SizedBox(width: 12,),
                          _buildTabButton("Pending", false),
                          const SizedBox(width: 12,),
                          _buildTabButton("Completed", false),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Service Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
            )
          ],
        ),
      ),
    );
  }


  BarChartGroupData makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 18,
          borderRadius: BorderRadius.circular(4),
          color: const Color(0xFF2F5AE3),
        ),
      ],
    );
  }

  // ---- Helper Widgets ----
  static Widget _buildStatCard(String value, String label, String icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HexColor("#EBEBEB")),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: HexColor("#2F4DBC"))),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),

          const SizedBox(width: 10,),

          Expanded(child: Container(width: 0,)),

          Container(
            height: 36,
            width: 36,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: HexColor("#2F4DBC").withOpacity(0.06)
            ),
              child: Image.asset(icon, height: 24,width: 24,)),
        ],
      ),
    );
  }

  static BarChartGroupData _barGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 20,
          borderRadius: BorderRadius.circular(4),
          color: Colors.blueAccent,
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
}
