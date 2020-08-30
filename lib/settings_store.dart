import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;

enum SettingsTheme { dark, light }

class SettingsStore extends Store {
  SettingsTheme _theme = SettingsTheme.dark;

  // getters
  SettingsTheme get theme => _theme;

  SettingsStore() {
    // init listener
    toggleTheme.listen((_) {
      if (theme == SettingsTheme.dark) {
        _theme = SettingsTheme.light;
      } else {
        _theme = SettingsTheme.dark;
      }
      trigger();
    });
  }
}

// export, import (zip)
// export specifc song (json)
// import specific song (json)
// theme: dark/light
// default NoteView (tile, list)
Action toggleTheme = Action();
Action setDefaultModeView = Action();

StoreToken settingsToken = StoreToken(SettingsStore());
