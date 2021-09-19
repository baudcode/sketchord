import 'package:flutter/material.dart';
import 'package:flutter_share/flutter_share.dart';
import 'package:sound/backup.dart';
import 'package:sound/export.dart';
import 'package:sound/model.dart';

showExportDialog(BuildContext context, List<Note> notes,
    {List<NoteCollection> collections, String title}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      ExportType current = ExportType.ZIP;

      _share() async {
        await Exporter.exportShare(notes, current,
            collections: collections, title: title);
        Navigator.of(context).pop();
      }

      _save() async {
        await Exporter.exportDialog(notes, current,
            collections: collections, title: title);
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
            DropdownButton(
                value: current,
                items: [ExportType.ZIP, ExportType.PDF, ExportType.TEXT]
                    .map((e) => DropdownMenuItem(
                        child: Text(getExtension(e)), value: e))
                    .toList(),
                onChanged: (v) => setState(() => current = v)),
          ]),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            ElevatedButton(child: Text("Share"), onPressed: _share),
            ElevatedButton(onPressed: _save, child: Text("Save"))
          ],
        );
      });
    },
  );
}
