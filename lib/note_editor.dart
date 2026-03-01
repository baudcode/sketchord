import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import 'dialogs/color_picker_dialog.dart';
import 'dialogs/export_dialog.dart';
import 'dialogs/import_dialog.dart';
import 'editor_store.dart';
import 'editor_views/additional_info.dart';
import 'editor_views/audio.dart';
import 'editor_views/section.dart';
import 'export.dart';
import 'file_manager.dart';
import 'local_storage.dart';
import 'model.dart';
import 'note_viewer.dart';
import 'recorder_bottom_sheet.dart';
import 'recorder_store.dart';
import 'share.dart';
import 'utils.dart';

class NoteEditor extends StatefulWidget {
  final Note note;
  const NoteEditor(this.note, {super.key});

  @override
  State<StatefulWidget> createState() => NoteEditorState();
}

class NoteEditorState extends State<NoteEditor> {
  final GlobalKey<ScaffoldState> _globalKey = GlobalKey<ScaffoldState>();
  final List<String> popupMenuActions = ['share', 'copy'];
  final Map<Section, GlobalKey> dismissables = {};
  StreamSubscription<AudioFile>? _recordingSub;

  @override
  void initState() {
    super.initState();
    noteEditorStore.setNote(widget.note);
    _recordingSub = recorderBottomSheetStore.onRecordingFinished.listen((f) async {
      await addAudioFile(f);
    });
  }

  @override
  void dispose() {
    _recordingSub?.cancel();
    super.dispose();
  }

  Future<void> _onFloatingActionButtonPress() async {
    if (recorderBottomSheetStore.state == RecorderState.recording) {
      await stopAction();
    } else {
      await startRecordingAction();
    }
  }

  void _onAudioFileDelete(NoteEditorStore store, AudioFile file, int index) {
    late Flushbar<void> bar;
    bar = Flushbar<void>(
      message: '${file.name} was deleted',
      onStatusChanged: (status) {
        if (status == FlushbarStatus.DISMISSED &&
            !store.note!.audioFiles.contains(file)) {
          hardDeleteAudioFile(file);
        }
      },
      mainButton: TextButton(
        child: const Text('Undo'),
        onPressed: () {
          if (!store.note!.audioFiles.contains(file)) {
            restoreAudioFile(Tuple2(file, index));
          }
          bar.dismiss();
        },
      ),
      duration: const Duration(seconds: 3),
    );
    bar.show(context);
    softDeleteAudioFile(file);
  }

  Future<void> _copyToClipboard(NoteEditorStore store) async {
    final text = Exporter.getText(store.note!);
    await Clipboard.setData(ClipboardData(text: text));
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Copied to Clipboard')),
    );
  }

  void _runPopupAction(NoteEditorStore store, String action) {
    switch (action) {
      case 'share':
        showExportDialog(context, store.note!);
        break;
      case 'star':
        toggleStarred();
        break;
      case 'copy':
        _copyToClipboard(store);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NoteEditorStore>();
    final recorderStore = context.watch<RecorderBottomSheetStore>();
    final note = store.note;
    if (note == null) {
      return const SizedBox.shrink();
    }

    final items = <Widget>[
      NoteEditorTitle(
        title: note.title,
        onChange: changeTitle,
        allowEdit: true,
      ),
    ];

    for (var i = 0; i < note.sections.length; i++) {
      final section = note.sections[i];
      dismissables.putIfAbsent(section, () => GlobalKey());
      items.add(SectionListItem(
        globalKey: dismissables[section]!,
        section: section,
        moveDown: i != (note.sections.length - 1),
        moveUp: i != 0,
      ));
    }

    items.add(const AddSectionItem());
    items.add(NoteEditorAdditionalInfo(note));

    if (note.audioFiles.isNotEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('Audio Files', style: Theme.of(context).textTheme.titleMedium),
      ));
    }

    note.audioFiles.asMap().forEach((index, f) {
      items.add(AudioFileView(
        file: f,
        index: index,
        onDelete: () => _onAudioFileDelete(store, f, index),
        onMove: () {
          showImportDialog(
            context,
            'Copy audio to',
            () async {
              final copy = await FileManager().copyToNew(f);
              Future.delayed(const Duration(milliseconds: 200), () {
                showSnack(_globalKey.currentState, 'The audio file was copied to a new note');
              });
              final newNote = Note.empty();
              newNote.audioFiles.add(copy);
              await LocalStorage().syncNote(newNote);
              return newNote;
            },
            (Note targetNote) async {
              final copy = await FileManager().copyToNew(f);
              Future.delayed(const Duration(milliseconds: 200), () {
                showSnack(_globalKey.currentState, 'The audio file was copied to ${targetNote.title}');
              });
              if (targetNote.id == widget.note.id) {
                copy.name += ' - copy';
                await addAudioFile(copy);
              } else {
                targetNote.audioFiles.add(copy);
                await LocalStorage().syncNote(targetNote);
              }
              return targetNote;
            },
            openNote: false,
            syncNote: false,
            importButtonText: 'Copy',
            newButtonText: 'Copy as NEW',
          );
        },
        onShare: () => shareFile(f.path),
        globalKey: _globalKey,
      ));
    });

    final showSheet = recorderStore.state == RecorderState.pausing ||
        recorderStore.state == RecorderState.playing ||
        recorderStore.state == RecorderState.recording;

    final icon = Icon(
      recorderStore.state == RecorderState.recording ? Icons.mic_none : Icons.mic,
      color: recorderStore.state == RecorderState.recording
          ? Theme.of(context).colorScheme.secondary
          : null,
    );

    final actions = <Widget>[
      IconButton(
        icon: Icon(note.starred ? Icons.star : Icons.star_border),
        onPressed: () => toggleStarred(),
      ),
      IconButton(icon: icon, onPressed: _onFloatingActionButtonPress),
      Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: () => showColorPickerDialog(context, note.color, changeColor),
          ),
          Positioned(
            bottom: 17,
            right: 14,
            child: Container(
              decoration: BoxDecoration(
                color: note.color,
                borderRadius: BorderRadius.circular(10),
              ),
              height: 10,
              width: 10,
            ),
          ),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.play_circle_filled),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteViewer(
                note,
                showAdditionalInformation: false,
                showAudioFiles: false,
                showSheet: true,
                showTitle: false,
              ),
            ),
          );
        },
      ),
      PopupMenuButton<String>(
        onSelected: (action) => _runPopupAction(store, action),
        itemBuilder: (context) {
          return popupMenuActions
              .map((action) => PopupMenuItem(value: action, child: Text(action)))
              .toList();
        },
      ),
    ];

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          stopAction();
        }
      },
      child: Scaffold(
        key: _globalKey,
        appBar: AppBar(actions: actions),
        bottomSheet: showSheet ? const RecorderBottomSheet(key: Key('bottomSheet')) : null,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            itemBuilder: (context, index) => items[index],
            itemCount: items.length,
          ),
        ),
      ),
    );
  }
}
