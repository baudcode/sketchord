import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ColorPicker extends StatelessWidget {
  final Color pickerColor;
  final List<Color> availableColors;
  final ValueChanged<Color> onColorChanged;

  ColorPicker({this.availableColors, this.onColorChanged, this.pickerColor});

  _getItem(Color color) {
    return Padding(
        padding: EdgeInsets.all(8),
        child: GestureDetector(
            onTap: () => onColorChanged(color),
            child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: color == pickerColor
                    ? IconButton(
                        icon: Icon(Icons.check,
                            color: color.computeLuminance() < 0.5
                                ? Colors.white
                                : Colors.black),
                        onPressed: () {})
                    : null)));
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width * 0.7;
    double height = MediaQuery.of(context).size.height * 0.5;

    return Container(
        width: width,
        height: height,
        child: GridView.count(
            childAspectRatio: 1.0,
            padding: const EdgeInsets.all(2.0),
            mainAxisSpacing: 2.0,
            crossAxisSpacing: 2.0,
            crossAxisCount: 4,
            children: availableColors
                .map<Widget>((color) => _getItem(color))
                .toList()));
  }
}

List<Color> getCardColors(BuildContext context) {
  Color cardColor = Theme.of(context).cardColor;
  List<MaterialColor> materials = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  List<Color> colors = [];
  for (var i = 0; i < materials.length; i++) {
    colors.add(materials[i].shade300);
  }
  colors.add(cardColor);
  return colors;
}

showColorPickerDialog(BuildContext context, Color currentColor,
    ValueChanged<Color> onColorChanged) {
  List<Color> colors = getCardColors(context);

  _onCancel() {
    Navigator.of(context).pop();
  }

  showDialog(
      context: context,
      builder: (context) {
        Color selected = currentColor;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            titlePadding: const EdgeInsets.all(16),
            contentPadding: const EdgeInsets.all(8),
            title: Text("Choose a Color"),
            actions: [
              FlatButton(child: Text("Cancel"), onPressed: _onCancel),
              FlatButton(
                  child: Text("Apply"),
                  onPressed: () {
                    onColorChanged(selected);
                    Navigator.of(context).pop();
                  }),
            ],
            content: SingleChildScrollView(
              child: ColorPicker(
                availableColors: colors,
                pickerColor:
                    selected == null ? Theme.of(context).cardColor : selected,
                onColorChanged: (color) => setState(() => selected = color),
              ),
            ),
          );
        });
      });
}
