import 'package:flutter_share/flutter_share.dart';
import 'package:path/path.dart' as p;

Future<bool> shareFile(String path, {String filename, String text}) async {
  if (filename == null) filename = p.basename(path);
  if (text == null) text = 'Sharing file $filename';

  return await FlutterShare.shareFile(
      title: filename, text: text, filePath: path);
}
