import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';
import 'package:tuple/tuple.dart';

class AudioListStore extends Store {
  // default values

  String _search;
  bool _searching;

  bool get isSearching => _searching;
  String get search => _search;

  AudioListStore() {
    // init listener
    _searching = false;

    addAudioIdea.listen((AudioFile f) async {
      int row = await LocalStorage().addAudioIdea(f);
      print("Added audio file row $row");
      trigger();
    });

    deleteAudioIdea.listen((AudioFile f) async {
      await LocalStorage().deleteAudioIdea(f);
      trigger();
    });

    toggleStarredAudioIdea.listen((AudioFile f) async {
      f.starred = !f.starred;
      await LocalStorage().syncAudioFile(f);
      trigger();
    });

    renameAudioIdea.listen((Tuple2<AudioFile, String> r) async {
      r.item1.name = r.item2;
      await LocalStorage().syncAudioFile(r.item1);
      trigger();
    });

    setSearchAudioIdeas.listen((s) {
      _search = s;
      trigger();
    });
    toggleAudioIdeasSearch.listen((s) {
      _searching = !_searching;
      _search = "";
      trigger();
    });
  }
}

Action<AudioFile> addAudioIdea = Action<AudioFile>();
Action<AudioFile> deleteAudioIdea = Action<AudioFile>();
Action<String> setSearchAudioIdeas = Action<String>();
Action<bool> toggleAudioIdeasSearch = Action<bool>();
Action<AudioFile> toggleStarredAudioIdea = Action<AudioFile>();
Action<Tuple2<AudioFile, String>> renameAudioIdea =
    Action<Tuple2<AudioFile, String>>();

StoreToken audioListToken = StoreToken(AudioListStore());
