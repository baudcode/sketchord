import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_share/flutter_share.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sound/backup.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';

import 'package:path/path.dart' as p;

enum ExportType { PDF, JSON, TEXT, ZIP }

String getExtension(ExportType t) {
  switch (t) {
    case ExportType.JSON:
      return "json";
    case ExportType.PDF:
      return "pdf";
    case ExportType.TEXT:
      return "text";
    case ExportType.ZIP:
      return "zip";

    default:
      return "";
  }
}

class PDFExporter {
  pw.Document pdf;
  var textStyle = pw.TextStyle();

  PDFExporter() {
    pdf = pw.Document();
  }

  static Future<pw.Font> loadFont(String name) async {
    var data = await rootBundle.load("assets/fonts/$name");
    return pw.Font.ttf(data);
  }

  static String formatText(String text) {
    return latin1.decode(utf8.encode(text), allowInvalid: false);
  }

  static List<String> splitTextPerRow(String text, {int maxRows = 60}) {
    List<String> rows = text.split("\n");
    List<String> split = [];

    for (int i = 0; i < rows.length; i += maxRows) {
      int end = (i + maxRows) > rows.length ? rows.length : i + maxRows;
      print("Split from $i to $end");
      split.add(rows.sublist(i, end).join("\n"));
    }
    return split;
  }

