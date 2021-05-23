import 'package:flutter/material.dart';

const defaultDuration = Duration(seconds: 2);
showUndoSnackbar(ScaffoldState state, String dataString, dynamic data,
    ValueChanged<dynamic> onUndo) {
  var snackbar = SnackBar(
      content: Text("Deleted $dataString sucessfully"),
      duration: Duration(seconds: 3),
      action: SnackBarAction(label: "Undo", onPressed: () => onUndo(data)));

  state.showSnackBar(snackbar);
}

showSnack(var state, String message, {Duration duration = defaultDuration}) {
  var snackbar = SnackBar(content: Text(message), duration: duration);

  state.showSnackBar(snackbar);
}

Color getSelectedCardColor(BuildContext context) {
  return Theme.of(context).textTheme.bodyText1.color.withOpacity(0.4);
}

BoxDecoration getSelectedDecoration(BuildContext context) {
  return BoxDecoration(color: getSelectedCardColor(context));
}
