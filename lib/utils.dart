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

showSnack(ScaffoldState state, String message,
    {Duration duration = defaultDuration}) {
  var snackbar = SnackBar(content: Text(message), duration: duration);

  state.showSnackBar(snackbar);
}
