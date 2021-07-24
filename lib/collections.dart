import 'package:flutter/material.dart';
import 'package:flutter_flux/flutter_flux.dart';
import 'package:sound/collection_editor_store.dart';
import 'package:sound/db.dart';
import 'package:sound/dialogs/choose_note_dialog.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/collections_store.dart';
import 'package:sound/note_search_view.dart';
import 'package:sound/note_viewer.dart';
import 'package:sound/utils.dart';

class NoteCollectionItemModel {
  final NoteCollection collection;
  final bool isSelected;

  const NoteCollectionItemModel({this.collection, this.isSelected});
}

class NoteCollectionList extends StatelessWidget {
  final bool singleView;
  final ValueChanged<NoteCollection> onTap;
  final ValueChanged<NoteCollection> onLongPress;
  final List<NoteCollectionItemModel> items;

  NoteCollectionList(this.items, this.onTap, this.onLongPress,
      {this.singleView = true});

  List<NoteCollectionItemModel> processList(
      List<NoteCollectionItemModel> data, bool even) {
    List<NoteCollectionItemModel> returns = [];

    for (int i = 0; i < data.length; i++) {
      if (even && i % 2 == 0) returns.add(data[i]);
      if (!even && i % 2 != 0) returns.add(data[i]);
    }
    return returns;
  }

  _getItem(double width, int index, {double padding = 8}) {
    if (!singleView) {
      return Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Flexible(
                    flex: 1,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            direction: Axis.vertical,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            children: processList(items, true)
                                .map((i) => SmallNoteCollectionItem(
                                    i.collection,
                                    i.isSelected,
                                    () => onTap(i.collection),
                                    () => onLongPress(i.collection),
                                    width / 2 - padding,
                                    EdgeInsets.only(left: 0)))
                                .toList(),
                          )
                        ])),
                Flexible(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                      Wrap(
                        direction: Axis.vertical,
                        alignment: WrapAlignment.spaceEvenly,
                        children: processList(items, false)
                            .map((i) => SmallNoteCollectionItem(
                                i.collection,
                                i.isSelected,
                                () => onTap(i.collection),
                                () => onLongPress(i.collection),
                                width / 2 - padding,
                                EdgeInsets.only(left: 0)))
                            .toList(),
                      )
                    ]))
              ]));
    } else {
      var item = items[index];

      return Padding(
          padding: EdgeInsets.only(
              left: 0,
              right: 0,
              top: index == 0 ? padding : 0,
              bottom: index == items.length - 1 ? padding : 0),
          child: NoteCollectionItem(item.collection, item.isSelected,
              () => onTap(item.collection), () => onLongPress(item.collection),
              padding: 0));
    }
  }

  _body(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    int childCount = (singleView) ? items.length : 1;

    return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
      return _getItem(width, index);
    }, childCount: childCount));
  }

  @override
  Widget build(BuildContext context) {
    return _body(context);
  }
}

class NoteCollectionItem extends StatelessWidget {
  final NoteCollection collection;
  final bool isSelected;
  final Function onTap, onLongPress;
  final double padding;

  const NoteCollectionItem(
      this.collection, this.isSelected, this.onTap, this.onLongPress,
      {this.padding = 0, Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(padding),
        child: ListTile(
          onTap: onTap,
          onLongPress: onLongPress,
          title: Text(
              this.collection.title == "" ? "EMPTY" : this.collection.title),
          trailing: Text(this.collection.activeNotes.length.toString()),
          tileColor: isSelected ? getSelectedCardColor(context) : null,
          subtitle: this.collection.description == null ||
                  this.collection.description == ""
              ? Text("-")
              : (Text(this.collection.description)),
        ));
  }
}

class SmallNoteCollectionItem extends StatelessWidget {
  final NoteCollection collection;
  final bool isSelected;
  final EdgeInsets padding;
  final Function onTap, onLongPress;
  final double width;

  const SmallNoteCollectionItem(this.collection, this.isSelected, this.onTap,
      this.onLongPress, this.width, this.padding,
      {Key key})
      : super(key: key);

