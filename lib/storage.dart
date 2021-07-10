import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/settings_store.dart';
import 'package:sound/utils.dart';
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

  Filter({this.by, this.content});

  @override
  int get hashCode => (by.index.toString() + content).hashCode;

  bool operator ==(o) => (o is Filter && o.by == by && o.content == content);
}

class StaticStorage extends Store {
  List<Filter> _filters;
  Map<FilterBy, bool> _showMore;
  bool _twoPerRow;

  bool get view => _twoPerRow;

  List<Filter> get filters => _filters;

  List<Note> _selectedNotes;
  List<Note> get selectedNotes => _selectedNotes;

  String _search = "";
  String get search => _search;

  SortBy _sortBy = SortBy.lastModified;
  SortBy get sortBy => _sortBy;

  SortDirection _sortDirection = SortDirection.up;
  SortDirection get sortDirection => _sortDirection;

  bool mustShowMore(FilterBy by) {
    Map<FilterBy, List<Filter>> f = _getFiltersByCategory();
    if (f.keys.contains(by)) {
      return f[by].length > 3;
    } else
      return false;
  }

  bool isSelected(Note note) =>
      _selectedNotes.where((n) => n.id == note.id).toList().length > 0;

  bool isAnyNoteSelected() => _selectedNotes.length > 0;

  bool isAnyNoteStarred() => filteredNotes.any((n) => n.starred);

  bool showMore(FilterBy by) =>
      _showMore.containsKey(by) ? _showMore[by] : false;

  bool isFilterApplied(Filter filter) => _filters.contains(filter);

  StaticStorage() {
    _twoPerRow = false;

    toggleChangeView.listen((_) {
      _twoPerRow = !_twoPerRow;
      if (_twoPerRow) {
        setDefaultNoteListType(NoteListType.double);
      } else {
        setDefaultNoteListType(NoteListType.single);
      }
      trigger();
    });

    setTwoPerRow.listen((value) {
      _twoPerRow = value;
      trigger();
    });

    _filters = [];
    _selectedNotes = [];
    _showMore = Map();

    toggleShowMore.listen((by) {
      if (_showMore.containsKey(by)) {
        _showMore[by] = !_showMore[by];
      } else {
        _showMore[by] = true;
      }
      trigger();
    });

    addNote.listen((note) {
      DB().addNote(note);
      trigger();
    });

    addFilter.listen((f) {
      if (!_filters.contains(f)) {
        _filters.add(f);
        trigger();
      }
    });

    removeFilter.listen((f) {
      _filters.remove(f);
      trigger();
    });
    searchNotes.listen((s) {
      _search = s;
      trigger();
    });

    triggerSelectNote.listen((Note note) {
      if (!isSelected(note)) {
        _selectedNotes.add(note);
        trigger();
      } else {
        _selectedNotes.removeWhere((element) => element.id == note.id);
        trigger();
      }
    });

    resetStaticStorage.listen((_) {
      _search = "";
      _selectedNotes.clear();
      _filters.clear();
      trigger();
    });

    removeAllSelectedNotes.listen((_) {
      for (Note note in _selectedNotes) {
        for (var audio in note.audioFiles) {
          FileManager().delete(audio);
        }

        LocalStorage().deleteNote(note);
      }
      _selectedNotes.clear();
      trigger();
    });

    discardAllSelectedNotes.listen((_) {
      for (Note note in _selectedNotes) {
        LocalStorage().discardNote(note);
      }
      _selectedNotes.clear();
      trigger();
    });

    starAllSelectedNotes.listen((_) {
      for (Note note in _selectedNotes) {
        note.starred = true;
        LocalStorage().syncNoteAttr(note, 'starred');
      }
      _selectedNotes.clear();
      trigger();
    });
    unstarAllSelectedNotes.listen((_) {
      for (Note note in _selectedNotes) {
        note.starred = false;
        LocalStorage().syncNoteAttr(note, 'starred');
      }
      _selectedNotes.clear();
      trigger();
    });

    colorAllSelectedNotes.listen((Color color) {
      for (Note note in _selectedNotes) {
        note.color = color;
        LocalStorage().syncNoteAttr(note, 'color');
      }
      _selectedNotes.clear();
      trigger();
    });

    restoreNotes.listen((_notes) {
      for (Note note in _notes) {
        LocalStorage().restoreNote(note);
      }
      trigger();
    });

    clearSelection.listen((_) {
      _selectedNotes.clear();
      trigger();
    });

    updateView.listen((_) {
      // only update the view, data is stored in file_manager
      trigger();
    });

    changeSortDirection.listen((d) {
      if (this._sortDirection != d) {
        this._sortDirection = d;
        trigger();
      }
    });

    changeSortBy.listen((by) {
      if (_sortBy != by) {
        this._sortBy = by;
        trigger();
      }
    });

    changeListType.listen((event) {
      var twoPerRow = (event == NoteListType.single) ? false : true;
      if (twoPerRow != _twoPerRow) {
        _twoPerRow = twoPerRow;
        trigger();
      }
    });
  }

