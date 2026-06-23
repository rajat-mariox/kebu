import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/button_widget.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';


class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {

  var textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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

                          const SizedBox(width: 10,),
                        ],
                      ),
                    ),

                    const Spacer(),

                    const Text("Review", style: TextStyle(color: Colors.white, fontSize: 16),),

                    const Spacer(),

                    Container(
                      child: Image.asset("assets/notification.png", height: 28,),
                    ),
                  ],
                ),
              )
          ),

          Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.only(top: 120),
          //  padding: EdgeInsets.all(16),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40,),

                const Text(
                  "How was your Experience?",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  margin: const EdgeInsets.only(left: 30, right: 30),
                  child: Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      text: 'Your order is Successfully Done, Do you mind giving a small feedback about your experience?',
                      style: GoogleFonts.poppins(
                        color: HexColor("#000000").withOpacity(0.5),
                        fontSize: 10,
                      ),
                      children: [
                        TextSpan(
                          text: '',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFE53935),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                Container(
                  margin: const EdgeInsets.only(left: 40, right: 40),
                    child: Image.asset("assets/rate.png")
                ),

                const SizedBox(height: 25),

                Container(
                  height: 1,
                  width: MediaQuery.of(context).size.width,
                  color: Colors.grey.withOpacity(0.3),
                ),

                const SizedBox(height: 25),

                Container(
                  margin: const EdgeInsets.only(left: 20),
                  alignment: Alignment.topLeft,
                  width: MediaQuery.of(context).size.width,
                  child: Text(
                    "YOUR DRIVER",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.grey.withOpacity(0.4)
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.only(top: 7, bottom: 7, left: 14, right: 14),
                  margin: const EdgeInsets.only(top: 20),
                  width: MediaQuery.of(context).size.width - 40,
                  height: 160,
                  decoration: BoxDecoration(
                    color: HexColor("#E8E8E8").withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: TextFormField(
                    controller: textController,
                    style: const TextStyle(color: Colors.black, fontSize: 13),
                    decoration: const InputDecoration(
                        hintText: "Type here...",
                        hintStyle:  TextStyle(color: Colors.grey, fontSize: 13),
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        suffixIconConstraints: BoxConstraints(
                            maxWidth: 30
                        ),
                    ),
                  ),
                ),

                Expanded(child: Container(height: 0,)),

                Row(
                  children: [

                    const SizedBox(width: 17,),

                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Colors.black12),
                          ),
                          onPressed: () {
                            // Add your navigation logic here
                          },
                          child: const Text(
                            "Skip",
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 15,),

                    Expanded(
                      child: ButtonWidget(
                        text: "Submit",
                        backgroundColor: HexColor("#DE1A21"),
                        borderRadius: BorderRadius.circular(15),
                        linearGradient: LinearGradient(
                            colors: [
                              HexColor("#DE1A21"),HexColor("#DE1A21")
                            ]
                        ),
                      ),
                    ),

                    const SizedBox(width: 17,),
                  ],
                ),

                const SizedBox(height: 25,)
              ],
            ),
          ),
        ],
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
