import 'package:flutter/cupertino.dart';

pushTo(BuildContext context, Widget name) async {
  return await Navigator.push(
    context,
    CupertinoPageRoute(builder: (context) => name),
  );
}

/// Replaces the current screen with [name]. Use when advancing to the next step
/// of a linear, irreversible flow (e.g. the household booking: en-route →
/// arrived → in-progress) so pressing Back does NOT return to an already
/// completed step. The partner can still resume the job from the dashboard's
/// "On Going" list, which reopens it at the correct step.
Future<T?> pushReplace<T>(BuildContext context, Widget name) {
  return Navigator.pushReplacement(
    context,
    CupertinoPageRoute(builder: (context) => name),
  );
}

void replaceRoute(BuildContext context, Widget name){
  Navigator.pushAndRemoveUntil(
    context,
    CupertinoPageRoute(builder: (context) => name),
        (Route<dynamic> route) => false,
  );
}

/// Pops the current route, or — if there is nothing to pop (e.g. the screen
/// was opened directly from a push notification, so it is the only route on
/// the stack) — replaces the stack with [fallback]. Prevents back navigation
/// from landing on an empty (black) screen.
void safeBack(BuildContext context, Widget fallback) {
  if (Navigator.of(context).canPop()) {
    Navigator.pop(context);
  } else {
    replaceRoute(context, fallback);
  }
}