  bool _isSearchValid(Note note) {
    if (_search != null) {
      var search = _search.toLowerCase();
      if (note.label != null && note.label.toLowerCase().contains(search))
        return true;
      if (note.capo != null &&
          note.capo.toString().toLowerCase().contains(search)) return true;
      if (note.title != null && note.title.toLowerCase().contains(search))
        return true;

      if (note.artist != null && note.artist.toLowerCase().contains(search))
        return true;

      if (note.tuning != null && note.tuning.toLowerCase().contains(search))
        return true;

      if (note.sections.any((s) =>
          s.content.toLowerCase().contains(search) ||
          resolveRichContent(s.content).toLowerCase().contains(search) ||
          s.title.toLowerCase().contains(search))) return true;
    }
    return false;
  }

  Map<FilterBy, List<Filter>> _getFiltersByCategory() {
    Map<FilterBy, List<Filter>> m = Map();
    for (Filter f in _filters) {
      if (m.keys.contains(f.by)) {
        m[f.by].add(f);
      } else {
        m[f.by] = [f];
      }
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

  String getLower(String t) {
    if (t == null)
      return null;
    else
      return t.toLowerCase();
  }

  int _sort(Note a, Note b) {
    if (_sortBy == SortBy.lastModified) {
      if (_sortDirection == SortDirection.up) {
        return b.lastModified.compareTo(a.lastModified);
      } else {
        return a.lastModified.compareTo(b.lastModified);
      }
    } else if (_sortBy == SortBy.created) {
      if (_sortDirection == SortDirection.up) {
        return b.createdAt.compareTo(a.createdAt);
      } else {
        return a.createdAt.compareTo(b.createdAt);
      }
    } else if (_sortBy == SortBy.az) {
      if (_sortDirection == SortDirection.up) {
        return getLower(b.title).compareTo(getLower(a.title));
      } else {
        return getLower(a.title).compareTo(getLower(b.title));
      }
    } else
      return 1;
  }

  List<Note> get filteredNotes {
    List<Note> notes = DB().notes;
    notes.sort(_sort);

    return notes.where((Note note) {
      if (_filters.length == 0 && (_search == null || _search == ""))
        return true;

      if (_search != null && search != "") {
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
}

Action<List<Note>> setNotes = Action();
Action<Note> addNote = Action();
Action<Filter> addFilter = Action();
Action<Filter> removeFilter = Action();

Action<String> searchNotes = Action();
Action<FilterBy> toggleShowMore = Action();
Action toggleChangeView = Action();
Action<bool> setTwoPerRow = Action();
Action openSettings = Action();
//Action<FirebaseUser> setUser = Action();

Action<Note> triggerSelectNote = Action();
Action removeAllSelectedNotes = Action();
Action discardAllSelectedNotes = Action();
Action starAllSelectedNotes = Action();
Action unstarAllSelectedNotes = Action();
Action<Color> colorAllSelectedNotes = Action();

Action<List<Note>> restoreNotes = Action();
Action clearSelection = Action();
Action updateView = Action();
Action resetStaticStorage = Action();
Action<SortBy> changeSortBy = Action();
Action<SortDirection> changeSortDirection = Action();
Action<NoteListType> changeListType = Action();

StoreToken storageToken = StoreToken(StaticStorage());
StoreToken searchNoteStorageToken = StoreToken(StaticStorage());
