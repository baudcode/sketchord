import 'package:flutter/material.dart';
import 'package:sound/dialogs/color_picker_dialog.dart';
import 'package:sound/dialogs/initial_import_dialog.dart';
import 'package:sound/note_viewer.dart';
import 'package:sound/note_views/appbar.dart';
import 'package:sound/note_views/seach.dart';
import 'package:tuple/tuple.dart';
import 'local_storage.dart';
import 'file_manager.dart';
import 'note_list.dart';
import 'storage.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'dart:ui';
import 'note_editor.dart';
import 'model.dart';
//import 'recorder.dart';
import 'db.dart';

// search for notes
// have a bottom bar that has a list of all notes to add (as well remove notes from this list of notes to add)
// bottom bar can have round corners
// TODO: Back button always present, but with a simple dialog box asking wheather you actually want to leave or not
// maybe round the dialog boxes at the corners

class NoteSearchViewLoader extends StatelessWidget {
  final NoteCollection collection;
  final ValueChanged<List<Note>> onAddNotes;
  const NoteSearchViewLoader({this.collection, this.onAddNotes, Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var builder = FutureBuilder(
        builder: (context, AsyncSnapshot<List<Note>> snap) {
          if (!snap.hasData)
            return CircularProgressIndicator();
          else {
            // add all notes that are active and note already part of this collection
            DB().setNotes(snap.data.where((element) {
              try {
                collection.notes.firstWhere((n) => n.id == element.id);
                return false;
              } catch (e) {
                return true;
              }
            }).toList());

            return _NoteSearchView(
                collection: collection, onAddNotes: onAddNotes);
          }
        },
        future: LocalStorage().getActiveNotes());
    return Scaffold(body: builder);
  }
}

class _NoteSearchView extends StatefulWidget {
  final NoteCollection collection;
  final ValueChanged<List<Note>> onAddNotes; // function that will be called

  _NoteSearchView({this.collection, this.onAddNotes});

  @override
  State<StatefulWidget> createState() {
    return _NoteSearchViewState();
  }
}

class _NoteSearchViewState extends State<_NoteSearchView>
    with StoreWatcherMixin, SingleTickerProviderStateMixin {
  TextEditingController _controller;
  StaticStorage storage;
  // settings store, use view and set recording format

  bool isSearching = true;
  bool filtersEnabled;

  bool get isFiltering => storage.filters.length > 0;

  @override
  Widget build(BuildContext context) {
    return _sliver();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    filtersEnabled = false;
    _controller = TextEditingController();

    // set notes note belonging already to this collection
    storage = listenToStore(searchNoteStorageToken);
    setTwoPerRow(true);
  }

  _clear() {
    // clears the state of the view
    resetStaticStorage();
  }

  _activeFiltersView() {
    return ActiveFiltersView(
        filters: storage.filters, removeFilter: removeFilter);
  }

  _filtersView() {
    List<Widget> items = [];

    List<Tuple3<List<String>, FilterBy, String>> filterOptions = [
      Tuple3(DB().uniqueKeys, FilterBy.KEY, "keys"),
      Tuple3(DB().uniqueCapos, FilterBy.CAPO, "capos"),
      Tuple3(DB().uniqueTunings, FilterBy.TUNING, "tunings"),
      Tuple3(DB().uniqueLabels, FilterBy.LABEL, "labels"),
    ];

    for (Tuple3<List<String>, FilterBy, String> option in filterOptions) {
      if (option.item1.length >= 0) {
        items.add(FilterOptionsView(
          title: option.item3,
          data: option.item1,
          by: option.item2,
          showMore: storage.showMore(option.item2),
          mustShowMore: storage.mustShowMore(option.item2),
          isFilterApplied: storage.isFilterApplied,
        ));
      }
    }

    return Padding(
        padding: EdgeInsets.only(left: 25, top: 60),
        child: ListView.builder(
          itemBuilder: (context, i) => items[i],
          itemCount: items.length,
        ));
  }

  _searchActionButtons() {
    return [
      IconButton(
          icon: Icon(filtersEnabled ? Icons.arrow_upward : Icons.filter_list),
          onPressed: () {
            setState(() {
              filtersEnabled = !filtersEnabled;
            });
          })
    ];
  }

  _onOk() {
    widget.onAddNotes(storage.selectedNotes);
    _clear();
    Navigator.of(context).pop();
  }

  _sliverNoteSelectionAppBar() {
    return SliverAppBar(
      pinned: true,
      leading: IconButton(
          icon: Icon(Icons.clear), onPressed: () => clearSelection()),
      title: Text(storage.selectedNotes.length.toString()),
      actions: <Widget>[
        IconButton(icon: Icon(Icons.check), onPressed: _onOk),
      ],
    );
  }

  _onBackPressed() {
    Navigator.of(context).pop();
  }

  _sliverAppBar() {
    return SliverAppBar(
      titleSpacing: 5.0,
      actions: _searchActionButtons(),
      flexibleSpace: (filtersEnabled)
          ? _filtersView()
          : (isFiltering ? _activeFiltersView() : Container()),
      leading: IconButton(
          icon: Icon(Icons.arrow_back), onPressed: () => _onBackPressed()),
      title: Padding(
          child: Center(child: _searchView()),
          padding: EdgeInsets.only(left: 5)),
      expandedHeight:
          (isSearching && filtersEnabled) ? 370 : (isFiltering ? 100 : 0),
      floating: false,
      pinned: true,
    );
  }

  _sliver() {
    onTap(Note note) {
      triggerSelectNote(note);
    }

    onLongPress(Note note) {
      triggerSelectNote(note);
    }

    List<Widget> noteList = [];

    if (storage.isAnyNoteStarred()) {
      print("notes are starred");
      List<NoteListItemModel> items = storage.filteredNotes
          .where((n) => !n.starred)
          .map((n) =>
              NoteListItemModel(note: n, isSelected: storage.isSelected(n)))
          .toList();

      List<NoteListItemModel> starrtedItems = storage.filteredNotes
          .where((n) => n.starred)
          .map((n) =>
              NoteListItemModel(note: n, isSelected: storage.isSelected(n)))
          .toList();

      noteList = [
        SliverList(
            delegate: SliverChildListDelegate([
          Padding(
              padding: EdgeInsets.only(left: 16, top: 16),
              child: Row(children: [
                Text("Starred", style: Theme.of(context).textTheme.caption),
                Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.star, size: 16))
              ]))
        ])),
        NoteList(true, storage.view, starrtedItems, onTap, onLongPress,
            highlight: storage.search == "" ? null : storage.search.trim()),
        SliverList(
            delegate: SliverChildListDelegate([
          Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text("Other", style: Theme.of(context).textTheme.caption))
        ])),
        NoteList(true, storage.view, items, onTap, onLongPress,
            highlight: storage.search == "" ? null : storage.search.trim())
      ];
    } else {
      List<NoteListItemModel> items = storage.filteredNotes
          .map((n) =>
              NoteListItemModel(note: n, isSelected: storage.isSelected(n)))
          .toList();

      noteList = [
        NoteList(true, storage.view, items, onTap, onLongPress,
            highlight: storage.search == "" ? null : storage.search)
      ];
    }

    SliverAppBar appBar = storage.isAnyNoteSelected()
        ? _sliverNoteSelectionAppBar()
        : _sliverAppBar();

    return CustomScrollView(
      slivers: [appBar]..addAll(noteList),
    );
  }

  _searchView() {
    return SearchTextView(
        toggleIsSearching: ({searching}) {},
        onChanged: (s) {
          searchNotes(s);
        },
        controller: _controller);
  }
}
