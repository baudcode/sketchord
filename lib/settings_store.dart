import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/recorder_store.dart';

class SettingsStore extends Store {
  // default values

  Settings _settings = Settings(
      audioFormat: AudioFormat.WAV,
      theme: SettingsTheme.dark,
      name: null,
      view: EditorView.single);

  // getter
  SettingsTheme get theme => _settings.theme;

  EditorView get view => _settings.view;

  AudioFormat get audioFormat => _settings.audioFormat;
  String get name => _settings.name;

  Settings get settings => _settings;

  SettingsStore() {
    // init listener
    toggleTheme.listen((_) async {
      if (theme == SettingsTheme.dark) {
        _settings.theme = SettingsTheme.light;
      } else {
        _settings.theme = SettingsTheme.dark;
      }
      await LocalStorage().syncSettings(settings);
      trigger();
    });

    setDefaultAudioFormat.listen((format) async {
      _settings.audioFormat = format;
      await LocalStorage().syncSettings(_settings);
      trigger();
    });

    setDefaultView.listen((view) async {
      _settings.view = view;
      await LocalStorage().syncSettings(_settings);
      trigger();
    });

    setDefaultSortBy.listen((SortBy by) async {
      _settings.sortBy = by;
      await LocalStorage().syncSettings(_settings);
      trigger();
    });

    setDefaultSortDirection.listen((SortDirection d) async {
      _settings.sortDirection = d;
      await LocalStorage().syncSettings(_settings);
      trigger();
    });

    setName.listen((name) async {
      _settings.name = name;
      await LocalStorage().syncSettings(_settings);
      trigger();
    });

    // this will be called when the app initializes
    updateSettings.listen((s) {
      if (s != null) {
        _settings = s;
        print("settings audio format");
        trigger();
      }
    });
  }
}

Action toggleTheme = Action();
Action<String> setName = Action();

Action<EditorView> setDefaultView = Action();
Action<AudioFormat> setDefaultAudioFormat = Action();
Action<Settings> updateSettings = Action();
Action<SortDirection> setDefaultSortDirection = Action();
Action<SortBy> setDefaultSortBy = Action();

StoreToken settingsToken = StoreToken(SettingsStore());