  List<pw.Page> getPages(Note note, int totalPageCount, int pageOffset) {
    //var data = await rootBundle.load("assets/fonts/arial.ttf");
    //var customFont = pw.Font.ttf(data);
    //var textStyle = pw.TextStyle(font: customFont);

    // var textStyle = pw.TextStyle(
    //     font: await loadFont("OpenSans-Regular.ttf"),
    //     fontBold: await loadFont("OpenSans-Bold.ttf"));

    String info = note.getInfoText();
    // final Uint8List fontData = File('open-sans.ttf').readAsBytesSync();
    // final ttf = pw.Font.ttf(fontData.buffer.asByteData());
    List<pw.Row> sections = [];
    List<List<pw.Row>> sectionRows = [];

    int rows = 0;

    List<Section> noteSections = note.sections
        .where((element) => element.content.trim().length > 0)
        .toList();

    for (var section in noteSections) {
      int sectionLength = section.content.split("\n").length;

      if (((sectionRows.length == 0 && (rows + sectionLength) > 50)) ||
          ((sectionRows.length > 0) && (rows + sectionLength) > 58)) {
        sectionRows.add(sections);
        sections = [];
        rows = 0;
      }

      rows += 3;
      rows += sectionLength;

      // separate content to multiple rows

      sections.add(pw.Row(children: [
        pw.Text(formatText(section.title),
            style: textStyle.copyWith(fontWeight: pw.FontWeight.bold))
      ]));
      sections.add(pw.Row(children: [pw.Container(height: 5)]));

      List<String> split = splitTextPerRow(section.content);

      print("section has ${split.length} splits...");

      for (int i = 0; i < split.length; i++) {
        var text = split.elementAt(i);

        sections.add(pw.Row(children: [
          pw.Text(formatText(text),
              style: textStyle.copyWith(fontSize: 11 * PdfPageFormat.point))
        ]));

        if (i != split.length - 1) {
          sectionRows.add(sections);
          sections = [];
        } else {}
      }
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
        pw.Row(
            children: [pw.Text(info, style: textStyle.copyWith(fontSize: 12))]),
        pw.Row(children: [pw.Container(height: 10)])
      ]);
    }
    // add title
    titleRows.add(pw.Row(children: [
      pw.Center(
          child: pw.Text(formatText(note.title),
              style: textStyle.copyWith(fontSize: 20)))
    ]));
    // spacing between title and content
    titleRows.add(pw.Row(children: [pw.Container(height: 50)]));

    String artist = (note.artist != null ? note.artist : Settings().name);
    artist = formatText(artist);

    var copyright = (artist == null)
        ? pw.Container()
        : pw.Positioned(
            bottom: 0,
            right: 0,
            child: pw.Text("© ${formatText(artist)}", style: textStyle),
          );

    List<pw.Page> pages = [];

    for (var i = 0; i < sectionRows.length; i++) {
      var page = pw.Positioned(
        bottom: 0,
        left: 0,
        child: pw.Text("Page ${pageOffset + i + 1}/$totalPageCount",
            style: textStyle),
      );

      pages.add(pw.Page(
          margin: pw.EdgeInsets.only(top: 50, bottom: 20, left: 50, right: 20),
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Stack(children: [
              copyright,
              page,
              pw.Column(
                  children: (i == 0)
                      ? (titleRows..addAll(sectionRows[i]))
                      : sectionRows[i])
            ]);
          })); // Page
    }

    return pages;
  }

  addNotes(List<Note> notes) {
    if (notes.length == 0) return;

    int totalPageCount = notes
        .map((e) => getPages(e, 0, 0).length)
        .toList()
        .reduce((a, b) => a + b);

    int offset = 0;

    for (Note note in notes) {
      var pages = getPages(note, totalPageCount, offset);
      offset += pages.length;

      for (var page in pages) {
        pdf.addPage(page);
      }
    }
  }

  String save(String path) {
    File(path).writeAsBytesSync(pdf.save());
    return path;
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
        return json([note]);
      case ExportType.PDF:
        return pdf([note]);
      case ExportType.TEXT:
        return text([note]);
      case ExportType.ZIP:
        return zip([note]);

      default:
        return null;
    }
  }

  static Future<String> exportNotes(List<Note> notes, ExportType t,
      {List<NoteCollection> collections, String title}) async {
    Settings settings = await LocalStorage().getSettings();

    for (Note note in notes) {
      if (note.artist == null) {
        if (settings != null) {
          note.artist = settings.name;
        }
      }
    }

    switch (t) {
      case ExportType.JSON:
        return json(notes, collections: collections, title: title);
      case ExportType.PDF:
        return pdf(notes, title: title);
      case ExportType.TEXT:
        return text(notes, title: title);
      case ExportType.ZIP:
        return zip(notes, collections: collections, title: title);

      default:
        return null;
    }
  }

  static Future<String> zip(List<Note> notes,
      {List<NoteCollection> collections, String title}) async {
    return await Backup().exportZip(notes,
        collections: collections, filename: getFilename(notes, 'zip'));
  }

  static Future<void> exportShare(List<Note> notes, ExportType t,
      {List<NoteCollection> collections}) async {
    String path = await exportNotes(notes, t, collections: collections);
    String title = p.basename(path);

    print("export to $path");
    await FlutterShare.shareFile(
        title: '$title.${getExtension(t)}',
        text: 'Sharing $title from SOUND',
        filePath: path);
  }

  static Future<String> saveFileDialog(String path) async {
    final params = SaveFileDialogParams(sourceFilePath: path);
    return await FlutterFileDialog.saveFile(params: params);
  }

  static Future<void> exportDialog(List<Note> notes, ExportType t,
      {List<NoteCollection> collections}) async {
    String path = await exportNotes(notes, t, collections: collections);
    await saveFileDialog(path);
  }

  static String getText(Note note) {
    String info = note.getInfoText();
    String contents = "";

    if (note.artist != null) {
      contents += "© ${note.artist} \n\n";
    }
    contents += note.title + "\n\n";

    if (info != null) {
      contents += info;
    }
    contents += "\n\n\n";
    for (var i = 0; i < note.sections.length; i++) {
      Section section = note.sections[i];

      var sectionTitleEmpty =
          section.title == null || section.title.trim() == "";
      var contentEmpty =
          section.content == null || section.content.trim() == "";

      if (sectionTitleEmpty) {
        if (!contentEmpty) {
          contents += section.content;
        }
      } else {
        contents += "[${section.title}]" + "\n\n";
        contents += section.content;
      }

      if ((!sectionTitleEmpty || !contentEmpty) &&
          i != (note.sections.length - 1)) {
        contents += "\n\n";
      }
    }
    return contents;
  }

  static String getFilename(List<Note> notes, String extension,
      {String title}) {
    if (title == null) title = "${notes.length} notes";
    if (notes.length == 1) title = notes.elementAt(0).title;
    return "$title.$extension";
  }

  static Future<String> getPath(List<Note> notes, String extension,
      {String title}) async {
    Directory d = await Backup().getFilesDir();
    return p.join(d.path, getFilename(notes, extension));
  }

  static Future<String> text(
    List<Note> notes, {
    String title,
  }) async {
    String contents = "";

    for (int i = 0; i < notes.length; i++) {
      contents += getText(notes.elementAt(0));
      if (i != 0 && i != (notes.length - 1)) {
        contents += "\n\n\n\n";
      }
    }

    String path = await getPath(notes, "txt", title: title);
    File(path).writeAsStringSync(contents);
    return path;
  }

  static Future<String> json(List<Note> notes,
      {String title, List<NoteCollection> collections}) async {
    //return await Backup().exportNote(note);
    String path = await getPath(notes, "json", title: title);
    Map<String, dynamic> data;

    data = {
      "notes": notes.map((e) => e.toJson()).toList(),
    };

    if (collections != null) {
      data["collections"] = collections.map((e) => e.toJson()).toList();
    }

    File(path).writeAsStringSync(jsonEncode(data));
    return path;
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

  static Future<String> pdf(List<Note> notes, {String title}) async {
    String path = await getPath(notes, "pdf", title: title);

    PDFExporter exporter = PDFExporter();
    exporter.addNotes(notes);

    return exporter.save(path);
  }
}
