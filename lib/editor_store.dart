import 'package:flutter/material.dart' show Color;
import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;
import 'local_storage.dart';
import 'file_manager.dart';
import 'model.dart';
import 'package:tuple/tuple.dart';

class NoteEditorStore extends Store {
  Note _note;
  Note get note => _note;

  Tuple2<int, dynamic> _lastDeletion;

  void setNote(Note n) {
    _note = n;
  }

  NoteEditorStore() {
    editorSetNote.listen((note) {
      _note = note;
      trigger();
    });

    addAudioFile.listen((f) async {
      _note.audioFiles.add(f);
      await LocalStorage().syncNoteAttr(_note, 'audioFiles');

      trigger();
    });

    addSection.listen((s) async {
      _note.sections.add(s);
      await LocalStorage().syncNoteAttr(_note, 'sections');
      trigger();
    });

    hardDeleteAudioFile.listen((f) async {
      FileManager().delete(f);

      _note.audioFiles.remove(f);
      print("Removing: ${f.name}");
      await LocalStorage().syncNoteAttr(_note, 'audioFiles');

      trigger();
    });

    softDeleteAudioFile.listen((AudioFile f) async {
      _note.audioFiles.remove(f);
      print("Softly emoving: ${f.name}");

      //FileManager().delete(f);
      //await LocalStorage().syncNoteAttr(_note, 'audioFiles');

      trigger();
    });

    deleteSection.listen((s) async {
      int index = _note.sections.indexOf(s);
      _note.sections.removeAt(index);
      _lastDeletion = Tuple2(index, s);
      await LocalStorage().syncNoteAttr(_note, 'sections');

      trigger();
    });

    undoDeleteSection.listen((_) async {
      _note.sections.insert(_lastDeletion.item1, _lastDeletion.item2);
      await LocalStorage().syncNoteAttr(_note, 'sections');
      trigger();
    });
    moveSectionUp.listen((s) async {
      int index = _note.sections.indexOf(s);
      if (index >= 1) {
        print("move up with index $index");
        _note.sections.removeAt(index);
        _note.sections.insert(index - 1, s);
        await LocalStorage().syncNoteAttr(_note, 'sections');
        trigger();
      }
    });
    moveSectionDown.listen((s) async {
      int index = _note.sections.indexOf(s);
      if (index != (note.sections.length - 1) && index >= 0) {
        print('move down with index: $index');
        _note.sections.removeAt(index);
        _note.sections.insert(index + 1, s);
        await LocalStorage().syncNoteAttr(_note, 'sections');
      }
      trigger();
    });
    changeSectionTitle.listen((t) async {
      int index = _note.sections.indexOf(t.item1);
      _note.sections[index].title = t.item2;
      await LocalStorage().syncNoteAttr(_note, 'sections');
      trigger();
    });

    changeTitle.listen((t) async {
      _note.title = t;
      print('chaning title...');
      await LocalStorage().syncNoteAttr(_note, 'title');
      trigger();
    });

    changeContent.listen((t) async {
      int index = _note.sections.indexOf(t.item1);
      _note.sections[index].content = t.item2;
      await LocalStorage().syncNoteAttr(_note, 'sections');
      trigger();
    });

    changeCapo.listen((String x) async {
      _note.capo = x;
      await LocalStorage().syncNoteAttr(_note, 'capo');
      trigger();
    });

    changeAudioFile.listen((AudioFile f) async {
      int index = _note.audioFiles.indexWhere((AudioFile a) => a.id == f.id);
      if (index == -1) {
        print("cannot change audio file, file not found");
        return;
      }
      _note.audioFiles[index] = f;

      await LocalStorage().syncNoteAttr(_note, 'audioFiles');
      trigger();
    });

    changeTuning.listen((String x) async {
      if (x.trim() == "") return;
      _note.tuning = x;
      await LocalStorage().syncNoteAttr(_note, 'tuning');
      trigger();
    });
    changeKey.listen((String x) async {
      if (x.trim() == "") return;
      _note.key = x;
      await LocalStorage().syncNoteAttr(_note, 'key');
      trigger();
    });
    changeLabel.listen((String x) async {
      if (x.trim() == "") return;
      _note.label = x;
      await LocalStorage().syncNoteAttr(_note, 'label');
      trigger();
    });
    changeArtist.listen((String x) async {
      if (x.trim() == "") return;
      _note.artist = x;
      await LocalStorage().syncNoteAttr(_note, 'artist');
      trigger();
    });
    changeInstrument.listen((String x) async {
      if (x.trim() == "") return;
      _note.instrument = x;
      await LocalStorage().syncNoteAttr(_note, 'instrument');
      trigger();
    });

    updateNoteEditorView.listen((_) {
      trigger();
    });

    restoreAudioFile.listen((Tuple2<AudioFile, int> a) async {
      print(
          "restoring audio file ${a.item1.path} at ${a.item2} into the notes");
      _note.audioFiles.insert(a.item2, a.item1);
      await LocalStorage().syncNoteAttr(_note, 'audioFiles');
      trigger();
    });

    toggleStarred.listen((event) async {
      _note.starred = !_note.starred;
      await LocalStorage().syncNoteAttr(_note, 'starred');
      trigger();
    });

    changeColor.listen((Color event) async {
      _note.color = event;
      await LocalStorage().syncNoteAttr(_note, 'color');
      trigger();
    });
  }
}

Action<Note> editorSetNote = Action();
Action<AudioFile> softDeleteAudioFile = Action();
Action<AudioFile> hardDeleteAudioFile = Action();
Action<Section> deleteSection = Action();
Action undoDeleteSection = Action();
Action<Section> addSection = Action();
Action<Section> moveSectionUp = Action();
Action<Section> moveSectionDown = Action();
Action<Tuple2<Section, String>> changeSectionTitle = Action();
Action<String> changeTitle = Action();
Action<String> changeCapo = Action();
Action<String> changeTuning = Action();
Action<String> changeKey = Action();
Action<String> changeLabel = Action();
Action<String> changeArtist = Action();
Action<String> changeInstrument = Action();
Action<AudioFile> changeAudioFile = Action();
Action<Tuple2<Section, String>> changeContent = Action();
Action<AudioFile> addAudioFile = Action();
Action<Tuple2<AudioFile, int>> restoreAudioFile = Action();
Action<Tuple2<AudioFile, bool>> uploadCallback = Action();
Action updateNoteEditorView = Action();
Action toggleStarred = Action();
Action<Color> changeColor = Action();

StoreToken noteEditorStoreToken = StoreToken(NoteEditorStore());
