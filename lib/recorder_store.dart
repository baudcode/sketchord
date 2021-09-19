import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' show RangeValues;
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:flutter_flux/flutter_flux.dart' show Store, Action, StoreToken;
// import 'package:video_player/video_player.dart';
// import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound/editor_store.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/settings_store.dart';
import 'package:sound/utils.dart';
import 'package:tuple/tuple.dart';
import 'dart:async';
import 'model.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
//import 'package:audio_recorder/audio_recorder.dart';

// https://github.com/ZaraclaJ/audio_recorder

enum RecorderState { STOP, RECORDING, PLAYING, PAUSING }

class PlayerPositionStore extends Store {
  Duration _position = Duration(seconds: 0);

  Duration get position => _position;

  PlayerPositionStore() {
    changePlayerPosition.listen((event) {
      _position = event;
      trigger();
    });
  }
}

Action<Duration> changePlayerPosition = Action();
StoreToken playerPositionStoreToken = StoreToken(PlayerPositionStore());

class RecorderPositionStore extends Store {
  Duration _position = Duration(seconds: 0);

  Duration get position => _position;

  RecorderPositionStore() {
    changeRecorderPosition.listen((event) {
      _position = event;
      trigger();
    });
  }
}

Action<Duration> changeRecorderPosition = Action();
StoreToken recorderPositionStoreToken = StoreToken(RecorderPositionStore());

class RecorderBottomSheetStore extends Store {
  //VideoPlayerController _controller;
  RecordingStatus _currentStatus = RecordingStatus.Unset;
  AudioPlayer _player = AudioPlayer();
  AudioFormat _audioFormat = AudioFormat.WAV;

  Recording _current;
  FlutterAudioRecorder _recorder;
  Duration _currentLength; // length of the current audio file

  // recorder
  RecorderState _state = RecorderState.STOP;
  String _currentPath;

  bool _minimized;
  bool get minimized => _minimized;

  Duration _recordTime;
  Duration get recordTime => _recordTime;

  RangeValues get loopRange => _audioFile == null ? null : _audioFile.loopRange;

  // getters
  RecorderState get state => _state;
  RecordingStatus get status => _currentStatus;
  Duration get currentLength => _currentLength;
  String get stateString => _state.toString();
  String get currentPath => _currentPath;

  AudioFile _audioFile;
  AudioFile get currentAudioFile => _audioFile;
  AudioFormat get audioFormat => _audioFormat;
  AudioPlayer get player => _player;

  bool get isLooping => (loopRange != null);

  getDurationLoopEnd() {
    if (loopRange == null) return null;
    return Duration(milliseconds: (loopRange.end * 1000).floor());
  }

  getDurationLoopStart() {
    if (loopRange == null) return null;
    return Duration(milliseconds: (loopRange.start * 1000).floor());
  }

  Future<int> stopPlayer(bool force) async {
    if (this.loopRange != null && !force) {
      print("stop player with loop range: $loopRange");
      _state = RecorderState.PLAYING;
      await _player.play(_currentPath,
          isLocal: true, position: getDurationLoopStart());
      print("seek to start");
      return -10;
    } else {
      int res = await _player.stop();
      changePlayerPosition(Duration(seconds: 0));
      return res;
    }
  }

  Future<int> startPlayer(String path) async {
    print("playing $path");
    // set length not yet available

    _player.onAudioPositionChanged.listen((pos) async {
      if (loopRange != null && pos >= getDurationLoopEnd()) {
        pos = getDurationLoopStart();
        await _player.seek(pos);
        print("seek to start...");
      }
      changePlayerPosition(pos);
    });

    _player.onDurationChanged.listen((event) {
      if (_currentLength != event) {
        setDuration(Tuple2(_audioFile, event));
        _currentLength = event;
        trigger();
      }
    });

    _state = RecorderState.PLAYING;
    _player.onPlayerStateChanged.listen((AudioPlayerState event) async {
      print("player state change $event");
    });

    _player.onPlayerCompletion.listen((event) async {
      print("player completed");
      stopAction(false);
    });

    print("play me");
    Duration startPosition =
        (loopRange == null) ? Duration(seconds: 0) : getDurationLoopStart();
    int result =
        await _player.play(path, isLocal: true, position: startPosition);
    trigger();
    return result;
  }

