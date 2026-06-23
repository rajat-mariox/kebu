import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';


Widget pickSelfie(BuildContext context){

  return SizedBox(
    height: 58,
    width: MediaQuery.of(context).size.width,
    child: Stack(
      children: [
        SizedBox(
          height: 58,
          child: Image.asset("assets/dotted_line_1.png",
            width: MediaQuery.of(context).size.width,
            fit: BoxFit.fill,
          ),
        ),

        Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: HexColor("#CCCCCC")
              ),
              padding: const EdgeInsets.all(7),
              margin: const EdgeInsets.all(6),
              child: Image.asset("assets/business_man_icon.png"),

            ),

            const SizedBox(width: 2,),

            Container(
              width: MediaQuery.of(context).size.width - 111,
              height: 47,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HexColor("#000000").withOpacity(0.2)
                  )
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  Icon(Icons.camera_alt_outlined, size: 25,),

                  SizedBox(width: 5,),

                  Text("Capture your selfie", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 13),)

                ],
              ),
            )
          ],
        )
      ],
    ),
  );
}