import 'package:flutter/material.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';

class PaymentRecievedScreen extends StatefulWidget {
  const PaymentRecievedScreen({super.key});

  @override
  State<PaymentRecievedScreen> createState() => _PaymentRecievedScreenState();
}

class _PaymentRecievedScreenState extends State<PaymentRecievedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          cleaningAppBar(
              height: 160,
              context: context,
              child: Container(
                padding: const EdgeInsets.only(top: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.only(left: 16),
                        width: 40,
                        height: 35,
                        alignment: Alignment.center,
                        child: Image.asset(
                          "assets/back_arrow.png",
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    const Text(
                      "Summary",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              )
          ),

          Container(
            margin: const EdgeInsets.only(top: 110),
            decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32)
                )
            ),
            child: const Column(
              children: [

              ],
            ),
          ),
        ],
      ),
    );
  }
}
