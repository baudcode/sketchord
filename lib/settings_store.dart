import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';

class SettingsStore extends Store {
  SettingsTheme _theme = SettingsTheme.dark;

  // getters
  SettingsTheme get theme => _theme;

  String _audioFormat = "aac";
  String _view = 'single';

  Settings get settings =>
      Settings(audioFormat: _audioFormat, theme: _theme, view: _view);

  SettingsStore() {
    // init listener
    toggleTheme.listen((_) async {
      if (theme == SettingsTheme.dark) {
        _theme = SettingsTheme.light;
      } else {
        _theme = SettingsTheme.dark;
      }
      await LocalStorage().syncSettings(settings);
      trigger();
    });

    setDefaultAudioFormat.listen((format) async {
      _audioFormat = format;
      await LocalStorage().syncSettings(settings);
      trigger();
    });

    setDefaultView.listen((view) async {
      _view = view;
      await LocalStorage().syncSettings(settings);
      trigger();
    });

    updateSettings.listen((s) {
      if (s != null) {
        _theme = s.theme;
        _view = s.view;
        _audioFormat = s.audioFormat;
        trigger();
      }
    });
  }
}

Action toggleTheme = Action();
Action<String> setDefaultView = Action();
Action<String> setDefaultAudioFormat = Action();
Action<Settings> updateSettings = Action();

StoreToken settingsToken = StoreToken(SettingsStore());