  bool get empty => ((collection.title == null ||
          collection.title.trim() == "") &&
      (collection.description == null || collection.description.trim() == "") &&
      collection.notes.length == 0);

  @override
  Widget build(BuildContext context) {
    Widget child = Card(
        color: null,
        child: Container(
            decoration: isSelected
                ? getSelectedDecoration(context)
                : getNormalDecoration(context),
            child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(collection.title)),
                      Padding(
                          child: Text(
                            collection.notes.length.toString(),
                            textScaleFactor: 2.0,
                          ),
                          padding: EdgeInsets.only(top: 16))
                    ]))));
    List<Widget> stackChildren = [];
    stackChildren.add(child);

    return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
            width: this.width,
            height: (empty) ? 50 : null,
            padding: this.padding,
            child: Stack(children: stackChildren)));
  }
}

class CollectionEditor extends StatefulWidget {
  final NoteCollection collection;
  final bool allowEdit;

  const CollectionEditor(this.collection, {this.allowEdit = true, Key key})
      : super(key: key);

  @override
  _CollectionEditorState createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<CollectionEditor>
    with StoreWatcherMixin<CollectionEditor> {
  CollectionEditorStore store;
  Map<Note, GlobalKey> dismissables = {};

  @override
  void initState() {
    super.initState();
    store = listenToStore(collectionEditorStoreToken);
    store.setCollection(widget.collection);
  }

  _edit({initial, title, hint, onChanged, maxlines = 1}) {
    return TextFormField(
        initialValue: initial,
        decoration: InputDecoration(
            labelText: title, border: InputBorder.none, hintText: hint),
        enabled: widget.allowEdit,
        onChanged: (v) => onChanged(v),
        maxLines: maxlines);
  }

  floatingActionButtonPressed() async {
    // add a note to this collection
    Navigator.push(
        context,
        new MaterialPageRoute(
            builder: (context) => NoteSearchViewLoader(
                  collection: store.collection,
                  onAddNotes: (List<Note> notes) {
                    addNotesToCollection(notes);
                  },
                )));

    // showAddNotesDialog(
    //     context: context,
    //     notes: notes,
    //     preselected: store.collection.notes,
    //     onImport: (notes) async {
    //       setNotesOfCollection(notes);
    //     });
  }

  _onPlay() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
      return NoteCollectionViewer(store.collection);
    }));
  }

  @override
  Widget build(BuildContext context) {
    var notes = [];
    var activeNotes = store.collection.activeNotes;

    for (var i = 0; i < activeNotes.length; i++) {
      if (!dismissables.containsKey(activeNotes[i]))
        dismissables[activeNotes[i]] = GlobalKey();

      bool showMoveUp = (i != 0);
      bool showMoveDown = (i != (activeNotes.length - 1));
      notes.add(CollecitonNoteListItem(
          idx: i + 1,
          globalKey: dismissables[activeNotes[i]],
          note: activeNotes[i],
          moveDown: showMoveDown,
          moveUp: showMoveUp));
    }

    var titleEdit = Padding(
        padding: EdgeInsets.only(left: 10, top: 10),
        child: Wrap(runSpacing: 1, children: [
          _edit(
              initial: store.collection.title,
              title: "Title",
              hint: "Title...",
              onChanged: changeCollectionTitle),
          _edit(
              initial: store.collection.description,
              title: "Description",
              hint: "Description...",
              onChanged: changeCollectionDescription,
              maxlines: 1),
          Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Row(children: [
                Text("Notes", style: Theme.of(context).textTheme.caption)
              ])),
          ...notes
        ]));

    List<Widget> items = [
      titleEdit,
    ];

    List<Widget> stackChildren = [];

    stackChildren.add(Container(
        padding: EdgeInsets.all(16),
        child: ListView.builder(
          itemBuilder: (context, index) => items[index],
          itemCount: items.length,
        )));

    List<Widget> actions = [
      IconButton(icon: Icon(Icons.play_circle), onPressed: _onPlay),
      IconButton(
          icon:
              Icon((store.collection.starred) ? Icons.star : Icons.star_border),
          onPressed: toggleCollectionStarred),
    ];

    return WillPopScope(
        onWillPop: () async {
          if (store.collection.empty) {
            print("delete collection");
            LocalStorage().deleteCollection(store.collection);
          } else {
            print("sync collection");
            LocalStorage().syncCollection(store.collection);
          }
          return true;
        },
        child: ScaffoldMessenger(
          child: Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: floatingActionButtonPressed,
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).accentColor,
                child: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: floatingActionButtonPressed,
                ),
              ),
              appBar: AppBar(
                //backgroundColor: store.note.color,
                actions: actions,
                title: Text("Edit Set"),
              ),
              body: Container(child: Stack(children: stackChildren))),
        ));
  }
}

