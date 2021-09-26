import 'package:flutter/material.dart';
import 'package:sound/utils.dart';

showChangeNumberDialog(BuildContext context, String title, double _value,
    ValueChanged<double> onChange,
    {double step = 1.0,
    bool asInt = true,
    double max,
    double min,
    bool isTime = false,
    double longPressStep = 2}) {
  showDialog(
      context: context,
      builder: (context) {
        double value = _value;
        bool isLongPressed = false;

        String getValue() {
          if (isTime) {
            return toTime(value.toInt());
          } else {
            return asInt ? value.toInt().toString() : value.toString();
          }
        }

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
              title: Text(title),
              content: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onLongPressEnd: (_) =>
                          setState(() => isLongPressed = false),
                      onLongPressStart: (_) async {
                        isLongPressed = true;
                        do {
                          if (longPressStep != null) {
                            setState(() {
                              value = (min == null ||
                                      (value - longPressStep) >= min)
                                  ? (value - longPressStep)
                                  : min;
                            });
                          }
                          await Future.delayed(Duration(seconds: 1));
                        } while (isLongPressed);
                      },
                      child: IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              value = ((min == null) || (value - step) >= min)
                                  ? (value - step)
                                  : min;
                            });
                          }),
                    ),
                    Text(getValue(),
                        style: Theme.of(context)
                            .textTheme
                            .caption
                            .copyWith(fontSize: 20)),
                    GestureDetector(
                      onLongPressStart: (_) async {
                        isLongPressed = true;
                        do {
                          if (longPressStep != null) {
                            setState(() {
                              value = (max == null ||
                                      (value + longPressStep) <= max)
                                  ? (value + longPressStep)
                                  : max;
                            });
                          }
                          await Future.delayed(Duration(seconds: 1));
                        } while (isLongPressed);
                      },
                      onLongPressEnd: (_) =>
                          setState(() => isLongPressed = false),
                      onLongPress: () {},
                      child: IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              value = (max == null || (value + step) <= max)
                                  ? (value + step)
                                  : max;
                            });
                          }),
                    )
                  ]),
              actions: <Widget>[
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
                new ElevatedButton(
                  child: new Text("Apply"),
                  onPressed: () {
                    onChange(value);
                    Navigator.of(context).pop();
                  },
                ),
              ]);
        });
      });
}
