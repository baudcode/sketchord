import 'package:flutter/foundation.dart';
import 'local_storage.dart';
import 'file_manager.dart';
import 'model.dart';
import 'db.dart';
import 'package:flutter/material.dart' show Color;

List<Note> notes = [
  Note(
      title: "Why am I, why am I the way I am",
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      key: "C Major",
      tuning: "Dadgad",
      label: "Song",
      starred: true,
      audioFiles: [
        AudioFile.create(
            duration: Duration(seconds: 5),
            path: "/data/sdcard/files/test_file.mp4")
      ],
      sections: [
        Section(
            title: 'Verse 1',
            content:
                "The world comes crashing down\nand you are the only one\nWho helps me though the dark/past\nSo Drunk and fallen apart"),
        Section(
            title: "Chorus",
            content: "Why am I, why am I the way I am I don't understand"),
        Section(
            title: "Bridge",
            content:
                "Lately, I dont like myself\nI cant even look myself in the eye\nSo shockingly evil and vile")
      ]),
  Note(
      title: "Time",
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      key: "B Dur",
      tuning: "Standard",
      label: "Song",
      starred: false,
      audioFiles: [],
      sections: [
        Section(
            title: 'Verse 1',
            content:
                """        EM                                         Em.    D C C C 
Time has gone and young love passed
     G.        D.             C C C c
A blurry dot in the dark
Its difficult to go back to what once was
A flame sparks again
To take me back to when
"""),
        Section(
            title: "Chorus", content: "When we were young and full of love"),
        Section(title: "Verse 2", content: """
                Em                   Em                D     C      C   C
Its been some time, since we talked
         G    G         D       C         
when was our last walk?
Em                              G                        D    D        
oh what makes us happy and what not?
Em              D       G
please ask me again
    em           G             D      D
or take me back to when
                """),
        Section(title: "Bridge", content: """Em Em D/F# D/F# C D D D D  
Em Em D/F# D/F# C D D D D 
Em C Em G 
G G""")
      ]),
  Note(
      title: "Sleep",
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      key: "C Dur",
      capo: "7",
      tuning: "Standard",
      label: "Song",
      starred: false,
      audioFiles: [],
      sections: [
        Section(
            title: 'Verse 1',
            content:
                """   G G            D/B  D/B      C         D           G   G  G
I'm 25 and I don't know what I want in live
My girlfriend and I we're moving along the lines
We're havin jobs that pay nice, they make us feel alright
But if I am honstest, is this leading to a better life?"""),
        Section(
            title: "Chorus",
            content: """I think that I just want to sleep alright
And wake up without a gun to my mind
Mmmmmhh"""),
        Section(
            title: "Verse 2",
            content: """times' changing, its better to live alone
without someone looking under every stone
the next thing you remember is having children on your own
rolling around and looking under every stone"""),
        Section(title: "Bridge", content: """""")
      ]),
];

enum FilterBy { LABEL, TUNING, KEY, CAPO }

class Filter {
  FilterBy by;
  String content;

  Filter({required this.by, required this.content});

  @override
  int get hashCode => (by.index.toString() + content).hashCode;

  bool operator ==(o) => (o is Filter && o.by == by && o.content == content);
}

class StaticStorage extends ChangeNotifier {
  List<Filter> _filters = [];
  Map<FilterBy, bool> _showMore = {};
  bool _twoPerRow = false;

  bool get view => _twoPerRow;

  List<Filter> get filters => _filters;

  List<Note> _selectedNotes = [];
  List<Note> get selectedNotes => _selectedNotes;

  String _search = "";
  String get search => _search;

  bool mustShowMore(FilterBy by) {
    Map<FilterBy, List<Filter>> f = _getFiltersByCategory();
    if (f.keys.contains(by)) {
      return (f[by]?.length ?? 0) > 3;
    } else
      return false;
  }

  bool isSelected(Note note) => _selectedNotes.contains(note);

  bool isAnyNoteSelected() => _selectedNotes.length > 0;

  bool isAnyNoteStarred() => filteredNotes.any((n) => n.starred);

  bool showMore(FilterBy by) =>
      _showMore.containsKey(by) ? (_showMore[by] ?? false) : false;

  bool isFilterApplied(Filter filter) => _filters.contains(filter);

  StaticStorage() {
    _twoPerRow = false;
  }

  void toggleChangeView() {
    _twoPerRow = !_twoPerRow;
    notifyListeners();
  }

  void toggleShowMore(FilterBy by) {
    _showMore[by] = !(_showMore[by] ?? false);
    notifyListeners();
  }

  void addNote(Note note) {
    DB().addNote(note);
    notifyListeners();
  }

  void addFilter(Filter f) {
    if (_filters.contains(f)) return;
    _filters.add(f);
    notifyListeners();
  }

  void removeFilter(Filter f) {
    _filters.remove(f);
    notifyListeners();
  }

  void searchNotes(String s) {
    _search = s;
    notifyListeners();
  }

  void triggerSelectNote(Note note) {
    if (_selectedNotes.contains(note)) {
      _selectedNotes.remove(note);
    } else {
      _selectedNotes.add(note);
    }
    notifyListeners();
  }

