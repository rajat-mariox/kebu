import 'package:kebu_customer/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class SliderButtonWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final String text;
  final double? height;
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


  const SliderButtonWidget({
    super.key,
    this.onTap,
    required this.text,
    this.height,
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

    const Color cardBorder = Color(0xFFE6EEF2);

    return InkWell(
      onTap: onTap ?? () {},
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: padding ?? const EdgeInsets.all(0),
        width: MediaQuery.of(context).size.width,
        margin: margin ?? const EdgeInsets.all(0),
        height: height ?? 50,
        decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.greenColor,
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: border
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: cardBorder),
              ),
              child: Center(
                child: Icon(Icons.keyboard_double_arrow_right, color: AppColors.greenColor, size: 30,),
              ),
            ),

            const Spacer(),

            Text(
              text,
              style: textStyle ??
                  TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
            ),

            const Spacer(),

            const SizedBox(width: 58,)
          ],
        ),
      ),
    );
  }
}