class AroundText extends StatelessWidget {
  final String text;
  final double radius;
  final BoxShape shape;
  const AroundText(
      {this.text, this.radius = 30, this.shape = BoxShape.rectangle, Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color background = Theme.of(context).appBarTheme.backgroundColor;
    background = Theme.of(context).accentColor;
    return Container(
      width: this.radius,
      height: this.radius,
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: background),
        shape: BoxShape.rectangle,
        // You can use like this way or like the below line
        //borderRadius: new BorderRadius.circular(30.0),
        //color: Theme.of(context).appBarTheme.backgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(this.text),
        ],
      ),
    );
  }
}

class CollecitonNoteListItem extends StatelessWidget {
  // Section section, bool moveDown, bool moveUp, GlobalKey globalKey) {
  final Note note;
  final int idx;
  final bool moveDown, moveUp;
  final GlobalKey globalKey;

  const CollecitonNoteListItem(
      {this.note,
      this.idx,
      this.moveUp,
      this.moveDown,
      this.globalKey,
      Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> trailingWidgets = [];
    if (moveDown)
      trailingWidgets.add(IconButton(
          icon: Icon(Icons.arrow_drop_down),
          onPressed: () => moveNoteDown(note)));

    if (moveUp)
      trailingWidgets.add(IconButton(
        icon: Icon(Icons.arrow_drop_up),
        onPressed: () => moveNoteUp(note),
      ));

    Widget trailing = Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: trailingWidgets);

    Card card = Card(
        child: Container(
            padding: EdgeInsets.zero,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                    padding: EdgeInsets.only(left: 10, top: 10),
                    child: AroundText(text: idx.toString())),
                Expanded(
                    child: Container(
                        padding: EdgeInsets.all(15),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  note.hasEmptyTitle
                                      ? EMPTY_TEXT.toUpperCase()
                                      : note.title,
                                  style: Theme.of(context).textTheme.subtitle1),
                            ]))),
                trailing
              ],
            )));

    return Dismissible(
      child: card,
      onDismissed: (d) {
        removeNoteFromCollection(note);

        showUndoSnackbar(
            context: context,
            dataString: note.hasEmptyTitle ? "Note" : note.title,
            data: note,
            onUndo: (_) {
              undoRemoveNoteFromCollection(note);
            });
      },
      direction: DismissDirection.startToEnd,
      key: globalKey,
      background: Card(
          child: Container(
              color: Theme.of(context).accentColor,
              child: Row(children: <Widget>[Icon(Icons.delete)]),
              padding: EdgeInsets.all(8))),
    );
  }
}

class Collections extends StatelessWidget {
  final Function onMenuPressed;

  Collections(this.onMenuPressed);

  _floatingButtonPress(BuildContext context) {
    NoteCollection collection = NoteCollection.empty();
    LocalStorage().syncCollection(collection);
    Navigator.push(
        context,
        new MaterialPageRoute(
            builder: (context) => CollectionEditor(collection)));
  }

