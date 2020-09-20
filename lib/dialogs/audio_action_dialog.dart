import 'package:flutter/material.dart';

class AudioAction {
  final IconData icon;
  final String description;
  final int id;

  AudioAction(this.id, this.icon, this.description);
}

showAudioActionDialog(BuildContext context, List<AudioAction> actions,
    ValueChanged<AudioAction> onActionPressed) {
  // actions are an icon with a descrition unterneath it

  showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: actions.map<Widget>((action) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: Icon(action.icon, size: 30),
                        onPressed: () => onActionPressed(action)),
                    Text(action.description, textScaleFactor: 0.7)
                  ],
                );
              }).toList()),
          // actions: [
          //   FlatButton(
          //       child: Text("Close"),
          //       onPressed: () => Navigator.of(context).pop())
          // ]
        );
      });
}
