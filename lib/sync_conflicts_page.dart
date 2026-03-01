import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'model.dart';
import 'sync_status_store.dart';

class SyncConflictsPage extends StatefulWidget {
  const SyncConflictsPage({super.key});

  @override
  State<SyncConflictsPage> createState() => _SyncConflictsPageState();
}

class _SyncConflictsPageState extends State<SyncConflictsPage> {
  @override
  void initState() {
    super.initState();
    syncStatusStore.refresh();
  }

  String _prettyJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return rawJson;
    }
  }

  Widget _statusHeader(SyncStatusStore store) {
    final queueText = store.queuedChanges == 1
        ? '1 queued change'
        : '${store.queuedChanges} queued changes';
    final conflictText = store.unresolvedConflicts == 1
        ? '1 unresolved conflict'
        : '${store.unresolvedConflicts} unresolved conflicts';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_outlined),
          const SizedBox(width: 8),
          Text('$queueText, $conflictText'),
        ],
      ),
    );
  }

  Widget _conflictTile(SyncConflict conflict, SyncStatusStore store) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${conflict.entityType.name} ${conflict.operation.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              conflict.reason,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Entity: ${conflict.entityId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Queued payload'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: Theme.of(context).cardColor,
                  child: SelectableText(_prettyJson(conflict.localPayload)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => store.resolveConflict(conflict.id),
                icon: const Icon(Icons.check),
                label: const Text('Mark resolved'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SyncStatusStore>();
    final conflicts = store.conflicts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Conflicts'),
        actions: [
          if (conflicts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Resolve all',
              onPressed: () => store.resolveAllConflicts(),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: store.refresh),
        ],
      ),
      body: Column(
        children: [
          _statusHeader(store),
          Expanded(
            child: conflicts.isEmpty
                ? const Center(child: Text('No unresolved conflicts'))
                : ListView.builder(
                    itemCount: conflicts.length,
                    itemBuilder: (context, index) =>
                        _conflictTile(conflicts[index], store),
                  ),
          ),
        ],
      ),
    );
  }
}