  @override
  Widget build(BuildContext context) {
    LocalStorage()
        .getCollections()
        .then((value) => LocalStorage().collectionController.sink.add(value));

    var builder = StreamBuilder<List<NoteCollection>>(
      stream: LocalStorage().collectionStream,
      initialData: [],
      builder: (context, snap) {
        print(snap);
        if (snap.hasData) {
          print("DB Set collections ${snap.data.length}");
          DB().setCollections(snap.data);
          return CollectionsContent(onMenuPressed: this.onMenuPressed);
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

class CollectionsContent extends StatefulWidget {
  final Function onMenuPressed;
  final NoteListType listType;

  CollectionsContent(
      {Key key, this.onMenuPressed, this.listType = NoteListType.double})
      : super(key: key);

  @override
  _CollectionsContentState createState() => _CollectionsContentState();
}

class _CollectionsContentState extends State<CollectionsContent>
    with StoreWatcherMixin, SingleTickerProviderStateMixin {
  CollectionsStore storage;

  @override
  void initState() {
    super.initState();
    storage = listenToStore(collectionsStoreToken);
  }

  bool get singleView => true;

  _sliverNoteSelectionAppBar() {
    return SliverAppBar(
      pinned: true,
      leading: IconButton(
          icon: Icon(Icons.clear), onPressed: () => clearCollectionSelection()),
      title: Text(storage.selectedCollections.length.toString()),
      actions: <Widget>[
        IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => removeAllSelectedCollections()),
        IconButton(
            icon: Icon((storage.selectedCollections
                            .where((e) => e.starred)
                            .toList()
                            .length
                            .toDouble() /
                        storage.selectedCollections.length.toDouble()) <
                    0.5
                ? Icons.star
                : Icons.star_border),
            onPressed: () {
              if ((storage.selectedCollections
                          .where((e) => e.starred)
                          .toList()
                          .length
                          .toDouble() /
                      storage.selectedCollections.length.toDouble()) <
                  0.5) {
                starAllSelectedCollections();
              } else {
                unstarAllSelectedCollections();
              }
            }),
      ],
    );
  }

  _sliver() {
    onTap(NoteCollection collection) {
      if (storage.isAnyCollectionSelected()) {
        triggerSelectCollection(collection);
      } else {
        Navigator.push(
            context,
            new MaterialPageRoute(
                builder: (context) => CollectionEditor(collection)));
      }
    }

    onLongPress(NoteCollection collection) {
      triggerSelectCollection(collection);
    }

    List<Widget> noteList = [];

    if (storage.isAnyCollectionStarred()) {
      print("notes are starred");
      List<NoteCollectionItemModel> items = storage.filteredCollections
          .where((n) => !n.starred)
          .map((n) => NoteCollectionItemModel(
              collection: n, isSelected: storage.isSelected(n)))
          .toList();

      List<NoteCollectionItemModel> starrtedItems = storage.filteredCollections
          .where((n) => n.starred)
          .map((n) => NoteCollectionItemModel(
              collection: n, isSelected: storage.isSelected(n)))
          .toList();

      noteList = [
        SliverList(
            delegate: SliverChildListDelegate([
          Padding(
              padding: EdgeInsets.only(left: 16, top: 16),
              child: Row(children: [
                Text("Starred", style: Theme.of(context).textTheme.caption),
                Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 0),
                    child: Icon(Icons.star, size: 16))
              ]))
        ])),
        NoteCollectionList(starrtedItems, onTap, onLongPress,
            singleView: singleView),
        SliverList(
            delegate: SliverChildListDelegate([
          Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text("Other", style: Theme.of(context).textTheme.caption))
        ])),
        NoteCollectionList(items, onTap, onLongPress, singleView: singleView)
      ];
    } else {
      List<NoteCollectionItemModel> items = storage.filteredCollections
          .map((n) => NoteCollectionItemModel(
              collection: n, isSelected: storage.isSelected(n)))
          .toList();

      noteList = [
        NoteCollectionList(items, onTap, onLongPress, singleView: singleView)
      ];
    }

    SliverAppBar appBar = storage.isAnyCollectionSelected()
        ? _sliverNoteSelectionAppBar()
        : _sliverAppBar();

    return CustomScrollView(
      slivers: [appBar]..addAll(noteList),
    );
  }

  _sliverAppBar() {
    return SliverAppBar(
      titleSpacing: 5.0,
      leading:
          IconButton(icon: Icon(Icons.menu), onPressed: widget.onMenuPressed),
      title: Center(
          child: Align(child: Text("Sets"), alignment: Alignment.centerLeft)),
      floating: false,
      pinned: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _sliver();
  }
}
