import 'package:flutter/material.dart';

showChangeNumberDialog(BuildContext context, String title, double _value,
    ValueChanged<double> onChange,
    {double step = 1.0, bool asInt = true}) {
  showDialog(
      context: context,
      builder: (context) {
        double value = _value;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
              title: Text(title),
              content: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            value = value - step;
                          });
                        }),
                    Text(asInt ? value.toInt().toString() : value.toString(),
                        style: Theme.of(context)
                            .textTheme
                            .caption
                            .copyWith(fontSize: 20)),
                    IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            value = value + step;
                          });
                        })
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