  Future<bool> init(String path) async {
    try {
      if (await Permission.microphone.request().isGranted) {
        _recorder = FlutterAudioRecorder(path, audioFormat: _audioFormat);
        await _recorder.initialized;

        // after initialization
        _current = await _recorder.current(channel: 0);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("ERRROR!");
      print(e);
      return false;
    }
  }

  Future<bool> startRecorder(String path) async {
    // Check permissions before starting
    print("init...");
    print("starting recorder $path");

    // Check permissions before starting
    bool hasPermissions = await init(path);

    print("has permissions: $hasPermissions");

    if (!hasPermissions) {
      return false;
    }

    await _recorder.start();
    _current = await _recorder.current(channel: 0);
    _currentStatus = _current.status;

    const tick = const Duration(milliseconds: 50);

    new Timer.periodic(tick, (Timer t) async {
      if (_currentStatus == RecordingStatus.Stopped) {
        t.cancel();
      }

      var current = await _recorder.current(channel: 0);
      // print(current.status);
      if (_currentStatus != current.status) {
        _currentStatus = current.status;
        _current = current;

        trigger();
      }

      changeRecorderPosition(current.duration);
    });

    return true;
  }

  Future<String> stopRecorder() async {
    print("stopping...");
    if (_currentStatus != RecordingStatus.Unset) {
      var result = await _recorder.stop();
      // reuslt.path, result.duration
      print("Stop recording: ${result.path}");
      print("Stop recording: ${result.duration}");
      _recordTime = result.duration;
      _current = result;
      changeRecorderPosition(Duration(seconds: 0));
    }

    return "";
  }

  Future<String> getFilename() async {
    var d = (await getApplicationDocumentsDirectory()).parent;
    d = Directory(p.join(d.path, 'files'));

    String ext = _audioFormat == AudioFormat.WAV ? "wav" : "aac";
    return d.path + '/' + getFormattedDate(DateTime.now()) + ".$ext";
  }

  RecorderBottomSheetStore() {
    _minimized = false;

    LocalStorage().getSettings().then((value) {
      if (value != null) {
        _audioFormat = value.audioFormat;
      }
    });
    // sound = FlutterSound();
    startPlaybackAction.listen((AudioFile f) async {
      if (_state == RecorderState.PLAYING) {
        await stopPlayer(true);
        _state = RecorderState.STOP;
      }
      if (_state == RecorderState.STOP || _state == RecorderState.PAUSING) {
        changePlayerPosition(Duration(seconds: 0));
        _audioFile = f;
        _currentPath = f.path;
        print("Init Audio file with Loop Range: ${f.loopRange}");

        startPlayer(f.path).then((t) {
          //   _state = RecorderState.PLAYING;
          // trigger();
        });
      }
    });

    stopAction.listen((force) {
      if (_state == RecorderState.RECORDING ||
          _state == RecorderState.PLAYING ||
          _state == RecorderState.PAUSING) {
        if (_state == RecorderState.PLAYING ||
            _state == RecorderState.PAUSING) {
          stopPlayer(force).then((r) {
            if (r != -10) {
              _state = RecorderState.STOP;
              trigger();
            }
          });
        } else {
          stopRecorder().then((_) {
            _state = RecorderState.STOP;
            recordingFinished(
                AudioFile(duration: _recordTime, path: currentPath));
          });
        }
      }
    });

    startRecordingAction.listen((_) {
      getFilename().then((path) {
        _currentPath = path;

        void start() {
          startRecorder(path).then((hasPermissions) {
            if (hasPermissions) {
              _state = RecorderState.RECORDING;
              trigger();
            } else {
              audioRecordingPermissionDenied();
            }
          });
        }

        start();
      });
    });

    skipTo.listen((d) async {
      print("seeking to $d");
      await _player.seek(d);
      trigger();
    });

    pauseAction.listen((_) async {
      await _player.pause();
      _state = RecorderState.PAUSING;
      trigger();
    });
    resumeAction.listen((_) async {
      await _player.resume();
      _state = RecorderState.PLAYING;
      trigger();
    });

    resetRecorderState.listen((_) {
      //_currentPath = null;
      _state = RecorderState.STOP;
      trigger();
    });

    setRecorderState.listen((s) {
      _state = s;
      trigger();
    });

    setAudioFormat.listen((format) {
      _audioFormat = format;
      print("setting audio format to $_audioFormat");
      trigger();
    });

    setLoopRange.listen((range) async {
      print("SetLoopRange $range $loopRange $_state");
      if (range != null &&
          (loopRange == null ||
              (loopRange != null && range.start != loopRange.start))) {
        if (_state == RecorderState.PLAYING) {
          print("seeking to start of range");
          var start = Duration(milliseconds: (range.start * 1000).floor());
          await _player.seek(start);
        }
      }
      print("New Loop Range: $range");
      if (this._audioFile != null) {
        _audioFile.loopRange = range;
        trigger();
      }
    });

    setMinimized.listen((m) {
      print("set minimized internal: $m");
      if (m != minimized) {
        _minimized = m;
        trigger();
      }
    });

    setDefaultAudioFormat.listen((format) {
      _audioFormat = format;
      print("ping");
      trigger();
    });
    print("editor store created");
  }
}

Action<String> startRecordingAction = Action();
Action<AudioFile> startPlaybackAction = Action();

Action<RecorderState> setRecorderState = Action();
Action<String> setPath = Action();
Action<bool> stopAction = Action();
Action pauseAction = Action();
Action resumeAction = Action();
Action<Duration> setElapsed = Action();
Action<Duration> skipTo = Action();
Action<AudioFile> recordingFinished = Action();
Action resetRecorderState = Action();
Action<RangeValues> setLoopRange = Action();
Action<AudioFormat> setAudioFormat = Action();
Action<bool> setMinimized = Action();
Action audioRecordingPermissionDenied = Action();

StoreToken recorderBottomSheetStoreToken =
    StoreToken(RecorderBottomSheetStore());
