import 'package:flutter/material.dart';
import 'package:sound/dialogs/audio_action_dialog.dart';
import 'package:sound/editor_views/audio.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/share.dart';

class AudioIdeasPage extends StatefulWidget {
  final VoidCallback onMenuPressed;

  const AudioIdeasPage({required this.onMenuPressed, super.key});

  @override
  State<AudioIdeasPage> createState() => _AudioIdeasPageState();
}

class _AudioIdeasPageState extends State<AudioIdeasPage> {
  List<AudioFile> _ideas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadIdeas();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onMenuPressed,
        ),
        title: const Text('Ideas'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ideas.isEmpty
              ? const Center(child: Text('No audio ideas yet'))
              : RefreshIndicator(
                  onRefresh: _loadIdeas,
                  child: ListView.builder(
                    itemCount: _ideas.length,
                    itemBuilder: (context, index) {
                      final file = _ideas[index];
                      return Dismissible(
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
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'share', child: Text('Share')),
                              PopupMenuItem(value: 'move', child: Text('Move to Note')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
