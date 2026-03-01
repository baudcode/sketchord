import 'package:flutter/material.dart';
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
          title: const Text("Export Options"),
          content: Row(children: [
            const Padding(
              child: Text("Format:"),
              padding: EdgeInsets.only(right: 10),
            ),
            DropdownButton<ExportType>(
                value: current,
                items: ExportType.values
                    .map((e) => DropdownMenuItem<ExportType>(
                        child: Text(getExtension(e)), value: e))
                    .toList(),
                onChanged: (v) => setState(() => current = v!)),
          ]),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // usually buttons at the bottom of the dialog
            TextButton(
              child: const Text("Export"),
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
