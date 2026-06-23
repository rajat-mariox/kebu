import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

Widget walletWidget(BuildContext context){
     return Container(
       padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
       decoration: BoxDecoration(
         color: HexColor("#A2BF49"),
         borderRadius: BorderRadius.circular(12),
       ),
       child: const Row(
         children:  [
           Icon(Icons.wallet, color: Colors.white),
           SizedBox(width: 6),
           Text(
             "500",
             style: TextStyle(
               fontSize: 13,
               color: Colors.white,
               fontWeight: FontWeight.bold,
             ),
           )
         ],
       ),
     );
   }