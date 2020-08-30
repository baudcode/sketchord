import 'package:flutter/material.dart';
import 'package:flutter_share/flutter_share.dart';
import 'package:sound/utils.dart';
import 'db.dart';
import 'backup.dart';
import 'model.dart';

class ExportNote extends StatefulWidget {
  final ScaffoldState state;

  ExportNote({this.state});

  @override
  State<StatefulWidget> createState() {
    return ExportNoteState();
  }
}

class ExportNoteState extends State<ExportNote> {
  String id;

  @override
  void initState() {
    super.initState();
    id = null;
  }

  Note get note => DB().notes.firstWhere((n) => n.id == id, orElse: () => null);

  _export() async {
    if (note == null) {
      showSnack(widget.state, "Please select a note to export first");
      return;
    }
    String path = await Backup().exportNote(note);

    await FlutterShare.shareFile(
        title: '${note.title}.json',
        text: 'Sharing Json of ${note.title}',
        filePath: path);
  }

  @override
  Widget build(BuildContext context) {
    print("note: ${note == null}");
    print("notes: ${DB().notes.length}");
    return Wrap(
        //spacing: 20, // to apply margin in the main axis of the wra/p
        //runSpacing: 20, // apply margin in the cross axis of the wrap
        children: [
          // Row(
          //   children: [
          //     Text("Export Single Note",
          //         style: Theme.of(context).textTheme.subtitle1)
          //   ],
          // ),
          Row(children: [
            Expanded(
                child: DropdownButton<String>(
              isExpanded: true,
              //hint: Text("Select a note by name"),
              value: id,
              items: DB()
                  .notes
                  .map((Note note) => DropdownMenuItem<String>(
                        value: note.id,
                        child:
                            Text("${DB().notes.indexOf(note)}: ${note.title}"),
                      ))
                  .toList(),
              onChanged: (newId) {
                print("onChanged.... $newId");
                setState(() {
                  id = newId;
                });
              },
            )),
            Container(
              width: 100,
              child: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child:
                      RaisedButton(onPressed: _export, child: Text("Export"))),
            )
          ])
        ]);
  }
}
