import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:flutter_flux/flutter_flux.dart' show Store, Action, StoreToken;
// import 'package:video_player/video_player.dart';
// import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'model.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
//import 'package:audio_recorder/audio_recorder.dart';

// https://github.com/ZaraclaJ/audio_recorder

enum RecorderState { STOP, RECORDING, PLAYING, PAUSING }

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
  Duration _elapsed;

  // getters
  RecorderState get state => _state;
  RecordingStatus get status => _currentStatus;
  Duration get currentLength => _currentLength;
  String get stateString => _state.toString();
  Duration get elapsed => _elapsed;
  String get currentPath => _currentPath;
  AudioFormat get audioFormat => _audioFormat;

  Future<int> stopPlayer() async {
    return await _player.stop();
  }

  Future<int> startPlayer(String path) async {
    print("playing $path");

    // set length not yet available
    _currentLength = null;
    trigger();

    _player.onDurationChanged.listen((d) {
      _currentLength = d;
      trigger();
    });

    _player.onAudioPositionChanged.listen((event) {
      _elapsed = event;
      trigger();
    });

    _player.onPlayerStateChanged.listen((AudioPlayerState event) {
      print("player state change $event");
    });

    _player.onPlayerCompletion.listen((event) {
      print("player completed");
      _state = RecorderState.STOP;
      trigger();
    });

    int result = await _player.play(path, isLocal: true);
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
      _currentStatus = current.status;
      _current = current;
      _elapsed = current.duration;
      print("update to ${current.duration.inSeconds}");
      trigger();
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
      _elapsed = result.duration;
      _current = result;
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
    startPlaybackAction.listen((path) {
      if (_state == RecorderState.STOP || _state == RecorderState.PAUSING) {
        _elapsed = null;
        _currentPath = path;
        startPlayer(path).then((t) {
          _state = RecorderState.PLAYING;
          trigger();
        });
      }
    });

    stopAction.listen((_) {
      if (_state == RecorderState.RECORDING ||
          _state == RecorderState.PLAYING ||
          _state == RecorderState.PAUSING) {
        _elapsed = Duration(microseconds: 0);
        if (_state == RecorderState.PLAYING) {
          stopPlayer();
          _state = RecorderState.STOP;
          trigger();
        } else {
          stopRecorder().then((_) {
            _state = RecorderState.STOP;
            recordingFinished(AudioFile(duration: elapsed, path: currentPath));
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

    setElapsed.listen((e) {
      _elapsed = e;
      trigger();
    });

    skipTo.listen((d) async {
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

    toggleAudioFormat.listen((event) {
      if (_audioFormat == AudioFormat.WAV) {
        _audioFormat = AudioFormat.AAC;
      } else {
        _audioFormat = AudioFormat.WAV;
      }
      print("setting audio format to $_audioFormat");
      trigger();
    });
  }
}

Action<String> startRecordingAction = Action();
Action<String> startPlaybackAction = Action();

Action<RecorderState> setRecorderState = Action();
Action<String> setPath = Action();
Action stopAction = Action();
Action pauseAction = Action();
Action resumeAction = Action();
Action<Duration> setElapsed = Action();
Action<Duration> skipTo = Action();
Action<AudioFile> recordingFinished = Action();
Action resetRecorderState = Action();

StoreToken recorderBottomSheetStoreToken =
    StoreToken(RecorderBottomSheetStore());

Action toggleAudioFormat = Action<AudioFormat>();
