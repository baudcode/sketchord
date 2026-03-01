import 'model.dart';

// cache the notes and implement getter for unique sets

class DB {
  static final DB _singleton = new DB._internal();

  List<Note> _notes = [];
  List<Note> get notes => _notes;

  void setNotes(List<Note> l) {
    _notes = l;
  }

  void addNote(Note note) {
    _notes.add(note);
  }

  void removeNote(Note note) {
    _notes.remove(note);
  }

  factory DB() {
    return _singleton;
  }

  DB._internal();

  List<String> get uniqueLabels => _notes
      .map((n) => n.label)
      .whereType<String>()
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();
  List<String> get uniqueCapos => _notes
      .map((n) => n.capo)
      .whereType<String>()
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();

  List<String> get uniqueKeys => _notes
      .map((n) => n.key)
      .whereType<String>()
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();
  List<String> get uniqueTunings => _notes
      .map((n) => n.tuning)
      .whereType<String>()
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();
}
