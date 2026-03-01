import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'local_storage.dart';
import 'sync_debug_store.dart';
import 'sync_status_store.dart';

class SyncDebugPanel extends StatefulWidget {
  const SyncDebugPanel({super.key});

  @override
  State<SyncDebugPanel> createState() => _SyncDebugPanelState();
}

class _SyncDebugPanelState extends State<SyncDebugPanel> {
  String _backendUrl = '';
  bool _syncEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final url = await LocalStorage().getSyncBackendUrl();
    final enabled = await LocalStorage().getSyncEnabled();
    if (!mounted) return;
    setState(() {
      _backendUrl = url;
      _syncEnabled = enabled;
    });
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return dt.toIso8601String();
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 170, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debugStore = context.watch<SyncDebugStore>();
    final syncStatus = context.watch<SyncStatusStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Debug'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Runtime', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _row('Sync enabled', _syncEnabled ? 'true' : 'false'),
          _row('Backend URL', _backendUrl),
          _row('Currently syncing', debugStore.isSyncing ? 'true' : 'false'),
          _row('Queued changes', '${syncStatus.queuedChanges}'),
          _row('Unresolved conflicts', '${syncStatus.unresolvedConflicts}'),
          _row('Last upload count', '${debugStore.lastUploadCount}'),
          _row('Last pull count', '${debugStore.lastPullCount}'),
          _row('Last attempt', _fmt(debugStore.lastAttemptAt)),
          _row('Last success', _fmt(debugStore.lastSuccessAt)),
          _row('Last error', debugStore.lastError ?? '-'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  await debugStore.syncNow();
                  await syncStatus.refresh();
                  await _loadConfig();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await syncStatus.refresh();
                  await _loadConfig();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh panel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
