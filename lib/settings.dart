import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'backup.dart';
import 'dialogs/initial_import_dialog.dart';
import 'local_storage.dart';
import 'model.dart';
import 'recorder_store.dart';
import 'settings_store.dart';
import 'sync_debug_panel.dart';
import 'sync_network.dart';
import 'utils.dart';

class Settings extends StatefulWidget {
  final VoidCallback onMenuPressed;
  const Settings(this.onMenuPressed, {super.key});

  @override
  State<StatefulWidget> createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  final GlobalKey<ScaffoldState> _globalKey = GlobalKey<ScaffoldState>();
  bool _syncEnabled = true;
  String _syncBackendUrl = 'http://192.168.178.52:8009';

  @override
  void initState() {
    super.initState();
    _loadSyncConfig();
  }

  Future<void> _loadSyncConfig() async {
    final enabled = await LocalStorage().getSyncEnabled();
    final backendUrl = await LocalStorage().getSyncBackendUrl();
    if (!mounted) return;
    setState(() {
      _syncEnabled = enabled;
      _syncBackendUrl = backendUrl;
    });
  }

  String _themeAsString(SettingsStore store) =>
      store.theme == SettingsTheme.dark ? 'Dark' : 'Light';

  Widget _wrapItem(Widget item) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 8, top: 8, right: 48),
      child: item,
    );
  }

  String _audioFormatAsString(SettingsStore store) =>
      store.audioFormat == AudioFormat.aac ? 'AAC' : 'WAV';

  Future<void> _toggleAudioFormat(SettingsStore store) async {
    final newAudioFormat = store.audioFormat == AudioFormat.aac
        ? AudioFormat.wav
        : AudioFormat.aac;
    await setDefaultAudioFormat(newAudioFormat);
    setAudioFormat(newAudioFormat);
  }

  Future<void> _showEditNameDialog(SettingsStore store) async {
    final controller = TextEditingController(text: store.name ?? '');
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Name'),
          content: TextField(
            autofocus: true,
            maxLines: 1,
            minLines: 1,
            controller: controller,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Apply'),
              onPressed: () {
                setName(controller.value.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _onExport() async {
    final path = await Backup().exportZip(await LocalStorage().getNotes());
    showSnack(_globalKey.currentState, 'Exported zip to $path');
    final filename = p.basename(path);
    await SharePlus.instance.share(ShareParams(
      text: 'Share backup zip',
      title: filename,
      files: [XFile(path)],
    ));
  }

  Future<void> _onImport() async {
    try {
      final notes = await Backup().import();
      for (final note in notes) {
        note.id = const Uuid().v4();
      }
      showSelectNotesImportDialog(
        context,
        (List<Note> restoredNotes) {
          showSnack(
            _globalKey.currentState,
            'Successfully restored ${restoredNotes.length} notes',
          );
        },
        notes,
        title: 'Which songs would you like to restore?',
      );
    } on ImportException {
      showSnack(_globalKey.currentState, 'Error while importing zip');
    }
  }

  Future<void> _showBackendUrlDialog() async {
    final controller = TextEditingController(text: _syncBackendUrl);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sync Backend URL'),
          content: TextField(
            autofocus: true,
            maxLines: 1,
            minLines: 1,
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'http://127.0.0.1:8009',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Apply'),
              onPressed: () async {
                final next = controller.text.trim();
                if (next.isNotEmpty) {
                  await LocalStorage().setSyncBackendUrl(next);
                  if (mounted) {
                    setState(() {
                      _syncBackendUrl = next;
                    });
                  }
                }
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _setLanBackendUrl() async {
    final ip = await SyncNetwork.firstPrivateIpv4();
    if (ip == null) {
      showSnack(_globalKey.currentState, 'No private IPv4 interface found');
      return;
    }
    final url = 'http://$ip:8009';
    await LocalStorage().setSyncBackendUrl(url);
    if (!mounted) return;
    setState(() {
      _syncBackendUrl = url;
    });
    showSnack(_globalKey.currentState, 'Sync backend set to $url');
  }

  Widget _list(SettingsStore store) {
    final items = <Widget>[
      _wrapItem(Row(
        children: [
          const Expanded(child: Text('Name:')),
          ElevatedButton(
            child: Text((store.name == null || store.name!.isEmpty)
                ? 'Edit'
                : store.name!),
            onPressed: () => _showEditNameDialog(store),
          ),
        ],
      )),
      _wrapItem(Row(
        children: [
          const Expanded(child: Text('Theme:')),
          ElevatedButton(
            child: Text(_themeAsString(store)),
            onPressed: () => toggleTheme(),
          ),
        ],
      )),
      _wrapItem(Row(
        children: [
          const Expanded(child: Text('Audio Format:')),
          ElevatedButton(
            child: Text(_audioFormatAsString(store)),
            onPressed: () => _toggleAudioFormat(store),
          ),
        ],
      )),
      _wrapItem(Row(
        children: [
          const Expanded(child: Text('Sync Enabled:')),
          Switch(
            value: _syncEnabled,
            onChanged: (v) async {
              await LocalStorage().setSyncEnabled(v);
              if (!mounted) return;
              setState(() {
                _syncEnabled = v;
              });
            },
          ),
        ],
      )),
      _wrapItem(Row(
        children: [
          const Expanded(child: Text('Sync Backend:')),
          Flexible(
            child: ElevatedButton(
              onPressed: _showBackendUrlDialog,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _syncBackendUrl,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
        ],
      )),
      _wrapItem(
        Row(
          children: [
            const Expanded(child: Text('Use LAN URL:')),
            ElevatedButton(
              onPressed: _setLanBackendUrl,
              child: const Text('Auto-detect'),
            ),
          ],
        ),
      ),
      _wrapItem(
        Row(
          children: [
            const Expanded(child: Text('Sync Debug:')),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SyncDebugPanel(),
                  ),
                );
              },
              child: const Text('Open Panel'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ElevatedButton(onPressed: _onExport, child: const Text('Backup')),
      const SizedBox(height: 10),
      ElevatedButton(onPressed: _onImport, child: const Text('Restore')),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemBuilder: (context, index) => items[index],
      itemCount: items.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    return Scaffold(
      key: _globalKey,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onMenuPressed,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _list(store),
      ),
    );
  }
}
