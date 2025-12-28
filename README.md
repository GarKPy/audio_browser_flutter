# Audio Browser Flutter

A lightweight Flutter component for browsing and selecting audio files from local storage and SD cards.

## Key Features
- **Storage Discovery**: Automatically detects internal storage and SD cards on Android.
- **Permission Management**: Built-in handling for `MANAGE_EXTERNAL_STORAGE` permissions to ensure full access.
- **Audio Filtering**: Automatically filters for common audio formats (.mp3, .wav, .flac, .m4a, etc.).
- **Riverpod State Management**: Uses Riverpod for efficient and clean state handling.
- **Minimalist UI**: Simple, fast, and responsive folder navigation.

## Core Files
- `main.dart`: Application entry point and theme configuration.
- `file_browser.dart`: The UI widget for browsing files.
- `file_browser_provider.dart`: Business logic and state management.
- `pubspec.yaml`: Project dependencies.
