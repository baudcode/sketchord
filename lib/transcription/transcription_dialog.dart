import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../model.dart';
import '../share.dart';
import 'midi_encoder.dart';
import 'model_catalog.dart';
import 'model_download_manager.dart';
import 'midi_preview_player.dart';
import 'transcriber.dart';
import 'types.dart';

Future<void> showTranscriptionDialog(
    BuildContext context, AudioFile audio) async {
  var selected = OnDeviceModel.basicPitch;
  var downloading = false;
  var progress = 0.0;
  String? error;
  TranscriptionResult? result;
  File? midiFile;
  var midiPlaying = false;
  final midiPreview = MidiPreviewPlayer();

  Future<void> run(StateSetter setState) async {
    setState(() {
      downloading = true;
      progress = 0;
      error = null;
      result = null;
    });
    try {
      final output = await OnDeviceTranscriber().transcribe(
        audio.path,
        selected,
        onDownloadProgress: (value) => setState(() => progress = value),
      );
      final directory = await getApplicationDocumentsDirectory();
      final safeName = p
          .basenameWithoutExtension(audio.name)
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      midiFile =
          File(p.join(directory.path, '${safeName}_${selected.name}.mid'));
      await midiFile!.writeAsBytes(
        MidiEncoder.encode(output.notes),
        flush: true,
      );
      setState(() => result = output);
    } on ModelUnavailableException catch (exception) {
      setState(() => error = exception.message);
    } on FormatException catch (exception) {
      setState(() => error = exception.message);
    } catch (_) {
      setState(() => error =
          'Transcription failed. Please try another model or audio clip.');
    } finally {
      setState(() => downloading = false);
    }
  }

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final info = modelInfo(selected);
          return AlertDialog(
            title: const Text('Transcribe to MIDI'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(audio.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  DropdownButton<OnDeviceModel>(
                    value: selected,
                    isExpanded: true,
                    items: onDeviceModels
                        .map((entry) => DropdownMenuItem(
                              value: entry.model,
                              child: Text(entry.title),
                            ))
                        .toList(),
                    onChanged: downloading
                        ? null
                        : (value) => setState(() {
                              selected = value!;
                              error = null;
                              result = null;
                            }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    info.runtime == TranscriptionRuntime.dart
                        ? 'Built into the app; no download required.'
                        : ModelDownloadManager.hasBundledUpstreamArtifact(
                                    selected) ||
                                ModelDownloadManager.hasRemoteManifest
                            ? 'Downloads only after you tap Transcribe.'
                            : 'Requires this app build to configure a reviewed '
                                'model manifest before it can download.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!info.productionReady) ...[
                    const SizedBox(height: 4),
                    Text('Licence: ${info.license}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (downloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                        value: progress == 0 ? null : progress),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  if (result != null) ...[
                    const SizedBox(height: 16),
                    Text(
                        '${result!.notes.length} notes exported to ${p.basename(midiFile!.path)}.'),
                    if (result!.warnings.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(result!.warnings.first,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              if (result != null)
                TextButton.icon(
                  icon: Icon(midiPlaying ? Icons.stop : Icons.piano),
                  label: Text(midiPlaying ? 'Stop MIDI' : 'Play MIDI'),
                  onPressed: () async {
                    if (midiPlaying) {
                      await midiPreview.stop();
                      setState(() => midiPlaying = false);
                      return;
                    }
                    try {
                      setState(() => midiPlaying = true);
                      await midiPreview.play(result!.notes, onComplete: () {
                        if (context.mounted)
                          setState(() => midiPlaying = false);
                      });
                    } catch (_) {
                      if (context.mounted) {
                        setState(() {
                          midiPlaying = false;
                          error = 'Could not start the Grand Piano preview.';
                        });
                      }
                    }
                  },
                ),
              if (result != null)
                TextButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share MIDI'),
                  onPressed: () => shareFile(
                    midiFile!.path,
                    text: 'MIDI transcription of ${audio.name}',
                  ),
                ),
              TextButton(
                onPressed: downloading
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: downloading ? null : () => run(setState),
                icon: const Icon(Icons.music_note),
                label: Text(result == null ? 'Transcribe' : 'Transcribe again'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    await midiPreview.stop();
  }
}
