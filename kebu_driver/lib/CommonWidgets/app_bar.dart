import 'package:flutter/cupertino.dart';
import 'package:hexcolor/hexcolor.dart';



Widget commonAppBar({required Widget child, required double height, required BuildContext context}){
     return Container(
       height: height,
       width: MediaQuery.of(context).size.width,
       decoration:  BoxDecoration(
         color: HexColor("#FFD546"),
         gradient: LinearGradient(
           begin: Alignment.topCenter,
             end: Alignment.bottomCenter,
             colors: [
                 HexColor("#FFD546"),
                 HexColor("#FFD546")
         ])
       ),
       child: Stack(
         children: [
           child,
         ],
       ),
     );
  }