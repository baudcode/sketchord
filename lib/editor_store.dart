import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:tuple/tuple.dart';

import 'file_manager.dart';
import 'local_storage.dart';
import 'model.dart';

class NoteEditorStore extends ChangeNotifier {
  Note? _note;
  Note? get note => _note;

  Tuple2<int, Section>? _lastDeletion;

  void setNote(Note n) {
    _note = n;
    notifyListeners();
  }

  Future<void> addAudioFile(AudioFile f) async {
    if (_note == null) return;
    _note!.audioFiles.add(f);
    await LocalStorage().syncNoteAttr(_note!, 'audioFiles');
    notifyListeners();
  }

  Future<void> addSection(Section s) async {
    if (_note == null) return;
    _note!.sections.add(s);
    await LocalStorage().syncNoteAttr(_note!, 'sections');
    notifyListeners();
  }

  Future<void> hardDeleteAudioFile(AudioFile f) async {
    if (_note == null) return;
    FileManager().delete(f);
    _note!.audioFiles.remove(f);
    await LocalStorage().syncNoteAttr(_note!, 'audioFiles');
    notifyListeners();
  }

  void softDeleteAudioFile(AudioFile f) {
    if (_note == null) return;
    _note!.audioFiles.remove(f);
    notifyListeners();
  }

  Future<void> deleteSection(Section s) async {
    if (_note == null) return;
    final index = _note!.sections.indexOf(s);
    if (index < 0) return;
    _note!.sections.removeAt(index);
    _lastDeletion = Tuple2(index, s);
    await LocalStorage().syncNoteAttr(_note!, 'sections');
    notifyListeners();
  }

  Future<void> undoDeleteSection([dynamic _]) async {
    if (_note == null || _lastDeletion == null) return;
    _note!.sections.insert(_lastDeletion!.item1, _lastDeletion!.item2);
    await LocalStorage().syncNoteAttr(_note!, 'sections');
    notifyListeners();
  }

  Future<void> moveSectionUp(Section s) async {
    if (_note == null) return;
    final index = _note!.sections.indexOf(s);
    if (index < 1) return;
    _note!.sections.removeAt(index);
    _note!.sections.insert(index - 1, s);
    await LocalStorage().syncNoteAttr(_note!, 'sections');
    notifyListeners();
  }

  Future<void> moveSectionDown(Section s) async {
    if (_note == null) return;
    final index = _note!.sections.indexOf(s);
    if (index < 0 || index == _note!.sections.length - 1) return;
    _note!.sections.removeAt(index);
    _note!.sections.insert(index + 1, s);
    await LocalStorage().syncNoteAttr(_note!, 'sections');
    notifyListeners();
  }

  Future<void> changeSectionTitle(Tuple2<Section, String> t) async {
    if (_note == null) return;
    final index = _note!.sections.indexOf(t.item1);
    if (index < 0) return;
    _note!.sections[index].title = t.item2;
    await LocalStorage().syncNoteAttr(_note!, 'sections');
    notifyListeners();
  }

  Future<void> changeTitle(String t) async {
    if (_note == null) return;
    _note!.title = t;
    await LocalStorage().syncNoteAttr(_note!, 'title');
    notifyListeners();
  }

  Future<void> changeContent(Tuple2<Section, String> t) async {
    if (_note == null) return;
    final index = _note!.sections.indexOf(t.item1);
    if (index < 0) return;
    _note!.sections[index].content = t.item2;
    await LocalStorage().syncNoteAttr(_note!, 'sections');
    notifyListeners();
  }

  Future<void> changeCapo(String x) async {
    if (_note == null) return;
    _note!.capo = x;
    await LocalStorage().syncNoteAttr(_note!, 'capo');
    notifyListeners();
  }

  Future<void> changeAudioFile(AudioFile f) async {
    if (_note == null) return;
    final index = _note!.audioFiles.indexWhere((a) => a.id == f.id);
    if (index == -1) return;
    _note!.audioFiles[index] = f;
    await LocalStorage().syncNoteAttr(_note!, 'audioFiles');
    notifyListeners();
  }

  Future<void> changeTuning(String x) async {
    if (_note == null || x.trim().isEmpty) return;
    _note!.tuning = x;
    await LocalStorage().syncNoteAttr(_note!, 'tuning');
    notifyListeners();
  }