  Future<void> removeAllSelectedNotes() async {
    for (final note in _selectedNotes) {
      for (final audio in note.audioFiles) {
        FileManager().delete(audio);
      }
      await LocalStorage().deleteNote(note);
    }
    _selectedNotes.clear();
    notifyListeners();
  }

  Future<void> discardAllSelectedNotes() async {
    for (final note in _selectedNotes) {
      await LocalStorage().discardNote(note);
    }
    _selectedNotes.clear();
    notifyListeners();
  }

  Future<void> starAllSelectedNotes() async {
    for (final note in _selectedNotes) {
      note.starred = true;
      await LocalStorage().syncNoteAttr(note, 'starred');
    }
    _selectedNotes.clear();
    notifyListeners();
  }

  Future<void> unstarAllSelectedNotes() async {
    for (final note in _selectedNotes) {
      note.starred = false;
      await LocalStorage().syncNoteAttr(note, 'starred');
    }
    _selectedNotes.clear();
    notifyListeners();
  }

  Future<void> colorAllSelectedNotes(Color color) async {
    for (final note in _selectedNotes) {
      note.color = color;
      await LocalStorage().syncNoteAttr(note, 'color');
    }
    _selectedNotes.clear();
    notifyListeners();
  }

  Future<void> restoreNotes(List<Note> notes) async {
    for (final note in notes) {
      await LocalStorage().restoreNote(note);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedNotes.clear();
    notifyListeners();
  }

  void updateView() {
    notifyListeners();
  }

  bool _isSearchValid(Note note) {
    var search = _search.toLowerCase();
    if ((note.label ?? '').toLowerCase().contains(search))
      return true;
    if (note.capo.toString().toLowerCase().contains(search)) return true;
    if ((note.title).toLowerCase().contains(search))
      return true;

    if ((note.artist ?? '').toLowerCase().contains(search))
      return true;

    if ((note.tuning ?? '').toLowerCase().contains(search))
      return true;
    if (note.sections.any((s) =>
        s.content.toLowerCase().contains(search) ||
        s.title.toLowerCase().contains(search))) return true;
      return false;
  }

  Map<FilterBy, List<Filter>> _getFiltersByCategory() {
    final m = <FilterBy, List<Filter>>{};
    for (Filter f in _filters) {
      m.putIfAbsent(f.by, () => []).add(f);
    }
    return m;
  }

  bool _isFilterValid(Filter filter, Note note) {
    if (filter.by == FilterBy.CAPO) {
      if (note.capo.toString() == filter.content) return true;
    } else if (filter.by == FilterBy.KEY) {
      if (note.key == filter.content) return true;
    } else if (filter.by == FilterBy.TUNING) {
      if (note.tuning == filter.content) return true;
    } else if (filter.by == FilterBy.LABEL) {
      if (note.label == filter.content) return true;
    }
    return false;
  }

  bool _isAnyFilterValid(Note note) {
    Map<FilterBy, List<Filter>> m = _getFiltersByCategory();
    for (List<Filter> l in m.values) {
      if (!l.any((f) => _isFilterValid(f, note))) {
        return false;
      }
    }
    return true;
  }

  List<Note> get filteredNotes => DB().notes.where((Note note) {
        if (_filters.length == 0 && (_search == ""))
          return true;

        if (search != "") {
          if (_filters.length == 0) {
            return _isSearchValid(note);
          } else {
            return _isSearchValid(note) && _isAnyFilterValid(note);
          }
        } else {
          return _isAnyFilterValid(note);
        }
      }).toList();
}

final StaticStorage storageStore = StaticStorage();

void setNotes(List<Note> notes) => DB().setNotes(notes);
void addNote(Note note) => storageStore.addNote(note);
void addFilter(Filter filter) => storageStore.addFilter(filter);
void removeFilter(Filter filter) => storageStore.removeFilter(filter);
void searchNotes(String search) => storageStore.searchNotes(search);
void toggleShowMore(FilterBy by) => storageStore.toggleShowMore(by);
void toggleChangeView([dynamic _]) => storageStore.toggleChangeView();
void openSettings([dynamic _]) {}
void triggerSelectNote(Note note) => storageStore.triggerSelectNote(note);
Future<void> removeAllSelectedNotes([dynamic _]) =>
    storageStore.removeAllSelectedNotes();
Future<void> discardAllSelectedNotes([dynamic _]) =>
    storageStore.discardAllSelectedNotes();
Future<void> starAllSelectedNotes([dynamic _]) =>
    storageStore.starAllSelectedNotes();
Future<void> unstarAllSelectedNotes([dynamic _]) =>
    storageStore.unstarAllSelectedNotes();
Future<void> colorAllSelectedNotes(Color color) =>
    storageStore.colorAllSelectedNotes(color);
Future<void> restoreNotes(List<Note> notes) => storageStore.restoreNotes(notes);
void clearSelection([dynamic _]) => storageStore.clearSelection();
void updateView([dynamic _]) => storageStore.updateView();
