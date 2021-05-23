import 'package:flutter/material.dart';
import 'package:sound/dialogs/color_picker_dialog.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_list.dart';
import 'package:sound/recorder_bottom_sheet.dart';
import 'package:sound/storage.dart';
import 'package:sound/utils.dart';

class NoteSetItem extends StatelessWidget {
  final NoteSet nc;
  final bool selected;
  final ValueChanged<NoteSet> onTap;
  final ValueChanged<NoteSet> onLongPress;

  NoteSetItem(
      {@required this.nc,
      @required this.selected,
      @required this.onTap,
      @required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Ink(
        color: selected ? getSelectedCardColor(context) : nc.color,
        child: ListTile(
          title: Text(nc.getName()),
          onTap: () => onTap(nc),
          onLongPress: () => onLongPress(nc),
        ));
  }
}

class NoteSetEditor extends StatefulWidget {
  final NoteSet noteset;

  NoteSetEditor(@required this.noteset, {Key key}) : super(key: key);

  @override
  _NoteSetEditorState createState() => _NoteSetEditorState();
}

class _NoteSetEditorState extends State<NoteSetEditor> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        child: Scaffold(),
        onWillPop: () async {
          return true;
        });
  }
}

class NoteSets extends StatefulWidget {
  final Function onMenuPressed;

  NoteSets(this.onMenuPressed, {Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _NoteSetsState();
  }
}

enum FilterOrder { up, down }
enum FilterType { date, title }

class _NoteSetsState extends State<NoteSets> {
  final GlobalKey _globalKey = GlobalKey();

  List<NoteSet> selectedSets = [];
  FilterOrder order = FilterOrder.up; //
  FilterType type = FilterType.date;

  bool isSelected(NoteSet noteset) => selectedSets.contains(noteset);
  bool get isAnySetSelected => selectedSets.length > 0;

  List<NoteSet> sets = [];

  List<String> popups = ['delete'];

  @override
  void initState() {
    super.initState();

    LocalStorage().getSets().then((value) => setState(() {
          sets = value;
        }));
  }

  _clearSelection() {
    setState(() {
      selectedSets.clear();
    });
  }

  _runPopupAction(String action) {
    print("action: $action");
    if (action == "delete") {
      for (NoteSet nc in selectedSets) {
        LocalStorage().deleteSet(nc);
      }
      setState(() {
        sets.removeWhere((n) => isSelected(n));
      });
    } else if (action == 'delete_all') {
      for (NoteSet noteset in sets) {
        LocalStorage().deleteSet(noteset);
      }
      setState(() {
        sets = [];
      });
    }
  }

  sortSets() {
    sets.sort((n1, n2) {
      if (type == FilterType.date) {
        if (order == FilterOrder.down)
          return -n1.createdAt.compareTo(n2.createdAt);
        else
          return n1.createdAt.compareTo(n2.createdAt);
      } else if (type == FilterType.title) {
        if (order == FilterOrder.down)
          return -n1.name.compareTo(n2.name);
        else
          return n1.name.compareTo(n2.name);
      } else {
        if (order == FilterOrder.down)
          return -n1.createdAt.compareTo(n2.createdAt);
        else
          return n1.createdAt.compareTo(n2.createdAt);
      }
    });
  }

  starAllSelectedSets() {
    // TODO: sync set with database
    setState(() {
      sets.forEach((element) {
        element.starred = true;
      });
      selectedSets.clear();
    });
  }

  unstarAllSelectedSets() {
    // TODO: sync set with database
    setState(() {
      sets.forEach((element) {
        element.starred = false;
      });
      selectedSets.clear();
    });
  }

  colorAllSelectedNotes(Color c) {
    // TODO: sync set with database
    var selectedIds = selectedSets.map((s) => s.id);

    setState(() {
      sets.forEach((element) {
        if (selectedIds.contains(element.id)) {
          element.color = c;
        }
      });
      selectedSets.clear();
    });
  }

