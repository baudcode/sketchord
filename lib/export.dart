import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sound/backup.dart';
import 'package:sound/model.dart';

import 'package:path/path.dart' as p;

class Exporter {
  static Future<String> pdf(Note note) async {
    Directory d = await Backup().getFilesDir();
    String path = p.join(d.path, "${note.title}.pdf");

    // final Uint8List fontData = File('open-sans.ttf').readAsBytesSync();
    // final ttf = pw.Font.ttf(fontData.buffer.asByteData());
    final pdf = pw.Document();
    List<pw.Row> sections = [];

    for (var section in note.sections) {
      sections.add(pw.Row(children: [
        pw.Text(section.title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
      ]));
      sections.add(pw.Row(children: [pw.Container(height: 5)]));
      sections.add(pw.Row(children: [pw.Text(section.content)]));
      sections.add(pw.Row(children: [pw.Container(height: 25)]));
    }

    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
              padding: pw.EdgeInsets.all(10.0),
              child: pw.Column(
                  children: [
                pw.Row(children: [
                  pw.Center(
                      child: pw.Text(note.title,
                          style: pw.TextStyle(fontSize: 20)))
                ]),
                pw.Row(children: [pw.Container(height: 50)]),
              ]..addAll(sections)));
        })); // Page

    final file = File(path);
    await file.writeAsBytes(pdf.save());
    return path;
  }
}
