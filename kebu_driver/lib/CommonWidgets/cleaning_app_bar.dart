import 'package:flutter/cupertino.dart';
import 'package:hexcolor/hexcolor.dart';


Widget cleaningAppBar({required Widget child, required double height, required BuildContext context}){
  return Container(
    height: height,
    width: MediaQuery.of(context).size.width,
    decoration:  BoxDecoration(
      color: HexColor("#2F4DBC"),
    ),
    child: Stack(
      children: [
        child,
      ],
    ),
  );
}