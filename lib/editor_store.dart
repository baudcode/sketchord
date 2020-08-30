import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;
import 'local_storage.dart';
import 'file_manager.dart';
import 'model.dart';
import 'package:tuple/tuple.dart';

class NoteEditorStore extends Store {
  Note _note;
  Note get note => _note;

  bool _loading = false;
  Tuple2<int, dynamic> _lastDeletion;

  bool get loading => _loading;

  void setNote(Note n) {
    _note = n;
  }

  NoteEditorStore() {
    editorSetNote.listen((note) {
      _note = note;
      _loading = false;
      trigger();
    });

    addAudioFile.listen((f) async {
      _note.audioFiles.add(f);
      _loading = true;
      trigger();

      await LocalStorage().syncNoteAttr(_note, 'audioFiles');

      _loading = false;
      trigger();
    });

    addSection.listen((s) async {
      _note.sections.add(s);
      await LocalStorage().syncNoteAttr(_note, 'sections');
      trigger();
    });

    deleteAudioFile.listen((f) async {
      _loading = true;
      trigger();

      FileManager().delete(f);

      print("Removing: ${_note.audioFiles.remove(f)}");
      await LocalStorage().syncNoteAttr(_note, 'audioFiles');

      _loading = false;
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
      int index = _note.audioFiles.indexOf(f);
      _note.audioFiles[index] = f;

      await LocalStorage().syncNoteAttr(_note, 'audioFiles');
      trigger();
    });

    changeTuning.listen((String x) async {
      _note.tuning = x;
      await LocalStorage().syncNoteAttr(_note, 'tuning');
      trigger();
    });
    changeKey.listen((String x) async {
      _note.key = x;
      await LocalStorage().syncNoteAttr(_note, 'key');
      trigger();
    });
    changeLabel.listen((String x) async {
      _note.label = x;
      await LocalStorage().syncNoteAttr(_note, 'label');
      trigger();
    });
    changeInstrument.listen((String x) async {
      _note.instrument = x;
      await LocalStorage().syncNoteAttr(_note, 'instrument');
      trigger();
    });

    updateNoteEditorView.listen((_) {
      trigger();
    });
  }
}

Action<Note> editorSetNote = Action();
Action<AudioFile> deleteAudioFile = Action();
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
Action<String> changeInstrument = Action();
Action<AudioFile> changeAudioFile = Action();
Action<Tuple2<Section, String>> changeContent = Action();
Action<AudioFile> addAudioFile = Action();
Action<Tuple2<AudioFile, bool>> uploadCallback = Action();
Action updateNoteEditorView = Action();

StoreToken noteEditorStoreToken = StoreToken(NoteEditorStore());
