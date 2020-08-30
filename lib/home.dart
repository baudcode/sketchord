import 'package:flutter/material.dart';
import 'package:sound/settings.dart';
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
  _floatingButtonPress(BuildContext context) {
    Note note = Note.empty();
    LocalStorage().syncNote(note);

    Navigator.push(
        context, new MaterialPageRoute(builder: (context) => NoteEditor(note)));
  }

  @override
  Widget build(BuildContext context) {
    //print("user id: ${AuthHandler().user.uid}");

    // fetch initial values

    LocalStorage()
        .getNotes()
        .then((value) => LocalStorage().controller.sink.add(value));

    var builder = StreamBuilder<List<Note>>(
      stream: LocalStorage().stream,
      initialData: [],
      builder: (context, snap) {
        print(snap);
        if (snap.hasData) {
          DB().setNotes(snap.data);
          return HomeContent();
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
  HomeContent();

  @override
  State<StatefulWidget> createState() {
    return HomeContentState();
  }
}

class HomeContentState extends State<HomeContent> with StoreWatcherMixin {
  TextEditingController _controller;
  StaticStorage storage;

  bool isSearching;
  bool isFiltering;
  bool filtersEnabled;

  @override
  Widget build(BuildContext context) {
    return _sliver();
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
                      style: Theme.of(context).textTheme.caption),
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
                      Color color = (isFilterApplied)
                          ? Theme.of(context).indicatorColor
                          : Theme.of(context).disabledColor;
                      return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: ActionChip(
                              backgroundColor: color,
                              label: Text(data[index]),
                              onPressed: () => (isFilterApplied)
                                  ? removeFilter(filter)
                                  : addFilter(filter)));
                    },
                  ))
            ]));
  }

  _filtersView() {
    List<Widget> items = [
      _filterSpecificView("keys", DB().uniqueKeys, FilterBy.KEY),
      _filterSpecificView("capos", DB().uniqueCapos, FilterBy.CAPO),
      _filterSpecificView("tunings", DB().uniqueTunings, FilterBy.TUNING),
      _filterSpecificView("labels", DB().uniqueLabels, FilterBy.LABEL),
    ];

    return ListView.builder(
      itemBuilder: (context, i) => items[i],
      itemCount: items.length,
    );
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
      IconButton(icon: Icon(Icons.settings), onPressed: _openSettings)
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

  _sliverAppBar() {
    return SliverAppBar(
      actions: isSearching ? _searchActionButtons() : _listActionButtons(),
      flexibleSpace: filtersEnabled
          ? Padding(
              padding: EdgeInsets.only(left: 25, top: 60),
              child: _filtersView())
          : Container(),
      leading: isSearching
          ? IconButton(
              icon: Icon(Icons.arrow_back), onPressed: () => _clearSearch())
          : null,
      title: Padding(
          child: Center(child: _searchView()),
          padding: EdgeInsets.only(left: 10)),
      expandedHeight: (isSearching && filtersEnabled) ? 360 : 0,
      floating: false,
      pinned: true,
    );
  }

  _sliverNoteSelectionAppBar() {
    return SliverAppBar(
      leading: IconButton(
          icon: Icon(Icons.clear), onPressed: () => clearSelection()),
      actions: <Widget>[
        IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => removeAllSelectedNotes()),
      ],
    );
  }

  _openSettings() {
    Navigator.push(
        context, new MaterialPageRoute(builder: (context) => Settings()));
  }

  _sliver() {
    return CustomScrollView(
      slivers: <Widget>[
        (storage.isAnyNoteSelected()
            ? _sliverNoteSelectionAppBar()
            : _sliverAppBar()),
        NoteList(true)
      ],
    );
  }

  _searchView() {
    return TextField(
      controller: _controller,
      autofocus: false,
      onTap: () => _toggleIsSearching(searching: true),
      onSubmitted: (s) => _toggleIsSearching(searching: false),
      decoration:
          InputDecoration(border: InputBorder.none, hintText: "Search..."),
      maxLines: 1,
      minLines: 1,
      onChanged: (s) => searchNotes(s),
    );
  }
}