  deleteSelectedSets() {
    for (NoteSet noteset in selectedSets) {
      setState(() {
        sets.remove(noteset);
      });
    }
    selectedSets.clear();
  }

  _selectionAppBar() {
    var actions = [
      IconButton(
          icon: Icon(Icons.delete), onPressed: () => deleteSelectedSets()),
      IconButton(
          icon: Icon(Icons.color_lens),
          onPressed: () {
            showColorPickerDialog(context, null, (c) {
              colorAllSelectedNotes(c);
            });
          }),
      IconButton(
          icon: Icon(
              (selectedSets.where((e) => e.starred).toList().length.toDouble() /
                          selectedSets.length.toDouble()) <
                      0.5
                  ? Icons.star
                  : Icons.star_border),
          onPressed: () {
            if ((selectedSets
                        .where((e) => e.starred)
                        .toList()
                        .length
                        .toDouble() /
                    selectedSets.length.toDouble()) <
                0.5) {
              starAllSelectedSets();
            } else {
              unstarAllSelectedSets();
            }
          }),
    ];

    return AppBar(
      leading: IconButton(icon: Icon(Icons.clear), onPressed: _clearSelection),
      title: Text(selectedSets.length.toString()),
      actions: <Widget>[
        ...actions,
      ],
    );
  }

  _onChooseFilter() {
    setState(() {
      type = (type == FilterType.date) ? FilterType.title : FilterType.date;
    });
    sortSets();
  }

  _onFilterOrderChange() {
    setState(() {
      order = (order == FilterOrder.up) ? FilterOrder.down : FilterOrder.up;
    });
    sortSets();
  }

  _appBar() {
    return AppBar(
        title: Text("Sets"),
        actions: [
          // IconButton(onPressed: _onChooseFilter, icon: Icon(Icons.filter_list)),
          // IconButton(
          //     onPressed: _onFilterOrderChange,
          //     icon: Icon(order == FilterOrder.up
          //         ? Icons.arrow_upward
          //         : Icons.arrow_downward)),
        ],
        leading: IconButton(
            icon: Icon(Icons.menu), onPressed: widget.onMenuPressed));
  }

  _selectSet(NoteSet noteset) {
    if (!isSelected(noteset)) {
      setState(() {
        selectedSets.add(noteset);
      });
    } else {
      setState(() {
        selectedSets.remove(noteset);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // items.add(_title());
    // List<NoteListItemModel> items = notes
    //     .map((n) => NoteListItemModel(note: n, isSelected: isSelected(n)))
    //     .toList();

    onTap(NoteSet noteset) {
      if (isAnySetSelected) {
        _selectSet(noteset);
      } else {
        Navigator.push(
            context,
            new MaterialPageRoute(
                builder: (context) => NoteSetEditor(
                      noteset,
                    )));
      }
    }

    _floatingButtonPress(BuildContext context) {
      NoteSet noteset = NoteSet.empty();
      // TODO: sync note
      onTap(noteset);
    }

    onLongPress(NoteSet noteset) {
      _selectSet(noteset);
    }

    return Scaffold(
        key: _globalKey,
        appBar: isAnySetSelected ? _selectionAppBar() : _appBar(),
        floatingActionButton: FloatingActionButton(
          foregroundColor: Colors.white,
          backgroundColor: Theme.of(context).accentColor,
          onPressed: () => _floatingButtonPress(context),
          child: IconButton(
            onPressed: () => _floatingButtonPress(context),
            icon: Icon(Icons.add),
          ),
        ),
        bottomSheet: RecorderBottomSheet(),
        body: Container(
            child: ListView.builder(
                itemCount: sets.length,
                itemBuilder: (context, index) {
                  NoteSet nc = sets[index];
                  return NoteSetItem(
                      nc: nc,
                      selected: isSelected(nc),
                      onTap: onTap,
                      onLongPress: onLongPress);
                })) // NoteList(false, false, items, onTap, onLongPress),
        );
  }
}
