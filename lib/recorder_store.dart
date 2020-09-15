import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' show RangeValues;
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:flutter_flux/flutter_flux.dart' show Store, Action, StoreToken;
// import 'package:video_player/video_player.dart';
// import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound/settings_store.dart';
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

  Duration _recordTime;
  Duration get recordTime => _recordTime;

  RangeValues _loopRange;
  RangeValues get loopRange => _loopRange;

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

  getDurationLoopEnd() {
    if (_loopRange == null) return null;
    return Duration(milliseconds: (_loopRange.end * 1000).floor());
  }

  getDurationLoopStart() {
    if (_loopRange == null) return null;
    return Duration(milliseconds: (_loopRange.start * 1000).floor());
  }

  Future<int> stopPlayer() async {
    int res = await _player.stop();
    changePlayerPosition(Duration(seconds: 0));
    return res;
  }

  Future<int> startPlayer(String path) async {
    print("playing $path");
    // set length not yet available

    _player.onAudioPositionChanged.listen((pos) async {
      if (_loopRange != null && pos >= getDurationLoopEnd()) {
        pos = getDurationLoopStart();
        await _player.seek(pos);
      }
      changePlayerPosition(pos);
    });

    _player.onDurationChanged.listen((event) {
      if (_currentLength != event) {
        _currentLength = event;
        trigger();
      }
    });

    _state = RecorderState.PLAYING;
    _player.onPlayerStateChanged.listen((AudioPlayerState event) {
      print("player state change $event");
    });

    _player.onPlayerCompletion.listen((event) {
      print("player completed");
      stopAction();
    });

    print("play me");
    int result = await _player.play(path, isLocal: true);
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
        print("update to ${current.duration.inSeconds}");
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

    String date = DateTime.now().toString();
    String ext = _audioFormat == AudioFormat.WAV ? "wav" : "aac";
    return d.path +
        '/' +
        DateTime.now()
            .toString()
            .substring(0, date.length - 7)
            .replaceAll(":", "-") +
        ".$ext";
  }

  RecorderBottomSheetStore() {
    // sound = FlutterSound();
    startPlaybackAction.listen((AudioFile f) {
      if (_state == RecorderState.STOP || _state == RecorderState.PAUSING) {
        changePlayerPosition(Duration(seconds: 0));
        _audioFile = f;
        _currentPath = f.path;
        _loopRange = f.loopRange;
        print("Loop Range: $_loopRange");

        startPlayer(f.path).then((t) {
          //   _state = RecorderState.PLAYING;
          // trigger();
        });
      }
    });

    stopAction.listen((_) {
      _loopRange = null;
      if (_state == RecorderState.RECORDING ||
          _state == RecorderState.PLAYING ||
          _state == RecorderState.PAUSING) {
        if (_state == RecorderState.PLAYING ||
            _state == RecorderState.PAUSING) {
          stopPlayer();
          _state = RecorderState.STOP;
          trigger();
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
              //start();
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
      print("$range, $_loopRange");

      if (_loopRange == null ||
          (_loopRange != null && range.start != _loopRange.start)) {
        var start = Duration(milliseconds: (range.start * 1000).floor());
        await _player.seek(start);
      }
      _loopRange = range;
      trigger();
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
Action stopAction = Action();
Action pauseAction = Action();
Action resumeAction = Action();
Action<Duration> setElapsed = Action();
Action<Duration> skipTo = Action();
Action<AudioFile> recordingFinished = Action();
Action resetRecorderState = Action();
Action<RangeValues> setLoopRange = Action();
Action<AudioFormat> setAudioFormat = Action();

StoreToken recorderBottomSheetStoreToken =
    StoreToken(RecorderBottomSheetStore());
