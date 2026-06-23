import 'package:flutter/cupertino.dart';
import 'package:hexcolor/hexcolor.dart';


Widget sendParcelAppBar({required Widget child, required double height, required BuildContext context}){
  return Container(
    height: height,
    width: MediaQuery.of(context).size.width,
    decoration:  BoxDecoration(
        color: HexColor("#DE1A21"),
        // gradient: LinearGradient(
        //     begin: Alignment.topCenter,
        //     end: Alignment.bottomCenter,
        //     colors: [
        //       HexColor("#DE1A21"),
        //       HexColor("#DE1A21")
        //     ])
    ),
    child: Stack(
      children: [
        child,
      ],
    ),
  );
}