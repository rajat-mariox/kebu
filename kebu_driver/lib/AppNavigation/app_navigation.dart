import 'package:flutter/cupertino.dart';

pushTo(BuildContext context, Widget name) async {
  return await Navigator.push(
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