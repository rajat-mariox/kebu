import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/CommonWidgets/pick_salfie.dart';


class UpdateConfigScreen extends StatefulWidget {
  const UpdateConfigScreen({super.key});
  @override
  State<UpdateConfigScreen> createState() => _UpdateConfigScreenState();
}

class _UpdateConfigScreenState extends State<UpdateConfigScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          cleaningAppBar(
              height : 160,
              context : context,
              child: Container(
                padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                          const SizedBox(width: 6,),
                        ],
                      ),
                    ),

                    const Text("Update Booking", style: TextStyle(color: Colors.white, fontSize: 16),),

                    const Spacer(),
                  ],
                ),
              )
          ),

          Container(
            margin: const EdgeInsets.only(top: 120),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 7,),

                // Total amount section
                Container(
                  padding: const EdgeInsets.only(left: 10, right: 10, top: 17, bottom: 17),
                  decoration: BoxDecoration(
                    border: Border.all(color: HexColor("#000000").withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 10,),
                          const Text(
                            "Today 12:39 PM",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black,
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          const SizedBox(width: 7,),

                          Container(
                            padding: const EdgeInsets.only(left: 15, right: 15, top: 4, bottom: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: HexColor("#06A14E"), width: 1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              "Reached",
                              style: TextStyle(
                                fontSize: 10,
                                color: HexColor("#06A14E"),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(width: 10,),
                        ],
                      ),

                      const SizedBox(height: 4),

                      const Row(
                        children:  [
                          SizedBox(width: 10,),
                          Text(
                            "Your service number is #2699",
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.w500
                            ),
                          ),

                          Spacer(),

                          SizedBox(width: 10,),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                const Row(
                  children: [
                    SizedBox(width: 10,),
                    Text(
                      "Total Amount",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Spacer(),

                    Text(
                      "₹279",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(width: 10,),
                  ],
                ),

                const SizedBox(height: 17),

                const Row(
                  children: [
                    SizedBox(width: 10,),
                    Text(
                      "Extra Charges",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Spacer(),

                    SizedBox(width: 10,),
                  ],
                ),

                const SizedBox(height: 7,),

                Container(
                  padding: const EdgeInsets.only(left: 15, right: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: TextFormField(
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      border: InputBorder.none,           // Removes underline
                      enabledBorder: InputBorder.none,    // Removes when not focused
                      focusedBorder: InputBorder.none,    // Removes when focused
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                const Spacer(),

                Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.only(left: 5, right: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: HexColor("#2C54C1"),),
                              borderRadius: BorderRadius.circular(15)
                          ),
                          height: 50,
                          child: Center(
                            child: Text("Cancel", style: TextStyle(
                                color: HexColor("#2C54C1"),
                                fontSize: 14,
                                fontWeight: FontWeight.w500
                            ),),
                          ),
                        ),
                      ),

                      const SizedBox(width: 15,),

                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: HexColor("#2F4DBC")
                          ),
                          height: 50,
                          child: const Center(
                            child: Text("Update", style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500
                            ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )

              ],
            ),
          )
        ],
      ),
    );
  }
}
