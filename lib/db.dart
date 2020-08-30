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
      .where((n) => n.label != null && n.label != "")
      .map<String>((n) => n.label)
      .toSet()
      .toList();
  List<String> get uniqueCapos => _notes
      .where((n) => n.capo != null && n.capo != "")
      .map<String>((n) => n.capo.toString())
      .toSet()
      .toList();

  List<String> get uniqueKeys => _notes
      .where((n) => n.key != null && n.key != "")
      .map<String>((n) => n.key)
      .toSet()
      .toList();
  List<String> get uniqueTunings => _notes
      .where((n) => n.tuning != null && n.tuning != "")
      .map<String>((n) => n.tuning)
      .toSet()
      .toList();
}
