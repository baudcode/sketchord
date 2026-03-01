import 'package:flutter/material.dart';
import 'package:sound/backup.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';
import 'package:sound/note_viewer.dart';
import 'package:sound/share.dart';

Future<void> showAddNoteToSetDialog(BuildContext context, Note note) async {
  final collections = await LocalStorage().getCollections();
  if (!context.mounted) return;

  final selected = <String>{};
  for (final c in collections) {
    if (c.notes.any((n) => n.id == note.id)) {
      selected.add(c.id);
    }
  }

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add to Set'),
        content: SizedBox(
          width: 460,
          height: 420,
          child: collections.isEmpty
              ? const Center(child: Text('No sets yet'))
              : ListView.builder(
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    return CheckboxListTile(
                      value: selected.contains(collection.id),
                      title: Text(
                        collection.title.isEmpty ? 'Untitled Set' : collection.title,
                      ),
                      subtitle: Text('${collection.notes.length} notes'),
                      onChanged: (value) {
                        setState(() {
                          if (value ?? false) {
                            selected.add(collection.id);
                          } else {
                            selected.remove(collection.id);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              for (final c in collections) {
                final has = c.notes.any((n) => n.id == note.id);
                final selectedNow = selected.contains(c.id);
                if (selectedNow && !has) {
                  c.notes.add(note);
                  await LocalStorage().syncCollection(c);
                }
                if (!selectedNow && has) {
                  c.notes.removeWhere((n) => n.id == note.id);
                  await LocalStorage().syncCollection(c);
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

class CollectionsPage extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const CollectionsPage({required this.onMenuPressed, super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  List<NoteCollection> _collections = [];
  final Set<String> _selectedIds = <String>{};
  bool _loading = true;
  bool _searching = false;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollections() async {
    final collections = await LocalStorage().getCollections();
    if (!mounted) return;
    setState(() {
      _collections = collections;
      _loading = false;
    });
  }

  Future<void> _createCollection() async {
    final collection = NoteCollection.empty();
    await LocalStorage().syncCollection(collection);
    await _openCollection(collection);
  }

  Future<void> _openCollection(NoteCollection collection) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionEditorPage(collection: collection),
      ),
    );
    await _loadCollections();
  }

  void _toggleSelection(NoteCollection c) {
    setState(() {
      if (_selectedIds.contains(c.id)) {
        _selectedIds.remove(c.id);
      } else {
        _selectedIds.add(c.id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final selected =
        _collections.where((c) => _selectedIds.contains(c.id)).toList();
    for (final c in selected) {
      await LocalStorage().deleteCollection(c);
    }
    _selectedIds.clear();
    await _loadCollections();
  }

  Future<void> _setStarSelected(bool starred) async {
    for (final c in _collections.where((c) => _selectedIds.contains(c.id))) {
      c.starred = starred;
      await LocalStorage().syncCollection(c);
    }
    _selectedIds.clear();
    await _loadCollections();
  }

  List<NoteCollection> _filteredCollections() {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _collections;
    return _collections.where((c) {
      return c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final collections = _filteredCollections();
    final starred = collections.where((c) => c.starred).toList();
    final unstarred = collections.where((c) => !c.starred).toList();

    PreferredSizeWidget appBar;
    if (_selectionMode) {
      appBar = AppBar(
        leading: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => setState(() => _selectedIds.clear()),
        ),
        title: Text('${_selectedIds.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () => _setStarSelected(true),
          ),
          IconButton(
            icon: const Icon(Icons.star_border),
            onPressed: () => _setStarSelected(false),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelected,
          ),
        ],
      );
    } else {
      appBar = AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onMenuPressed,
        ),
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search sets...',
                ),
                onChanged: (v) => setState(() => _search = v),
              )
            : const Text('Sets'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_searching) {
                  _searchController.clear();
                  _search = '';
                }
                _searching = !_searching;
              });
            },
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: _createCollection),
        ],
      );
    }

    Widget list(List<NoteCollection> data, {String? title}) {
      if (data.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(title, style: Theme.of(context).textTheme.bodySmall),
            ),
          ...data.map((c) {
            final selected = _selectedIds.contains(c.id);
            return ListTile(
              tileColor: selected
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : null,
              title: Text(c.title.isEmpty ? 'Untitled Set' : c.title),
              subtitle: Text(
                c.description.isEmpty
                    ? '${c.activeNotes.length} notes'
                    : '${c.description} • ${c.activeNotes.length} notes',
              ),
              leading: c.starred ? const Icon(Icons.star, size: 18) : null,
              trailing: const Icon(Icons.chevron_right),
              onLongPress: () => _toggleSelection(c),
              onTap: () {
                if (_selectionMode) {
                  _toggleSelection(c);
                } else {
                  _openCollection(c);
                }
              },
            );
          }),
        ],
      );
    }

    return Scaffold(
      appBar: appBar,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : collections.isEmpty
              ? const Center(child: Text('No sets yet'))
              : RefreshIndicator(
                  onRefresh: _loadCollections,
                  child: ListView(
                    children: [
                      if (starred.isNotEmpty) list(starred, title: 'Starred'),
                      list(unstarred, title: starred.isNotEmpty ? 'Other' : null),
                    ],
                  ),
                ),
    );
  }
}

class CollectionEditorPage extends StatefulWidget {
  final NoteCollection collection;

  const CollectionEditorPage({required this.collection, super.key});

  @override
  State<CollectionEditorPage> createState() => _CollectionEditorPageState();
}

class _CollectionEditorPageState extends State<CollectionEditorPage> {
  late NoteCollection _collection;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    _titleController = TextEditingController(text: _collection.title);
    _descriptionController = TextEditingController(text: _collection.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _collection.title = _titleController.text;
    _collection.description = _descriptionController.text;
    await LocalStorage().syncCollection(_collection);
  }

  Future<void> _deleteCollection() async {
    await LocalStorage().deleteCollection(_collection);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleStar() async {
    _collection.starred = !_collection.starred;
    await _save();
    setState(() {});
  }

  Future<void> _exportCollectionZip() async {
    final notes = _collection.activeNotes;
    if (notes.isEmpty) return;
    final path = await Backup().exportZip(notes);
    if (path.isNotEmpty) {
      await shareFile(path,
          filename: '${_collection.title.isEmpty ? "set" : _collection.title}.zip');
    }
  }

  Future<void> _addNotes() async {
    final notes = await LocalStorage().getActiveNotes();
    if (!mounted) return;

    final selected = _collection.notes.map((n) => n.id).toSet();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add notes'),
              content: SizedBox(
                width: 460,
                height: 420,
                child: ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final checked = selected.contains(note.id);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(note.title.isEmpty ? 'Untitled Note' : note.title),
                      onChanged: (value) {
                        setState(() {
                          if (value ?? false) {
                            selected.add(note.id);
                          } else {
                            selected.remove(note.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _collection.notes =
                        notes.where((n) => selected.contains(n.id)).toList();
                    await _save();
                    if (mounted) Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Set'),
        actions: [
          IconButton(
            icon: Icon(_collection.starred ? Icons.star : Icons.star_border),
            onPressed: _toggleStar,
          ),
          IconButton(icon: const Icon(Icons.upload_file), onPressed: _exportCollectionZip),
          IconButton(icon: const Icon(Icons.playlist_add), onPressed: _addNotes),
          IconButton(icon: const Icon(Icons.delete), onPressed: _deleteCollection),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (_) => _save(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (_) => _save(),
            ),
          ),
          if (_collection.lengthStr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Length: ${_collection.lengthStr}'),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _collection.notes.length,
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final note = _collection.notes.removeAt(oldIndex);
                  _collection.notes.insert(newIndex, note);
                });
                await _save();
              },
              itemBuilder: (context, index) {
                final note = _collection.notes[index];
                return ListTile(
                  key: ValueKey('${note.id}-$index'),
                  title: Text(note.title.isEmpty ? 'Untitled Note' : note.title),
                  subtitle: Text(note.lengthStr.isEmpty ? '' : note.lengthStr),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () async {
                          setState(() {
                            _collection.notes.removeAt(index);
                          });
                          await _save();
                        },
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NoteEditor(note)),
                    );
                  },
                  onLongPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteViewer(
                          note,
                          showAdditionalInformation: false,
                          showTitle: true,
                          showAudioFiles: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
