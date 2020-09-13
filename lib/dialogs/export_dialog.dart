import 'package:flutter/material.dart';
import 'package:flutter_share/flutter_share.dart';
import 'package:sound/backup.dart';
import 'package:sound/export.dart';
import 'package:sound/model.dart';

showExportDialog(BuildContext context, Note note) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      ExportType current = ExportType.PDF;

      _export() async {
        await Exporter.exportShare(note, current);

        Navigator.of(context).pop();
      }

      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: new Text("Export Options"),
          content: Row(children: [
            Padding(
              child: Text("Format:"),
              padding: EdgeInsets.only(right: 10),
            ),
            new DropdownButton(
                value: current,
                items: ExportType.values
                    .map((e) => DropdownMenuItem(
                        child: Text(getExtension(e)), value: e))
                    .toList(),
                onChanged: (v) => setState(() => current = v)),
          ]),
          actions: <Widget>[
            new FlatButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Export"),
              onPressed: () {
                _export();
              },
            ),
          ],
        );
      });
    },
  );
}
