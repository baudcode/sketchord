import 'package:flutter/material.dart';
import 'package:sound/dialogs/color_picker_dialog.dart';
import 'package:sound/dialogs/initial_import_dialog.dart';
import 'package:sound/note_views/appbar.dart';
import 'package:sound/note_views/seach.dart';
import 'package:tuple/tuple.dart';
import 'package:provider/provider.dart';
import 'local_storage.dart';
import 'file_manager.dart';
import 'note_list.dart';
import 'storage.dart';
import 'note_editor.dart';
import 'model.dart';
//import 'recorder.dart';
import 'db.dart';

class Home extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const Home(this.onMenuPressed, {super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _initialImportChecked = false;

  @override
  void initState() {
    super.initState();
    _bootstrapHome();
  }

  Future<void> _bootstrapHome() async {
    final notes = await LocalStorage().getNotes();
    if (!mounted) return;

    LocalStorage().controller.sink.add(
          notes.where((e) => !e.discarded).toList(),
        );
    await _showInitialImportIfNeeded();
  }

  Future<void> _showInitialImportIfNeeded() async {
    if (_initialImportChecked) return;
    _initialImportChecked = true;

    final initialStart = await LocalStorage().isInitialStart();
    if (!mounted || !initialStart) return;

    await showInitialImportDialog(context, (_) async {
      await LocalStorage().setInitialStartDone();
    });
  }

  void _floatingButtonPress(BuildContext context) {
    Note note = Note.empty();
    LocalStorage().syncNote(note);

    Navigator.push(
        context, MaterialPageRoute(builder: (context) => NoteEditor(note)));
  }

  @override
  Widget build(BuildContext context) {
    var builder = StreamBuilder<List<Note>>(
      stream: LocalStorage().stream,
      initialData: [],
      builder: (context, snap) {
        print(snap);
        if (snap.hasData) {
          final data = snap.data ?? <Note>[];
          DB().setNotes(data.where((e) => !e.discarded).toList());
          return HomeContent(widget.onMenuPressed);
        } else {
          return CircularProgressIndicator();
        }
      },
    );
    return Scaffold(
        floatingActionButton: FloatingActionButton(
          foregroundColor: Colors.white,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          onPressed: () => _floatingButtonPress(context),
          child: IconButton(
            onPressed: () => _floatingButtonPress(context),
            icon: Icon(Icons.add),
          ),
        ),
        //bottomSheet: RecorderBottomSheet(),
        body: builder);
  }
}

class HomeContent extends StatefulWidget {
  final VoidCallback onMenuPressed;
  HomeContent(this.onMenuPressed);

  @override
  State<StatefulWidget> createState() {
    return HomeContentState();
  }
}

class HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late StaticStorage storage;
  // settings store, use view and set recording format

  bool isSearching = false;
  bool filtersEnabled = false;

  bool get isFiltering => storage.filters.length > 0;

  @override
  Widget build(BuildContext context) {
    storage = context.watch<StaticStorage>();
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
    _controller = TextEditingController();
    // init filemanager
    FileManager();
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

  _toggleIsSearching({searching}) {
    if (searching == null) {
      searching = !isSearching;
    }
    setState(() {
      isSearching = searching;
    });
  }

  _clearSearch() {
    _controller.clear();
    searchNotes("");
    FocusScope.of(context).requestFocus(new FocusNode());
    _toggleIsSearching();
  }

  _listActionButtons() {
    return [
      IconButton(
        icon: Icon(storage.view ? Icons.filter_2 : Icons.filter_1),
        onPressed: () {
          toggleChangeView();
        },
      ),
    ];
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

  _sliverNoteSelectionAppBar() {
    print((storage.selectedNotes
            .map((e) => e.starred)
            .toList()
            .length
            .toDouble() /
        storage.selectedNotes.length.toDouble()));

    return SliverAppBar(
      pinned: true,
      leading: IconButton(
          icon: Icon(Icons.clear), onPressed: () => clearSelection()),
      title: Text(storage.selectedNotes.length.toString()),
      actions: <Widget>[
        IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => discardAllSelectedNotes()),
        IconButton(
            icon: Icon(Icons.color_lens),
            onPressed: () {
              showColorPickerDialog(context, null, (c) {
                colorAllSelectedNotes(c);
              });
            }),
        IconButton(
            icon: Icon((storage.selectedNotes
                            .where((e) => e.starred)
                            .toList()
                            .length
                            .toDouble() /
                        storage.selectedNotes.length.toDouble()) <
                    0.5
                ? Icons.star
                : Icons.star_border),
            onPressed: () {
              if ((storage.selectedNotes
                          .where((e) => e.starred)
                          .toList()
                          .length
                          .toDouble() /
                      storage.selectedNotes.length.toDouble()) <
                  0.5) {
                starAllSelectedNotes();
              } else {
                unstarAllSelectedNotes();
              }
            }),
      ],
    );
  }

  _sliverAppBar() {
    return SliverAppBar(
      titleSpacing: 5.0,
      actions: isSearching ? _searchActionButtons() : _listActionButtons(),
      flexibleSpace: (filtersEnabled && isSearching)
          ? _filtersView()
          : (isFiltering ? _activeFiltersView() : Container()),
      leading: isSearching
          ? IconButton(
              icon: Icon(Icons.arrow_back), onPressed: () => _clearSearch())
          : IconButton(icon: Icon(Icons.menu), onPressed: widget.onMenuPressed),
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
      if (storage.isAnyNoteSelected()) {
        triggerSelectNote(note);
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => NoteEditor(note)));
      }
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
                Text("Starred", style: Theme.of(context).textTheme.bodySmall),
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
              child: Text("Other", style: Theme.of(context).textTheme.bodySmall))
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
        toggleIsSearching: _toggleIsSearching,
        onChanged: searchNotes,
        controller: _controller);
  }
}
