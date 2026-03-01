import 'package:flutter/foundation.dart';

class SyncDebugStore extends ChangeNotifier {
  DateTime? _lastAttemptAt;
  DateTime? _lastSuccessAt;
  String? _lastError;
  bool _isSyncing = false;
  int _lastUploadCount = 0;
  int _lastPullCount = 0;
  Future<void> Function()? _syncTrigger;

  DateTime? get lastAttemptAt => _lastAttemptAt;
  DateTime? get lastSuccessAt => _lastSuccessAt;
  String? get lastError => _lastError;
  bool get isSyncing => _isSyncing;
  int get lastUploadCount => _lastUploadCount;
  int get lastPullCount => _lastPullCount;

  void setSyncTrigger(Future<void> Function() trigger) {
    _syncTrigger = trigger;
  }

  void markStarted() {
    _isSyncing = true;
    _lastAttemptAt = DateTime.now();
    notifyListeners();
  }

  void markSucceeded({required int uploaded, required int pulled}) {
    _isSyncing = false;
    _lastSuccessAt = DateTime.now();
    _lastError = null;
    _lastUploadCount = uploaded;
    _lastPullCount = pulled;
    notifyListeners();
  }

  void markFailed(String error) {
    _isSyncing = false;
    _lastError = error;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (_syncTrigger == null) return;
    await _syncTrigger!.call();
  }
}

final SyncDebugStore syncDebugStore = SyncDebugStore();
