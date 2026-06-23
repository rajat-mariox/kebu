import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/CleaningModule/HouseHoldLoadingPointScreen/house_hold_loading_point_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/Controller/household_booking_controller.dart';
import 'package:kebu_customer/Services/household_api_service.dart';
import 'package:table_calendar/table_calendar.dart';


class SelectTimingScreen extends StatefulWidget {
  const SelectTimingScreen({super.key});
  @override
  State<SelectTimingScreen> createState() => _SelectTimingScreenState();
}

class _SelectTimingScreenState extends State<SelectTimingScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final String _selectedTimeSlot = '07:00 AM';
  List<dynamic> timeSlots = [];

  @override
  void initState() {
    super.initState();
    _loadTimeSlots();
  }

  Future<void> _loadTimeSlots() async {
    final response = await HouseholdApiService.getAvailableTimeSlots(
      'default',
      date: DateTime.now().toIso8601String(),
    );
    if (response.success && response.data != null && mounted) {
      setState(() {
        timeSlots = response.data['timeSlots'] ?? [];
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

                      const Text("Household service", style: TextStyle(color: Colors.white, fontSize: 16),),

                      const Spacer(),

                      const NotificationIconButton(),
                    ],
                  ),
                )
            ),

            Container(
              margin: const EdgeInsets.only(top: 120),
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10,),

                  // Calendar Header
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [

                        Text(
                          '${_focusedDay.monthName}, ${_focusedDay.year}',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),

                        const Spacer(),


                        const Icon(Icons.arrow_back, color: Colors.black, size: 22),

                        const SizedBox(width: 20,),

                        const Icon(Icons.arrow_forward, color: Colors.black, size: 22),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Calendar
                  Container(
                    margin: const EdgeInsets.only(left: 25, right: 25),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      headerVisible: false,
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: HexColor("#531E96"),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color:HexColor("#531E96"),
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle: GoogleFonts.poppins(fontSize: 11),
                        weekendTextStyle: GoogleFonts.poppins(color: Colors.black, fontSize: 11),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500, color: Colors.grey.shade600, fontSize: 11),
                        weekendStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500, color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    child: Text(
                      'Pick time',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                          fontSize: 12
                      ),
                    ),
                  ),

                  const SizedBox(height: 10,),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 7,),
                      Expanded(child: Container(
                          decoration: BoxDecoration(
                              color: HexColor('#531E96'),
                              borderRadius: BorderRadius.circular(100)
                          ),
                          child: _timeChip('Afternoon', Colors.white)
                       )
                      ),
                      const SizedBox(width: 10,),
                      Expanded(child: _timeChip('Late Morning', Colors.black)),
                      const SizedBox(width: 10,),
                    ],
                  ),


                  const SizedBox(height: 12),

                  // Time Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 7,),
                      _timeChip('07:00 AM', Colors.black),
                      const SizedBox(width: 10,),
                      _timeChip('11:00 AM', Colors.black),
                      const SizedBox(width: 10,),
                      _timeChip('12:00 PM', Colors.black),
                    ],
                  ),


                  const SizedBox(height: 60,),



                  // Proceed Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HexColor('#531E96'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final controller = Get.find<HouseholdBookingController>();
                        if (_selectedDay != null) {
                          controller.setDate(_selectedDay!);
                        }
                        controller.setTimeSlot(_selectedTimeSlot);
                        pushTo(context, const HouseHoldLoadingPointScreen());
                      },
                      child: Text(
                        'Proceed',
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
            ),
          ],
        ),
      ),
    );
  }


  Widget _timeChip(String time, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 13),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: HexColor("#E6E8EC"))
      ),
      alignment: Alignment.center,
      child: Text(
        time,
        style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 12
        ),
      ),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.black, size: 18),
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

  Widget offerCard({
    required Color backgroundColor,
    required String title,
    required String subtitle,
    required String code,
    required Color textColor,
    String? image,
  }) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(subtitle, style: TextStyle(color: textColor)),
                const SizedBox(height: 8),
                Text("Code : $code", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (image != null)
            Expanded(
              flex: 1,
              child: Image.asset(image, fit: BoxFit.contain),
            ),
        ],
      ),
    );
  }


  Widget _locationTile({
    required String title,
    required Widget icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black),
        ],
      ),
    );
  }
}

extension MonthName on DateTime {
  String get monthName {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}