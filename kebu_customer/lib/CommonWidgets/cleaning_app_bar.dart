import 'package:flutter/cupertino.dart';
import 'package:hexcolor/hexcolor.dart';


Widget cleaningAppBar({required Widget child, required double height, required BuildContext context}){
  return Container(
    height: height,
    width: MediaQuery.of(context).size.width,
    decoration:  BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HexColor("#E61978"),
            HexColor("#461E98")
          ])
    ),
    child: Stack(
      children: [
        child,
      ],
    ),
  );
}