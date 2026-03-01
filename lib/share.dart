import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

Future<void> shareFile(String path, {String? filename, String? text}) async {
  if (filename == null) filename = p.basename(path);
  if (text == null) text = 'Sharing file $filename';

  await SharePlus.instance.share(ShareParams(
    title: filename,
    text: text,
    files: [XFile(path)],
  ));
}
