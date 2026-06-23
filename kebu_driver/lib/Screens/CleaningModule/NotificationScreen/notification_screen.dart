import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor("#C4C4C4"),
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

                          const SizedBox(width: 2,),

                          const Text("Notification", style: TextStyle(color: Colors.white, fontSize: 16),)
                        ],
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              )
          ),

          Container(
            margin: const EdgeInsets.only(top: 120),
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 7),

                // Title
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Text(
                    "Today",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),

                const SizedBox(height: 20),


                Divider(height: 1,color: HexColor("#000000").withOpacity(0.1),),

                // Grid of 4 cards
                Expanded(
                  child: Container(
                    color: HexColor("#C4C4C4").withOpacity(0.15),
                    child: ListView(
                      padding: const EdgeInsets.only(top: 5, left: 5),
                      children: [

                        // Support Chat
                        contactOptionCard(
                          icon: "assets/reminder.png",
                          title: "Reminder",
                          subtitle: "House Shifting - #2F33J scheduled Tomorrow.",
                          backgroundColor: const Color(0xFFE6F6ED),
                          iconColor: const Color(0xFF34A853),
                        ),

                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 10,left: 20, right: 20),
                          height: 1,
                          width: MediaQuery.of(context).size.width,
                          color: HexColor("#8F92A1").withOpacity(0.1),
                        ),

                        // Call Center
                        contactOptionCard(
                          icon: "assets/new_message.png",
                          title: "You have a new Message",
                          subtitle: '“Hey! I looked your problem and it’s fixed now. can you confirm?”',
                          backgroundColor: const Color(0xFFFFF1EC),
                          iconColor: const Color(0xFFFF5722),
                        ),

                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 10,left: 20, right: 20),
                          height: 1,
                          width: MediaQuery.of(context).size.width,
                          color: HexColor("#8F92A1").withOpacity(0.1),
                        ),

                        // Email
                        contactOptionCard(
                          icon: "assets/check_mark.png",
                          title: "Order Confirmed",
                          subtitle: "Your Vehicle - Mini Van Order is successfully placed.",
                          backgroundColor: const Color(0xFFF2EDFC),
                          iconColor: const Color(0xFF9C27B0),
                        ),

                        Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 10,left: 20, right: 20),
                          height: 1,
                          width: MediaQuery.of(context).size.width,
                          color: HexColor("#8F92A1").withOpacity(0.1),
                        ),

                        // FAQ
                        contactOptionCard(
                          icon: "assets/summer_offer.png",
                          title: "Summer Offer",
                          subtitle: "49% off on House Painting service until November 23rd.",
                          backgroundColor: const Color(0xFFFFF8E1),
                          iconColor: const Color(0xFFFFC107),
                        ),
                      ],
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget contactOptionCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [

          Container(
            height: 75,
            width: 75,
            padding: title == "You have a new Message" ? const EdgeInsets.all(0) : const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: title == "Summer Offer" ? HexColor("#F4E1E1") : title == "Order Confirmed" ? HexColor("#E1F4E5") : HexColor("#EEEEF7"),
              borderRadius: BorderRadius.circular(20)
            ),
            child: Image.asset(icon,height: 75,),
          ),

          const SizedBox(width: 14),

          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: MediaQuery.of(context).size.width - 120,
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.start,
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
