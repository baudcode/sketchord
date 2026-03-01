import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sound/dialogs/audio_action_dialog.dart';
import 'package:sound/dialogs/audio_import_dialog.dart';
import 'package:sound/editor_views/audio.dart';
import 'package:sound/file_manager.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/recorder_bottom_sheet.dart';
import 'package:sound/recorder_store.dart';
import 'package:sound/share.dart';

class AudioIdeasPage extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const AudioIdeasPage({required this.onMenuPressed, super.key});

  @override
  State<AudioIdeasPage> createState() => _AudioIdeasPageState();
}

class _AudioIdeasPageState extends State<AudioIdeasPage> {
  List<AudioFile> _ideas = [];
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<AudioFile>? _recordingSub;
  bool _loading = true;
  bool _searching = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _recordingSub = recorderBottomSheetStore.onRecordingFinished.listen((f) async {
      await LocalStorage().addAudioIdea(f);
      await _loadIdeas();
    });
    _loadIdeas();
  }

  @override
  void dispose() {
    _recordingSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadIdeas() async {
    final ideas = await LocalStorage().getAudioIdeas();
    if (!mounted) return;
    setState(() {
      _ideas = ideas;
      _loading = false;
    });
  }

  Future<void> _deleteIdea(AudioFile file) async {
    await LocalStorage().deleteAudioIdea(file);
    await _loadIdeas();
  }

  Future<void> _moveIdea(AudioFile file) async {
    await showMoveToNoteDialog(context, () async {
      await LocalStorage().deleteAudioIdea(file);
      await _loadIdeas();
    }, file);
  }

  Future<void> _toggleStar(AudioFile file) async {
    file.starred = !file.starred;
    await LocalStorage().syncAudioFile(file);
    await _loadIdeas();
  }

  Future<void> _renameIdea(AudioFile file) async {
    final controller = TextEditingController(text: file.name);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Idea'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              file.name = controller.text.trim().isEmpty
                  ? 'Untitled idea'
                  : controller.text.trim();
              await LocalStorage().syncAudioFile(file);
              if (mounted) Navigator.pop(context);
              await _loadIdeas();
            },
            child: const Text('Apply'),
          )
        ],
      ),
    );
  }

  Future<void> _duplicateIdea(AudioFile file) async {
    final copy = await FileManager().copyToNew(file);
    copy.starred = file.starred;
    copy.text = file.text;
    await LocalStorage().addAudioIdea(copy);
    await _loadIdeas();
  }

  Future<void> _pickAndImportAudio() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['m4a', 'wav', 'mp3', 'aac'],
    );
    if (result == null) return;
    final files = result.paths.whereType<String>().map(File.new).toList();
    if (files.isEmpty || !mounted) return;
    showAudioImportDialog(context, files);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _loadIdeas();
  }

  Future<void> _toggleRecording() async {
    if (recorderBottomSheetStore.state == RecorderState.recording) {
      await stopAction();
    } else {
      await startRecordingAction();
    }
  }

  List<AudioFile> _filteredIdeas() {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _ideas;
    return _ideas.where((f) {
      return f.name.toLowerCase().contains(q) ||
          f.text.toLowerCase().contains(q) ||
          f.durationString.toLowerCase().contains(q);
    }).toList();
  }

  List<Widget> _buildIdeaTiles(List<AudioFile> files) {
    final list = <Widget>[];
    final starred = files.where((f) => f.starred).toList();
    final rest = files.where((f) => !f.starred).toList();

    void addGroup(String title, List<AudioFile> entries) {
      if (entries.isEmpty) return;
      list.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            if (title == 'Starred')
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.star, size: 14),
              ),
          ],
        ),
      ));

      for (final file in entries) {
        list.add(Dismissible(
          key: ValueKey(file.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _deleteIdea(file),
          background: Container(
            alignment: Alignment.centerRight,
            color: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.delete),
          ),
          child: ListTile(
            leading: IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => playInDialog(context, file),
            ),
            title: Text(file.name),
            subtitle: Text(file.durationString),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'share') {
                  await shareFile(file.path);
                } else if (action == 'move') {
                  await _moveIdea(file);
                } else if (action == 'delete') {
                  await _deleteIdea(file);
                } else if (action == 'star') {
                  await _toggleStar(file);
                } else if (action == 'rename') {
                  await _renameIdea(file);
                } else if (action == 'duplicate') {
                  await _duplicateIdea(file);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'share', child: Text('Share')),
                const PopupMenuItem(value: 'move', child: Text('Move to Note')),
                PopupMenuItem(
                  value: 'star',
                  child: Text(file.starred ? 'Unstar' : 'Star'),
                ),
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ));
      }
    }

    if (starred.isNotEmpty) {
      addGroup('Starred', starred);
      addGroup('Other', rest);
    } else {
      addGroup('Ideas', files);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final recorderStore = context.watch<RecorderBottomSheetStore>();
    final showSheet = recorderStore.state == RecorderState.recording ||
        recorderStore.state == RecorderState.playing ||
        recorderStore.state == RecorderState.pausing;
    final ideas = _filteredIdeas();

    return Scaffold(
      appBar: AppBar(
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
                  hintText: 'Search ideas...',
                ),
                onChanged: (value) => setState(() => _search = value),
              )
            : const Text('Ideas'),
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
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _pickAndImportAudio,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ideas.isEmpty
              ? const Center(child: Text('No audio ideas yet'))
              : RefreshIndicator(
                  onRefresh: _loadIdeas,
                  child: ListView(
                    children: _buildIdeaTiles(ideas),
                  ),
                ),
      bottomSheet: showSheet ? const RecorderBottomSheet() : null,
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleRecording,
        child: Icon(
          recorderStore.state == RecorderState.recording ? Icons.stop : Icons.mic,
        ),
      ),
    );
  }
}
