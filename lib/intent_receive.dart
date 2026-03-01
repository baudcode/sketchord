import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sound/dialogs/audio_import_dialog.dart';

showDataInvalidSnack(BuildContext context) {
  var snackbar = SnackBar(
      content: Text("The dataformat/files were invalid"),
      backgroundColor: Theme.of(context).colorScheme.error);
  ScaffoldMessenger.of(context).showSnackBar(snackbar);
}

setupIntentReceivers(BuildContext context) {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
    return;
  }
  final sharing = ReceiveSharingIntent.instance;
  // For sharing files coming from outside the app while the app is closed
  sharing.getInitialMedia().then((List<SharedMediaFile> value) async {
    var audioExtensions = ['.m4a', ".wav", ".mp3", ".aac"];
    var _validFiles = value.where(
        (f) => audioExtensions.any((e) => f.path.toLowerCase().endsWith(e)));

    if (_validFiles.length == 0) {
      showDataInvalidSnack(context);
      return;
    }

    print("Shared valid audio files:" +
        _validFiles.map((f) => f.path).join(","));
    List<File> files = _validFiles.map((f) => File(f.path)).toList();

    showAudioImportDialog(context, files);
    // show dialog to add text/audio to file or create a new one

    });
}
