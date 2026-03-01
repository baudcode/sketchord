import 'package:flutter/foundation.dart';
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';

class SettingsStore extends ChangeNotifier {
  Settings _settings = Settings(
    audioFormat: AudioFormat.wav,
    theme: SettingsTheme.dark,
    name: '',
    view: EditorView.single,
  );

  SettingsTheme get theme => _settings.theme;
  EditorView get view => _settings.view;
  AudioFormat get audioFormat => _settings.audioFormat;
  String? get name => _settings.name;
  Settings get settings => _settings;

  Future<void> toggleTheme() async {
    _settings.theme = _settings.theme == SettingsTheme.dark
        ? SettingsTheme.light
        : SettingsTheme.dark;
    await LocalStorage().syncSettings(_settings);
    notifyListeners();
  }

  Future<void> setDefaultAudioFormat(AudioFormat format) async {
    _settings.audioFormat = format;
    await LocalStorage().syncSettings(_settings);
    notifyListeners();
  }

  Future<void> setDefaultView(EditorView view) async {
    _settings.view = view;
    await LocalStorage().syncSettings(_settings);
    notifyListeners();
  }

  Future<void> setName(String name) async {
    _settings.name = name;
    await LocalStorage().syncSettings(_settings);
    notifyListeners();
  }

  void updateSettings(Settings? settings) {
    if (settings == null) return;
    _settings = settings;
    notifyListeners();
  }
}

final SettingsStore settingsStore = SettingsStore();

Future<void> toggleTheme([dynamic _]) => settingsStore.toggleTheme();
Future<void> setName(String name) => settingsStore.setName(name);
Future<void> setDefaultView(EditorView view) => settingsStore.setDefaultView(view);
Future<void> setDefaultAudioFormat(AudioFormat format) =>
    settingsStore.setDefaultAudioFormat(format);
void updateSettings(Settings? settings) => settingsStore.updateSettings(settings);
