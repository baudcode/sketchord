import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_storage.dart';
import 'model.dart';

class SyncStatusStore extends ChangeNotifier {
  SyncStatusSummary _summary = const SyncStatusSummary(
    queuedChanges: 0,
    unresolvedConflicts: 0,
  );
  List<SyncConflict> _conflicts = [];
  StreamSubscription<SyncStatusSummary>? _subscription;
  bool _started = false;

  SyncStatusSummary get summary => _summary;
  int get queuedChanges => _summary.queuedChanges;
  int get unresolvedConflicts => _summary.unresolvedConflicts;
  bool get isFullySynced => _summary.isFullySynced;
  List<SyncConflict> get conflicts => _conflicts;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _subscription = LocalStorage().syncStatusStream.listen((summary) {
      _summary = summary;
      notifyListeners();
    });

    await refresh();
  }

  Future<void> refresh() async {
    _summary = await LocalStorage().getSyncStatusSummary();
    _conflicts = await LocalStorage().getSyncConflicts(unresolvedOnly: true);
    notifyListeners();
  }

  Future<void> resolveConflict(String conflictId) async {
    await LocalStorage().resolveSyncConflict(conflictId);
    await refresh();
  }

  Future<int> resolveAllConflicts() async {
    final count = await LocalStorage().resolveAllSyncConflicts();
    await refresh();
    return count;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final SyncStatusStore syncStatusStore = SyncStatusStore();
