import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_share/flutter_share.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sound/backup.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';

import 'package:path/path.dart' as p;

enum ExportType { PDF, JSON, TEXT }

String getExtension(ExportType t) {
  switch (t) {
    case ExportType.JSON:
      return "json";
    case ExportType.PDF:
      return "pdf";
    case ExportType.TEXT:
      return "text";
    default:
      return "";
  }
}

class Exporter {
  static Future<String> export(Note note, ExportType t) async {
    if (note.artist == null) {
      Settings settings = await LocalStorage().getSettings();
      if (settings != null) {
        note.artist = settings.name;
      }
    }

    switch (t) {
      case ExportType.JSON:
        return json(note);
      case ExportType.PDF:
        return pdf(note);
      case ExportType.TEXT:
        return text(note);
      default:
        return null;
    }
  }

  static Future<void> exportShare(Note note, ExportType t) async {
    String path = await export(note, t);
    print("export to $path");
    await FlutterShare.shareFile(
        title: '${note.title}.${getExtension(t)}',
        text: 'Sharing ${note.title} from SOUND',
        filePath: path);
  }

  static String getText(Note note) {
    String info = note.getInfoText();
    String contents = "";

    if (note.artist != null) {
      contents += "© ${note.artist} \n";
    }
    contents += note.title + "\n";

    if (info != null) {
      contents += info;
    }
    contents += "\n\n\n";
    for (Section section in note.sections) {
      contents += "[${section.title}]" + "\n\n";
      contents += section.content;
      contents += "\n\n";
    }
    return contents;
  }

  static Future<String> text(Note note) async {
    Directory d = await Backup().getFilesDir();
    String path = p.join(d.path, "${note.title}.txt");

    String contents = getText(note);
    File(path).writeAsStringSync(contents);
    return path;
  }

  static Future<String> json(Note note) async {
    return await Backup().exportNote(note);
  }

  static Future<Size> getSize(String text, TextStyle textStyle,
      {double textScaleFactor = 1.0}) async {
    return (TextPainter(
            text: TextSpan(text: text, style: textStyle),
            maxLines: 1,
            textScaleFactor: textScaleFactor,
            textDirection: TextDirection.ltr)
          ..layout())
        .size;
  }

  static Future<String> pdf(Note note) async {
    Directory d = await Backup().getFilesDir();
    String path = p.join(d.path, "${note.title}.pdf");

    String info = note.getInfoText();
    // final Uint8List fontData = File('open-sans.ttf').readAsBytesSync();
    // final ttf = pw.Font.ttf(fontData.buffer.asByteData());
    final pdf = pw.Document();
    List<pw.Row> sections = [];
    List<List<pw.Row>> sectionRows = [];

    int rows = 0;

    for (var section in note.sections) {
      int sectionLength = section.content.split("\n").length;
      if ((rows + sectionLength) > 50) {
        sectionRows.add(sections);
        sections = [];
        rows = 0;
      }

      rows += 3;
      rows += sectionLength;

      sections.add(pw.Row(children: [
        pw.Text(section.title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
      ]));
      sections.add(pw.Row(children: [pw.Container(height: 5)]));
      sections.add(pw.Row(children: [pw.Text(section.content)]));
      sections.add(pw.Row(children: [pw.Container(height: 10)]));

      print("rows: $rows");
    }

    if (sections.length > 0) {
      sectionRows.add(sections);
    }

    print("Got ${sectionRows.length} section rows");

    List<pw.Row> titleRows = [];

    // add capo information / artist information...
    if (info != null) {
      titleRows.addAll([
        pw.Row(children: [pw.Text(info, style: pw.TextStyle(fontSize: 12))]),
        pw.Row(children: [pw.Container(height: 10)])
      ]);
    }
    // add title
    titleRows.add(pw.Row(children: [
      pw.Center(child: pw.Text(note.title, style: pw.TextStyle(fontSize: 20)))
    ]));
    // spacing between title and content
    titleRows.add(pw.Row(children: [pw.Container(height: 20)]));

    String artist = (note.artist != null ? note.artist : Settings().name);

    var copyright = (artist == null)
        ? pw.Container()
        : pw.Positioned(
            bottom: 0,
            right: 0,
            child: pw.Text("© $artist"),
          );

    for (var i = 0; i < sectionRows.length; i++) {
      pdf.addPage(pw.Page(
          margin: pw.EdgeInsets.all(20),
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Stack(children: [
              copyright,
              pw.Column(
                  children: (i == 0)
                      ? (titleRows..addAll(sectionRows[i]))
                      : sectionRows[i])
            ]);
          })); // Page
    }
    final file = File(path);
    await file.writeAsBytes(pdf.save());
    return path;
  }
}
