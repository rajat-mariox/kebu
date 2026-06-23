
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class AppColors {
  static Color pinkColor = HexColor("#E61978");
  static Color purpleColor = HexColor("#461E98");

  // Kept for backwards compatibility with existing call sites.
  // Now points at the brand pink so legacy "greenColor" usages
  // automatically pick up the new palette.
  static Color greenColor = HexColor("#E61978");

  static LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pinkColor, purpleColor],
  );
}
