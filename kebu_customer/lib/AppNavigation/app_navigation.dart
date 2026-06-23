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

/// Like [replaceRoute] but keeps the root (first) route — the Dashboard — at
/// the bottom of the stack instead of clearing everything. Use this for the
/// in-ride flow transitions (finding → live tracking → summary) so that back
/// navigation during an active ride returns to the Dashboard rather than
/// popping an empty stack and showing a black screen.
void replaceRouteKeepingRoot(BuildContext context, Widget name) {
  Navigator.pushAndRemoveUntil(
    context,
    CupertinoPageRoute(builder: (context) => name),
        (Route<dynamic> route) => route.isFirst,
  );
}