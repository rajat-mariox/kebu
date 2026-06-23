import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';


class CleaningButtonWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final String text;
  final double? height;
  final double? width;
  final BorderRadius? borderRadius;
  final HexColor? backgroundColor;
  final HexColor? textColor;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final TextStyle? textStyle;
  final LinearGradient? linearGradient;
  final bool? isEnabled;
  final bool? showBorder;
  final Border? border;


  const CleaningButtonWidget({
    super.key,
    this.onTap,
    required this.text,
    this.height,
    this.width,
    this.borderRadius,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.margin,
    this.textStyle,
    this.linearGradient,
    this.isEnabled,
    this.showBorder,
    this.border});


  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: padding ?? const EdgeInsets.all(0),
        width:  width ?? MediaQuery.of(context).size.width,
        margin: margin ?? const EdgeInsets.all(0),
        height: height ?? 50,
        decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: border,
            gradient: LinearGradient(
              colors: [
                HexColor("#E61978"),
                HexColor("#E61978"),
                HexColor("#461E98"),
                HexColor("#461E98"),
              ],
              transform: const GradientRotation(1.53)
            )
        ),
        child: Center(
          child: Text(
            text,
            style: textStyle ??
                TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
