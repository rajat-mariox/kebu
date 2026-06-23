import 'package:flutter/material.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/Screens/NotificationScreen/notification_screen.dart';

class NotificationIconButton extends StatelessWidget {
  const NotificationIconButton({
    super.key,
    this.height = 28,
    this.margin,
  });

  final double height;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => pushTo(context, const NotificationScreen()),
      child: Container(
        margin: margin,
        child: Image.asset("assets/notification.png", height: height),
      ),
    );
  }
}
