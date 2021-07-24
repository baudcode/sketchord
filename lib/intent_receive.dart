import 'dart:io';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sound/dialogs/audio_import_dialog.dart';
import 'package:sound/dialogs/text_import_dialog.dart';

showDataInvalidSnack(BuildContext context) {
  var snackBar = SnackBar(
      content: Text("The dataformat/files were invalid"),
      backgroundColor: Theme.of(context).errorColor);
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

setupIntentReceivers(BuildContext context) {
  // For sharing or opening urls/text coming from outside the app while the app is closed
  ReceiveSharingIntent.getInitialText().then((String value) {
    if (value != null) {
      showTextImportDialog(context, value);
    }
  });

  // For sharing images coming from outside the app while the app is closed
  ReceiveSharingIntent.getInitialMedia()
      .then((List<SharedMediaFile> value) async {
    if (value != null) {
      var audioExtensions = ['.m4a', ".wav", ".mp3", ".aac"];
      var _validFiles = value.where(
          (f) => audioExtensions.any((e) => f.path.toLowerCase().endsWith(e)));

      if (_validFiles.length == 0) {
        showDataInvalidSnack(context);
        return;
      }

      print("Shared valid audio files:" +
          (_validFiles?.map((f) => f.path)?.join(",") ?? ""));
      List<File> files = _validFiles.map((f) => File(f.path)).toList();

      showAudioImportDialog(context, files);
      // show dialog to add text/audio to file or create a new one

    }
  });
}
