import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_storage.dart';
import 'model.dart';
import 'sync_debug_store.dart';
import 'sync_network.dart';

class SyncEngine {
  Timer? _timer;
  bool _isSyncing = false;

  Future<void> start() async {
    syncDebugStore.setSyncTrigger(runOnce);
    await runOnce();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) async {
      await runOnce();
    });
  }

  Future<void> runOnce() async {
    if (_isSyncing) return;
    _isSyncing = true;
    syncDebugStore.markStarted();
    int uploaded = 0;
    int pulled = 0;
    try {
      final enabled = await LocalStorage().getSyncEnabled();
      if (!enabled) {
        syncDebugStore.markSucceeded(uploaded: 0, pulled: 0);
        return;
      }

      final baseUrl = await _resolvedBackendUrl();
      uploaded = await _uploadQueued(baseUrl);
      pulled = await _pullChanges(baseUrl);
      syncDebugStore.markSucceeded(uploaded: uploaded, pulled: pulled);
    } catch (e) {
      syncDebugStore.markFailed(e.toString());
      // Keep sync loop alive; queue items stay queued for next attempt.
    } finally {
      _isSyncing = false;
    }
  }

  Future<String> _resolvedBackendUrl() async {
    final configured = await LocalStorage().getSyncBackendUrl();
    Uri uri;
    try {
      uri = Uri.parse(configured);
    } catch (_) {
      throw Exception('Invalid sync backend URL: $configured');
    }

    if (uri.host != '0.0.0.0') {
      return configured;
    }

    // 0.0.0.0 is a bind address, not a client destination.
    if (Platform.isAndroid || Platform.isIOS) {
      throw Exception(
        'Sync backend URL uses 0.0.0.0. On mobile use your desktop LAN IP like http://192.168.x.x:8009',
      );
    }

    final loopback = uri.replace(host: '127.0.0.1').toString();
    final lanIp = await SyncNetwork.firstPrivateIpv4();
    final resolved =
        lanIp == null ? loopback : uri.replace(host: lanIp).toString();
    await LocalStorage().setSyncBackendUrl(resolved);
    return resolved;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<int> _uploadQueued(String baseUrl) async {
    final queued = await LocalStorage().getQueuedSyncChanges();
    if (queued.isEmpty) return 0;
    final source = await _clientSource();

    final mutations = queued
        .map(
          (item) => {
            'op_id': item.id,
            'entity_type': item.entityType.name,
            'entity_id': item.entityId,
            'operation': item.operation.name,
            'base_version': item.baseVersion,
            'payload': jsonDecode(item.payload),
            'client_ts': serializeDateTime(item.createdAt),
            'source': source,
          },
        )
        .toList();

    final response = await _postJson(
      '$baseUrl/v1/sync/upload',
      {'mutations': mutations},
    );
    final results = (response['results'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (final result in results) {
      final opId = result['op_id']?.toString() ?? '';
      final status = result['status']?.toString() ?? '';
      final entityTypeRaw = result['entity_type']?.toString() ?? '';
      final entityId = result['entity_id']?.toString() ?? '';
      final serverVersion = (result['server_version'] as num?)?.toInt();

      if (status == 'applied' || status == 'merged' || status == 'duplicate') {
        await LocalStorage().markQueueItemSynced(
          opId,
          newServerVersion: serverVersion,
          entityType: deserializeSyncEntityType(entityTypeRaw),
          entityId: entityId,
        );
      } else if (status == 'rejected') {
        final message =
            result['message']?.toString() ?? 'Mutation rejected by backend';
        final remotePayload =
            (result['remote_payload'] as Map?)?.cast<String, dynamic>();
        await LocalStorage().markQueueItemRejected(
          queueId: opId,
          reason: message,
          remotePayload: remotePayload,
        );
      }
    }
    return results.length;
  }

  Future<int> _pullChanges(String baseUrl) async {
    final sinceSeq = await LocalStorage().getSyncPullCursor();

    final response =
        await _getJson('$baseUrl/v1/sync/pull?since_seq=$sinceSeq');
    final changes = (response['changes'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (final change in changes) {
      final entityType = deserializeSyncEntityType(
        change['entity_type']?.toString() ?? '',
      );
      final entityId = change['entity_id']?.toString() ?? '';
      final operation = deserializeSyncOperationType(
        change['operation']?.toString() ?? '',
      );
      final version = (change['version'] as num?)?.toInt() ?? 0;
      final payload =
          (change['payload'] as Map?)?.cast<String, dynamic>() ?? {};
      await LocalStorage().applyRemoteChange(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        serverVersion: version,
      );
    }
    final nextSeq = (response['next_seq'] as num?)?.toInt() ?? sinceSeq;
    if (nextSeq > sinceSeq) {
      await LocalStorage().setSyncPullCursor(nextSeq);
    }
    return changes.length;
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(url));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      if (response.statusCode >= 400) {
        throw HttpException('Sync upload failed (${response.statusCode})');
      }
      return jsonDecode(payload) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      if (response.statusCode >= 400) {
        throw HttpException('Sync pull failed (${response.statusCode})');
      }
      return jsonDecode(payload) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _clientSource() async {
    final settings = await LocalStorage().getSettings();
    final userName = (settings.name ?? '').trim();
    String appLabel;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      appLabel = 'desktop-${Platform.operatingSystem}';
    } else if (Platform.isAndroid || Platform.isIOS) {
      appLabel = 'mobile-${Platform.operatingSystem}';
    } else {
      appLabel = Platform.operatingSystem;
    }
    if (userName.isEmpty) return appLabel;
    return '$appLabel:$userName';
  }
}

final SyncEngine syncEngine = SyncEngine();
