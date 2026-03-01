# sound

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
