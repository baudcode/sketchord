import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show RangeValues;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:tuple/tuple.dart';

import 'editor_store.dart';
import 'model.dart';

enum RecorderState { stop, recording, playing, pausing }

class PlayerPositionStore extends ChangeNotifier {
  Duration _position = Duration.zero;
  Duration get position => _position;

  void changePlayerPosition(Duration value) {
    _position = value;
    notifyListeners();
  }
}

class RecorderPositionStore extends ChangeNotifier {
  Duration _position = Duration.zero;
  Duration get position => _position;

  void changeRecorderPosition(Duration value) {
    _position = value;
    notifyListeners();
  }
}

class RecorderBottomSheetStore extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<AudioFile> _recordingFinishedController =
      StreamController<AudioFile>.broadcast();

  Timer? _recordTicker;
  DateTime? _recordStartedAt;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  AudioFormat _audioFormat = AudioFormat.wav;
  AudioFormat get audioFormat => _audioFormat;

  RecorderState _state = RecorderState.stop;
  RecorderState get state => _state;
  String? _currentPath;
  String? get currentPath => _currentPath;
  Duration? _currentLength;
  Duration? get currentLength => _currentLength;
  Duration? _recordTime;
  Duration? get recordTime => _recordTime;

  RangeValues? _loopRange;
  RangeValues? get loopRange => _loopRange;

  AudioFile? _audioFile;
  AudioFile? get currentAudioFile => _audioFile;

  Stream<AudioFile> get onRecordingFinished => _recordingFinishedController.stream;

  Duration? getDurationLoopEnd() {
    if (_loopRange == null) return null;
    return Duration(milliseconds: (_loopRange!.end * 1000).floor());
  }

  Duration? getDurationLoopStart() {
    if (_loopRange == null) return null;
    return Duration(milliseconds: (_loopRange!.start * 1000).floor());
  }

  Future<void> _stopPlayerInternal() async {
    await _player.stop();
    playerPositionStore.changePlayerPosition(Duration.zero);
  }

  Future<void> _bindPlayerStreams() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _completeSub?.cancel();

    _positionSub = _player.onPositionChanged.listen((pos) async {
      final loopEnd = getDurationLoopEnd();
      final loopStart = getDurationLoopStart();
      if (loopEnd != null && loopStart != null && pos >= loopEnd) {
        await _player.seek(loopStart);
        pos = loopStart;
      }
      playerPositionStore.changePlayerPosition(pos);
    });

    _durationSub = _player.onDurationChanged.listen((event) {
      if (_currentLength == event) return;
      _currentLength = event;
      if (_audioFile != null) {
        setDuration(Tuple2(_audioFile!, event));
      }
      notifyListeners();
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      stopAction();
    });
  }

  Future<void> startPlayer(String path) async {
    await _bindPlayerStreams();
    _state = RecorderState.playing;
    await _player.play(DeviceFileSource(path));
    notifyListeners();
  }

  Future<bool> _initRecorder() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  RecordConfig _recordConfig() {
    // Prefer AAC for iOS compatibility. Use WAV elsewhere if selected.
    if (_audioFormat == AudioFormat.wav && !Platform.isIOS) {
      return const RecordConfig(encoder: AudioEncoder.wav);
    }
    return const RecordConfig(encoder: AudioEncoder.aacLc);
  }

  Future<bool> startRecorder(String path) async {
    if (!await _initRecorder()) return false;
    await _recorder.start(_recordConfig(), path: path);
    _recordStartedAt = DateTime.now();
    _recordTicker?.cancel();
    _recordTicker = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final current = await _recorder.getAmplitude();
      final elapsed = _recordStartedAt == null
          ? Duration.zero
          : DateTime.now().difference(_recordStartedAt!);
      recorderPositionStore.changeRecorderPosition(elapsed);
      if (current.current.isNaN) {
        // keep ticker alive while recording; no-op
      }
    });
    return true;
  }

  Future<void> stopRecorder() async {
    final path = await _recorder.stop();
    _recordTicker?.cancel();
    _recordStartedAt = null;
    final elapsed = recorderPositionStore.position;
    _recordTime = elapsed;
    recorderPositionStore.changeRecorderPosition(Duration.zero);
    if (path != null) {
      _currentPath = path;
      _recordingFinishedController
          .add(AudioFile(duration: elapsed, path: path));
    }
  }

  Future<String> getFilename() async {
    var d = await getApplicationDocumentsDirectory();
    d = Directory(p.join(d.path, 'files'));
    if (!d.existsSync()) {
      d.createSync(recursive: true);
    }
    final date = DateTime.now().toIso8601String().replaceAll(':', '-');
    final ext = (_audioFormat == AudioFormat.wav && !Platform.isIOS)
        ? 'wav'
        : 'm4a';
    return p.join(d.path, '$date.$ext');
  }

  Future<void> startPlaybackAction(AudioFile f) async {
    if (_state == RecorderState.stop || _state == RecorderState.pausing) {
      playerPositionStore.changePlayerPosition(Duration.zero);
      _audioFile = f;
      _currentPath = f.path;
      _loopRange = f.loopRange;
      await startPlayer(f.path);
    }
  }

  Future<void> stopAction([dynamic _]) async {
    _loopRange = null;
    if (_state == RecorderState.playing || _state == RecorderState.pausing) {
      await _stopPlayerInternal();
      _state = RecorderState.stop;
      notifyListeners();
      return;
    }
    if (_state == RecorderState.recording) {
      await stopRecorder();
      _state = RecorderState.stop;
      notifyListeners();
    }
  }

  Future<void> startRecordingAction([dynamic _]) async {
    final path = await getFilename();
    _currentPath = path;
    final hasPermissions = await startRecorder(path);
    if (hasPermissions) {
      _state = RecorderState.recording;
      notifyListeners();
    }
  }

  Future<void> skipTo(Duration d) async {
    await _player.seek(d);
    notifyListeners();
  }

  Future<void> pauseAction([dynamic _]) async {
    await _player.pause();
    _state = RecorderState.pausing;
    notifyListeners();
  }

  Future<void> resumeAction([dynamic _]) async {
    await _player.resume();
    _state = RecorderState.playing;
    notifyListeners();
  }

  void resetRecorderState([dynamic _]) {
    _state = RecorderState.stop;
    notifyListeners();
  }

  void setRecorderState(RecorderState s) {
    _state = s;
    notifyListeners();
  }

  void setAudioFormat(AudioFormat format) {
    _audioFormat = format;
    notifyListeners();
  }

  Future<void> setLoopRange(RangeValues range) async {
    if (_loopRange == null || range.start != _loopRange!.start) {
      final start = Duration(milliseconds: (range.start * 1000).floor());
      await _player.seek(start);
    }
    _loopRange = range;
    notifyListeners();
  }

  @override
  void dispose() {
    _recordTicker?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _recordingFinishedController.close();
    _player.dispose();
    super.dispose();
  }
}

