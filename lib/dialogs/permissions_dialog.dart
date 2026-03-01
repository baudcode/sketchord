import 'package:flutter/material.dart';

showHasNoPermissionsDialog(BuildContext context) {
  showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
            title: Text("Permission denied"),
            content: Text(
                "You have to allow using the microphone permissions in the settings of your phone!"),
            actions: <Widget>[
              new ElevatedButton(
                child: new Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ]);
      });
}
