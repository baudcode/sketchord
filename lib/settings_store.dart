import 'package:flutter_audio_recorder/flutter_audio_recorder.dart';
import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:sound/note_list.dart';
import 'package:sound/recorder_store.dart';

class SettingsStore extends Store {
  // default values

  Settings _settings = Settings.defaults();

  // getter
  SettingsTheme get theme => _settings.theme;

  EditorView get editorView => _settings.editorView;

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

    setDefaultNoteListType.listen((listType) async {
      _settings.noteListType = listType;
      await LocalStorage().syncSettings(_settings);
      trigger();
    });

    setDefaultEditorView.listen((view) async {
      _settings.editorView = view;
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
        print("Update Settings in store");
        trigger();
      }
    });

    changeSectionContentFontSize.listen((value) async {
      _settings.sectionContentFontSize = value;
      await LocalStorage().syncSettings(_settings);
      trigger();
    });
  }
}

Action toggleTheme = Action();
Action<String> setName = Action();

Action<NoteListType> setDefaultNoteListType = Action();
Action<EditorView> setDefaultEditorView = Action();
Action<AudioFormat> setDefaultAudioFormat = Action();
Action<double> changeSectionContentFontSize = Action();
Action<Settings> updateSettings = Action();
Action<SortDirection> setDefaultSortDirection = Action();
Action<SortBy> setDefaultSortBy = Action();

StoreToken settingsToken = StoreToken(SettingsStore());
