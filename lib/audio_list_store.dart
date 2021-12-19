import 'package:flutter_flux/flutter_flux.dart' show Action, Store, StoreToken;
import 'package:sound/local_storage.dart';
import 'package:sound/model.dart';

class AudioListStore extends Store {
  // default values

  AudioListStore() {
    // init listener
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
  }
}

Action<AudioFile> addAudioIdea = Action<AudioFile>();
Action<AudioFile> deleteAudioIdea = Action<AudioFile>();
Action<AudioFile> toggleStarredAudioIdea = Action<AudioFile>();

StoreToken audioListToken = StoreToken(AudioListStore());