final PlayerPositionStore playerPositionStore = PlayerPositionStore();
final RecorderPositionStore recorderPositionStore = RecorderPositionStore();
final RecorderBottomSheetStore recorderBottomSheetStore = RecorderBottomSheetStore();

void changePlayerPosition(Duration event) =>
    playerPositionStore.changePlayerPosition(event);
void changeRecorderPosition(Duration event) =>
    recorderPositionStore.changeRecorderPosition(event);
Future<void> startRecordingAction([dynamic _]) =>
    recorderBottomSheetStore.startRecordingAction();
Future<void> startPlaybackAction(AudioFile f) =>
    recorderBottomSheetStore.startPlaybackAction(f);
void setRecorderState(RecorderState s) => recorderBottomSheetStore.setRecorderState(s);
void setPath(String path) {}
Future<void> stopAction([dynamic _]) => recorderBottomSheetStore.stopAction();
Future<void> pauseAction([dynamic _]) => recorderBottomSheetStore.pauseAction();
Future<void> resumeAction([dynamic _]) => recorderBottomSheetStore.resumeAction();
void setElapsed(Duration d) {}
Future<void> skipTo(Duration d) => recorderBottomSheetStore.skipTo(d);
void recordingFinished(AudioFile f) =>
    recorderBottomSheetStore.onRecordingFinished.listen((_) {}).cancel();
void resetRecorderState([dynamic _]) => recorderBottomSheetStore.resetRecorderState();
Future<void> setLoopRange(RangeValues range) =>
    recorderBottomSheetStore.setLoopRange(range);
void setAudioFormat(AudioFormat format) => recorderBottomSheetStore.setAudioFormat(format);
