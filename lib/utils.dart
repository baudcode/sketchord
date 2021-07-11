import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

String getFormattedDate(DateTime date) {
  String _date = DateTime.now().toString();
  return date.toString().substring(0, _date.length - 7).replaceAll(":", "-");
}

List<String> itemsByFrequency(List<String> input) => [
      ...(input
              .fold<Map<String, int>>(
                  <String, int>{},
                  (map, letter) => map
                    ..update(letter, (value) => value + 1, ifAbsent: () => 1))
              .entries
              .toList()
                ..sort((e1, e2) => e2.value.compareTo(e1.value)))
          .map((e) => e.key)
    ];

class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback resumeCallBack;
  final AsyncCallback suspendingCallBack;

  LifecycleEventHandler({
    this.resumeCallBack,
    this.suspendingCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        if (resumeCallBack != null) {
          await resumeCallBack();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (suspendingCallBack != null) {
          await suspendingCallBack();
        }
        break;
    }
  }
}

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

ShapeBorder getSelectedChardShape(BuildContext context) {
  return RoundedRectangleBorder(
    side: BorderSide(width: 1, color: getSelectedCardColor(context)),
    borderRadius: BorderRadius.circular(5.0),
  );
}

BoxDecoration getSelectedDecoration(BuildContext context) {
  return BoxDecoration(
    color: getSelectedCardColor(context),
    borderRadius: BorderRadius.circular(5.0),
  );
}

BoxDecoration getNormalDecoration(BuildContext context) {
  return null;
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
