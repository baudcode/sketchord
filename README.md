# sound

## On-device audio-to-MIDI

Every audio clip has a music-note button. It opens a model selector in the
same order as the product research: Basic Pitch, CREPE tiny/full, PESTO,
SwiftF0, SPICE, aubio YIN-compatible, then pYIN-compatible. A successful
transcription writes a standard `.mid` file, which can be shared from the
dialog. The same dialog can audition the exported notes through the bundled
2.1 MB Grand Piano SoundFont on Android and iOS.

The bundled SoundFont attribution and checksum are in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

The lightweight YIN and pYIN-compatible options run entirely in Dart. Imported
AAC/M4A/MP3 clips are converted through the Android/iOS media stack to a
temporary PCM WAV before every runner is invoked. Basic Pitch uses a pinned
upstream artifact. CREPE tiny/full, PESTO, SwiftF0, and SPICE need a reviewed
artifact in the app's HTTPS manifest: CREPE/PESTO have no compatible canonical
mobile graph, SwiftF0's published graph requires unsupported ONNX Runtime
operators, and the TF Hub SPICE graph requires unsupported Select-TF operators.
Neural artifacts download only after the user selects a model. Configure that
manifest with:

```sh
flutter run --flavor dev \
  --dart-define=MODEL_MANIFEST_URL=https://models.example.com/sketchord/models.json
```

The manifest is controlled by us rather than hard-coding third-party release
URLs, so each distributed artifact can be converted for its target runtime,
versioned, licence-reviewed, and checksum-pinned. Its contract is:

```json
{
  "models": {
    "basicPitch": {
      "id": "basic-pitch", "version": "1.0.0",
      "url": "https://models.example.com/basic-pitch-1.0.0.tflite",
      "fileName": "basic_pitch.tflite",
      "sha256": "lowercase-hex-sha256"
    }
  }
}
```

Downloads are written below the application-support directory and verified
before use. The runners consume decoded PCM in Dart and execute their TFLite
or ONNX model on device. The PESTO, SwiftF0, and SPICE artifact requirements
are documented in [`docs/pesto_model_artifact.md`](docs/pesto_model_artifact.md),
[`docs/swiftf0_model_artifact.md`](docs/swiftf0_model_artifact.md), and
[`docs/spice_model_artifact.md`](docs/spice_model_artifact.md).

flutter run --flavor prod
flutter run --flavor dev

# flutter run --flavor dev -d chrome --web-renderer html
# flutter packages pub run flutter_launcher_icons:main -f pubspec.yaml

# Create Release
1. Change Version
2. Build bundle `flutter build appbundle --flavor prod`

# CI/CD Release

A GitHub Actions workflow is defined at `.github/workflows/release-main.yml`.

On every push to `main`, it:

1. Builds Flutter artifacts for Android, Linux, macOS, and iOS (`--no-codesign` for iOS).
2. Builds standalone backend binaries with PyInstaller for Linux and macOS.
3. Publishes a GitHub Release named `Main build #<run_number>` and uploads all artifacts.
