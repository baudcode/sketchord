import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'types.dart';

typedef DownloadProgress = void Function(double progress);

class ModelArtifact {
  const ModelArtifact({required this.file, required this.version});

  final File file;
  final String version;
}

class ModelDownloadManager {
  ModelDownloadManager({HttpClient? client}) : _client = client ?? HttpClient();

  static const _manifestUrl = String.fromEnvironment('MODEL_MANIFEST_URL');
  static final _upstreamEntries = <String, _ModelManifestEntry>{
    OnDeviceModel.basicPitch.name: _ModelManifestEntry(
      id: 'basic-pitch',
      // Pin to the upstream commit, rather than a mutable branch URL, so the
      // checksum remains a meaningful integrity check.
      version: 'icassp-2022-fa5997af',
      url: Uri.parse(
        'https://raw.githubusercontent.com/spotify/basic-pitch/'
        'fa5997af0a8210982619003269994a1be25eddf3/'
        'basic_pitch/saved_models/icassp_2022/nmp.tflite',
      ),
      fileName: 'basic_pitch_nmp.tflite',
      sha256:
          '3db297d54af8e01c6e5618245c956b1d71b6a2b978cb2dedb527173186552676',
    ),
  };
  final HttpClient _client;
  Map<String, _ModelManifestEntry>? _manifest;

  static bool get hasRemoteManifest => _manifestUrl.isNotEmpty;

  /// Some models provide a licence-compatible, immutable upstream artifact.
  /// Others intentionally require our reviewed manifest because their graph
  /// has to be exported/validated for this runner first.
  static bool hasBundledUpstreamArtifact(OnDeviceModel model) =>
      _upstreamEntries.containsKey(model.name);

  /// Fetches only a compact signed/checksummed manifest first. Model binaries
  /// are fetched after the user selects a model, never during app startup.
  Future<ModelArtifact> ensureDownloaded(
    OnDeviceModelInfo info, {
    DownloadProgress? onProgress,
  }) async {
    if (info.runtime == TranscriptionRuntime.dart) {
      throw ModelUnavailableException(
          '${info.title} does not need a model download.');
    }
    final entry = await _entryFor(info);
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
        p.join(root.path, 'transcription-models', entry.id, entry.version));
    final target = File(p.join(directory.path, entry.fileName));
    if (await target.exists() && await _matchesChecksum(target, entry.sha256)) {
      onProgress?.call(1);
      return ModelArtifact(file: target, version: entry.version);
    }

    await directory.create(recursive: true);
    final partial = File('${target.path}.partial');
    if (await partial.exists()) await partial.delete();
    final request = await _client.getUrl(entry.url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw ModelUnavailableException(
          'Could not download ${info.title} (HTTP ${response.statusCode}).');
    }
    final length = response.contentLength;
    var received = 0;
    final sink = partial.openWrite();
    try {
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (length > 0) onProgress?.call(received / length);
      }
      await sink.close();
      if (!await _matchesChecksum(partial, entry.sha256)) {
        throw ModelUnavailableException(
            'The ${info.title} download failed its checksum.');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      onProgress?.call(1);
      return ModelArtifact(file: target, version: entry.version);
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<_ModelManifestEntry> _entryFor(OnDeviceModelInfo info) async {
    if (_manifestUrl.isEmpty) {
      final upstream = _upstreamEntries[info.model.name];
      if (upstream != null) return upstream;
      throw ModelUnavailableException(
        'Model downloads are not configured. Build with '
        '--dart-define=MODEL_MANIFEST_URL=https://…/models.json.',
      );
    }
    final manifest = await _loadManifest();
    final entry = manifest[info.model.name];
    if (entry == null) {
      throw ModelUnavailableException(
          '${info.title} is not available in this model manifest.');
    }
    return entry;
  }

  Future<Map<String, _ModelManifestEntry>> _loadManifest() async {
    if (_manifest != null) return _manifest!;
    final request = await _client.getUrl(Uri.parse(_manifestUrl));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw ModelUnavailableException(
          'Could not load the model manifest (HTTP ${response.statusCode}).');
    }
    final body = await utf8.decodeStream(response);
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final models = decoded['models'] as Map<String, dynamic>?;
    if (models == null)
      throw ModelUnavailableException(
          'The model manifest has no models object.');
    _manifest = models.map((key, value) => MapEntry(
          key,
          _ModelManifestEntry.fromJson(value as Map<String, dynamic>),
        ));
    return _manifest!;
  }

  Future<bool> _matchesChecksum(File file, String expected) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == expected.toLowerCase();
  }
}

class _ModelManifestEntry {
  const _ModelManifestEntry({
    required this.id,
    required this.version,
    required this.url,
    required this.fileName,
    required this.sha256,
  });

  factory _ModelManifestEntry.fromJson(Map<String, dynamic> json) {
    final requiredFields = ['id', 'version', 'url', 'fileName', 'sha256'];
    if (requiredFields.any(
        (field) => json[field] is! String || (json[field] as String).isEmpty)) {
      throw ModelUnavailableException(
          'The model manifest contains an invalid entry.');
    }
    final url = Uri.tryParse(json['url'] as String);
    if (url == null || url.scheme != 'https') {
      throw ModelUnavailableException('Model downloads must use HTTPS.');
    }
    final id = json['id'] as String;
    final version = json['version'] as String;
    final fileName = p.basename(json['fileName'] as String);
    final checksum = json['sha256'] as String;
    if (p.basename(id) != id ||
        p.basename(version) != version ||
        fileName != json['fileName'] ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(checksum)) {
      throw ModelUnavailableException(
          'The model manifest contains an unsafe artifact path or checksum.');
    }
    return _ModelManifestEntry(
      id: id,
      version: version,
      url: url,
      fileName: fileName,
      sha256: checksum,
    );
  }

  final String id;
  final String version;
  final Uri url;
  final String fileName;
  final String sha256;
}
