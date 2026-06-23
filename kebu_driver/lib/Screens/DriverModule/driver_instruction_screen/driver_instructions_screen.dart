import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/button_widget.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Utils/AppColors/app_colors.dart';

class DriverInstructionsScreen extends StatefulWidget {
  const DriverInstructionsScreen({super.key});

  @override
  State<DriverInstructionsScreen> createState() => _DriverInstructionsScreenState();
}

class _DriverInstructionsScreenState extends State<DriverInstructionsScreen> {
  bool agreed = false;

  final List<_InstructionItem> items = const [
    _InstructionItem(
      icon: Icons.access_time,
      title: 'Be on time for every pickup',
    ),
    _InstructionItem(
      icon: Icons.directions_car,
      title: 'Keep your vehicle clean and ready',
    ),
    _InstructionItem(
      icon: Icons.inbox,
      title: 'Handle parcels carefully',
    ),
    _InstructionItem(
      icon: Icons.credit_card,
      title: 'Encourage cashless payments',
    ),
    _InstructionItem(
      icon: Icons.call,
      title: 'Call customer only when necessary',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          commonAppBar(
              height : 100,
              context : context,
              child: Container(
                padding: const EdgeInsets.only(top: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: ()
                      {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.only(left: 16),
                        width: 40,
                        height: 35,
                        alignment: Alignment.center,
                        child: Image.asset("assets/back_arrow.png", color: Colors.black,),
                      ),
                    ),

                    const SizedBox(width: 8,),

                    const Text(
                      "Driver Instructions",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                  ],
                ),
              )
          ),

          // Top spacing
          const SizedBox(height: 18),

          // Intro text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Please read the instructions carefully before starting your rides or deliveries.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Cards list in an Expanded scroll area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var item in items) ...[
                    InstructionCard(item: item),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 6),

                  // checkbox line
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(width: 6),
                      Checkbox(
                        value: agreed,
                        onChanged: (v) => setState(() => agreed = v ?? false),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        activeColor: const Color(0xFF2F6BED),
                      ),
                      Text(
                        'I have read and understood all instructions',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // Bottom green Agree button (full width with safe margin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
            child: ButtonWidget(text: 'Agree',
              textColor: AppColors.blackColor,
              onTap: ()
            {
              Navigator.pop(context);
            },
            ),
          ),

          const SizedBox(height: 20,)
        ],
      ),
    );
  }
}

class InstructionCard extends StatelessWidget {
  final _InstructionItem item;
  const InstructionCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    const cardColor = Colors.white;
    const iconBg = Color(0xFFEAF1FF);
    const iconColor = Color(0xFF2F6BED);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HexColor("#E1E6EF")),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        children: [
          // icon circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(item.icon, color: iconColor, size: 45),
            ),
          ),

          const SizedBox(width: 14),

          // text
          Expanded(
            child: Text(
              item.title,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionItem {
  final IconData icon;
  final String title;
  const _InstructionItem({required this.icon, required this.title});
}