  Future<void> changeKey(String x) async {
    if (_note == null || x.trim().isEmpty) return;
    _note!.key = x;
    await LocalStorage().syncNoteAttr(_note!, 'key');
    notifyListeners();
  }

  Future<void> changeLabel(String x) async {
    if (_note == null || x.trim().isEmpty) return;
    _note!.label = x;
    await LocalStorage().syncNoteAttr(_note!, 'label');
    notifyListeners();
  }

  Future<void> changeArtist(String x) async {
    if (_note == null || x.trim().isEmpty) return;
    _note!.artist = x;
    await LocalStorage().syncNoteAttr(_note!, 'artist');
    notifyListeners();
  }

  Future<void> changeInstrument(String x) async {
    if (_note == null || x.trim().isEmpty) return;
    _note!.instrument = x;
    await LocalStorage().syncNoteAttr(_note!, 'instrument');
    notifyListeners();
  }

  void updateNoteEditorView([dynamic _]) {
    notifyListeners();
  }

  Future<void> restoreAudioFile(Tuple2<AudioFile, int> a) async {
    if (_note == null) return;
    _note!.audioFiles.insert(a.item2, a.item1);
    await LocalStorage().syncNoteAttr(_note!, 'audioFiles');
    notifyListeners();
  }

  Future<void> toggleStarred([dynamic _]) async {
    if (_note == null) return;
    _note!.starred = !_note!.starred;
    await LocalStorage().syncNoteAttr(_note!, 'starred');
    notifyListeners();
  }

  Future<void> changeColor(Color event) async {
    if (_note == null) return;
    _note!.color = event;
    await LocalStorage().syncNoteAttr(_note!, 'color');
    notifyListeners();
  }

  Future<void> setDuration(Tuple2<AudioFile, Duration> a) async {
    if (_note == null) return;
    for (final f in _note!.audioFiles) {
      if (f.id == a.item1.id) {
        f.duration = a.item2;
      }
    }
    await LocalStorage().syncNoteAttr(_note!, 'audioFiles');
    notifyListeners();
  }
}

final NoteEditorStore noteEditorStore = NoteEditorStore();

void editorSetNote(Note note) => noteEditorStore.setNote(note);
void softDeleteAudioFile(AudioFile file) => noteEditorStore.softDeleteAudioFile(file);
Future<void> hardDeleteAudioFile(AudioFile file) => noteEditorStore.hardDeleteAudioFile(file);
Future<void> deleteSection(Section section) => noteEditorStore.deleteSection(section);
Future<void> undoDeleteSection([dynamic _]) => noteEditorStore.undoDeleteSection();
Future<void> addSection(Section section) => noteEditorStore.addSection(section);
Future<void> moveSectionUp(Section section) => noteEditorStore.moveSectionUp(section);
Future<void> moveSectionDown(Section section) => noteEditorStore.moveSectionDown(section);
Future<void> changeSectionTitle(Tuple2<Section, String> value) =>
    noteEditorStore.changeSectionTitle(value);
Future<void> changeTitle(String value) => noteEditorStore.changeTitle(value);
Future<void> changeCapo(String value) => noteEditorStore.changeCapo(value);
Future<void> changeTuning(String value) => noteEditorStore.changeTuning(value);
Future<void> changeKey(String value) => noteEditorStore.changeKey(value);
Future<void> changeLabel(String value) => noteEditorStore.changeLabel(value);
Future<void> changeArtist(String value) => noteEditorStore.changeArtist(value);
Future<void> changeInstrument(String value) => noteEditorStore.changeInstrument(value);
Future<void> changeAudioFile(AudioFile value) => noteEditorStore.changeAudioFile(value);
Future<void> changeContent(Tuple2<Section, String> value) =>
    noteEditorStore.changeContent(value);
Future<void> addAudioFile(AudioFile file) => noteEditorStore.addAudioFile(file);
Future<void> restoreAudioFile(Tuple2<AudioFile, int> value) =>
    noteEditorStore.restoreAudioFile(value);
void uploadCallback(Tuple2<AudioFile, bool> value) {}
void updateNoteEditorView([dynamic _]) => noteEditorStore.updateNoteEditorView();
Future<void> toggleStarred([dynamic _]) => noteEditorStore.toggleStarred();
Future<void> changeColor(Color value) => noteEditorStore.changeColor(value);
Future<void> setDuration(Tuple2<AudioFile, Duration> value) =>
    noteEditorStore.setDuration(value);
