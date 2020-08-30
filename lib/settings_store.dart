import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;

enum SettingsTheme { dark, light }

class SettingsStore extends Store {
  SettingsTheme theme = SettingsTheme.dark;

  SettingsStore() {
    // init listener
    toggleTheme.listen((note) {
      if (theme == SettingsTheme.dark) {
        theme = SettingsTheme.light;
      } else {
        theme = SettingsTheme.dark;
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
