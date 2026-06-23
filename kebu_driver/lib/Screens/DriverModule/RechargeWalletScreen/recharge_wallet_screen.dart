import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:flutter/material.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  final TextEditingController _controller = TextEditingController(text: '500');
  final List<int> amounts = [250, 500, 750, 100];
  int selectedAmount = 500;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
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
                      "Recharge Wallet",
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

          // Top balance section
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: const Column(
              children: [
                Text(
                  'Available Balance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '₹2,430.00',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Middle input section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),

                  const SizedBox(width: 5,),

                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        final value = int.tryParse(val) ?? 0;
                        setState(() => selectedAmount = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: amounts.map((amt) {
                final isSelected = selectedAmount == amt;
                return GestureDetector(
                  onTap: () {
                    _controller.text = amt.toString();
                    setState(() => selectedAmount = amt);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 7),
                    padding: const EdgeInsets.only(left: 18, right: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2F6BED) : const Color(0xFFE5EAF0),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '₹$amt',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFF2F6BED) : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 17),

          // Recharge Now Button
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Recharge logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB6CC6B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Recharge Now',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
