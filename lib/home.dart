import 'package:flutter/material.dart';
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

class Home extends StatelessWidget {
  final Function onMenuPressed;

  Home(this.onMenuPressed);

  _floatingButtonPress(BuildContext context) {
    Note note = Note.empty();
    LocalStorage().syncNote(note);

    Navigator.push(
        context, new MaterialPageRoute(builder: (context) => NoteEditor(note)));
  }

  @override
  Widget build(BuildContext context) {
    LocalStorage().getNotes().then((value) => LocalStorage()
        .controller
        .sink
        .add(value.where((e) => !e.discarded).toList()));

    var builder = StreamBuilder<List<Note>>(
      stream: LocalStorage().stream,
      initialData: [],
      builder: (context, snap) {
        print(snap);
        if (snap.hasData) {
          DB().setNotes(snap.data.where((e) => !e.discarded).toList());
          return HomeContent(this.onMenuPressed);
        } else {
          return CircularProgressIndicator();
        }
      },
    );
    return Scaffold(
        floatingActionButton: FloatingActionButton(
          foregroundColor: Colors.white,
          backgroundColor: Theme.of(context).accentColor,
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
  final Function onMenuPressed;
  HomeContent(this.onMenuPressed);

  @override
  State<StatefulWidget> createState() {
    return HomeContentState();
  }
}

class HomeContentState extends State<HomeContent>
    with StoreWatcherMixin, SingleTickerProviderStateMixin {
  TextEditingController _controller;
  StaticStorage storage;
  // settings store, use view and set recording format

  bool isSearching;
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
    isSearching = false;
    filtersEnabled = false;
    _controller = TextEditingController();
    storage = listenToStore(storageToken);

    // init filemanager
    FileManager();
  }

  _filterSpecificView(
    String title,
    List<String> data,
    FilterBy by,
  ) {
    if (!storage.showMore(by)) data = data.take(3).toList();
    return Container(
        padding: EdgeInsets.only(bottom: 10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title.toUpperCase(),
                      style: Theme.of(context).appBarTheme.textTheme.caption),
                  (storage.mustShowMore(by))
                      ? GestureDetector(
                          onTap: () => toggleShowMore(by),
                          child: Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Text(
                                  (storage.showMore(by))
                                      ? 'Show Less'
                                      : 'Show More',
                                  style: Theme.of(context)
                                      .textTheme
                                      .caption
                                      .copyWith(
                                          color:
                                              Theme.of(context).accentColor))))
                      : Container(height: 0, width: 0),
                ],
              ),
              Container(
                  height: 50,
                  child: ListView.builder(
                    itemCount: data.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      print(data);
                      Filter filter = Filter(by: by, content: data[index]);
                      bool isFilterApplied = storage.isFilterApplied(filter);

                      Color backgroundColor = (isFilterApplied)
                          ? Theme.of(context).chipTheme.selectedColor
                          : Theme.of(context).chipTheme.backgroundColor;

                      return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: ActionChip(
                              backgroundColor: backgroundColor,
                              label: Text(data[index]),
                              onPressed: () => (isFilterApplied)
                                  ? removeFilter(filter)
                                  : addFilter(filter)));
                    },
                  ))
            ]));
  }

  _activeFiltersView() {
    return Padding(
        padding: EdgeInsets.only(left: 25, top: 70),
        child: Container(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
              Container(
                  height: 50,
                  child: ListView.builder(
                    itemCount: storage.filters.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      Filter filter = storage.filters[index];
                      Color color = Theme.of(context).chipTheme.selectedColor;

                      return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: ActionChip(
                              backgroundColor: color,
                              label: Text(
                                filter.content,
                              ),
                              onPressed: () => removeFilter(filter)));
                    },
                  ))
            ])));
  }

  _filtersView() {
    List<Widget> items = [
      _filterSpecificView("keys", DB().uniqueKeys, FilterBy.KEY),
      _filterSpecificView("capos", DB().uniqueCapos, FilterBy.CAPO),
      _filterSpecificView("tunings", DB().uniqueTunings, FilterBy.TUNING),
      _filterSpecificView("labels", DB().uniqueLabels, FilterBy.LABEL),
    ];

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
          (isSearching && filtersEnabled) ? 360 : (isFiltering ? 100 : 0),
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
            new MaterialPageRoute(builder: (context) => NoteEditor(note)));
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

      noteList = [NoteList(true, storage.view, items, onTap, onLongPress)];
    }

    SliverAppBar appBar = storage.isAnyNoteSelected()
        ? _sliverNoteSelectionAppBar()
        : _sliverAppBar();

    return CustomScrollView(
      slivers: [appBar]..addAll(noteList),
    );
  }

  _searchView() {
    return TextField(
      controller: _controller,
      autofocus: false,
      style: Theme.of(context).appBarTheme.textTheme.subtitle1,
      onTap: () => _toggleIsSearching(searching: true),
      onSubmitted: (s) => _toggleIsSearching(searching: false),
      decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Search...",
          hintStyle: Theme.of(context).appBarTheme.textTheme.subtitle1),
      maxLines: 1,
      minLines: 1,
      onChanged: (s) => searchNotes(s),
    );
  }
}
