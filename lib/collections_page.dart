import 'package:flutter/material.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_editor.dart';

class CollectionsPage extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const CollectionsPage({required this.onMenuPressed, super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  List<NoteCollection> _collections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onMenuPressed,
        ),
        title: const Text('Sets'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createCollection),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _collections.isEmpty
              ? const Center(child: Text('No sets yet'))
              : RefreshIndicator(
                  onRefresh: _loadCollections,
                  child: ListView.builder(
                    itemCount: _collections.length,
                    itemBuilder: (context, index) {
                      final c = _collections[index];
                      return ListTile(
                        title: Text(c.title.isEmpty ? 'Untitled Set' : c.title),
                        subtitle: Text('${c.activeNotes.length} notes'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openCollection(c),
                      );
                    },
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
                    _collection.notes = notes.where((n) => selected.contains(n.id)).toList();
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
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _collection.notes.length,
              itemBuilder: (context, index) {
                final note = _collection.notes[index];
                return ListTile(
                  title: Text(note.title.isEmpty ? 'Untitled Note' : note.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () async {
                      setState(() {
                        _collection.notes.removeAt(index);
                      });
                      await _save();
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NoteEditor(note)),
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
