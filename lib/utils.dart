import 'package:flutter/material.dart';

const defaultDuration = Duration(seconds: 2);

ScaffoldMessengerState? _messengerFor(dynamic state) {
  if (state == null) return null;
  if (state is ScaffoldMessengerState) return state;
  if (state is ScaffoldState) return ScaffoldMessenger.of(state.context);
  if (state is BuildContext) return ScaffoldMessenger.of(state);
  return null;
}

void showUndoSnackbar(dynamic state, String dataString, dynamic data,
    ValueChanged<dynamic> onUndo) {
  final snackbar = SnackBar(
      content: Text("Deleted $dataString sucessfully"),
      duration: Duration(seconds: 3),
      action: SnackBarAction(label: "Undo", onPressed: () => onUndo(data)));

  _messengerFor(state)?.showSnackBar(snackbar);
}

void showSnack(dynamic state, String message,
    {Duration duration = defaultDuration}) {
  final snackbar = SnackBar(content: Text(message), duration: duration);

  _messengerFor(state)?.showSnackBar(snackbar);
}

Color getSelectedCardColor(BuildContext context) {
  return (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black)
      .withValues(alpha: 0.4);
}

BoxDecoration getSelectedDecoration(BuildContext context) {
  return BoxDecoration(color: getSelectedCardColor(context));
}

String resolveRichContent(String data) {
  List<String> lines = data.split("\n");

  List<String> resolved = [];
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if (line.contains('[') && line.contains(']')) {
      String chords = "";
      String text = "";
      int mode = 0;
      int skip = 0;

      for (int j = 0; j < line.length; j++) {
        String rest = line.substring(j + 1);
        var char = line[j];
        if (char == '[' && rest.contains("]") && mode == 0) {
          mode = 1;
        } else if (char == "]" && mode == 1) {
          mode = 0;
        } else if (mode == 1) {
          chords += char;
          skip += 1;
        } else {
          // skip the first
          if (skip == 0)
            chords += " ";
          else
            skip -= 1;
          text += char;
        }
      }
      print("${chords.length} vs ${text.length}");
      resolved.add(chords);
      resolved.add(text);
    } else {
      resolved.add(line);
    }
  }
  return resolved.join("\n");
}
