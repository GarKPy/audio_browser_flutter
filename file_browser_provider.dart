import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileBrowserItem {
  final String path;
  final String name;
  final bool isDirectory;
  final bool isPinned;
  final bool isPrimary;

  FileBrowserItem({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.isPinned = false,
    required this.isPrimary,
  });
}

class FileBrowserState {
  final String? rootPath;
  final String currentPath;
  final List<FileBrowserItem> items;
  final bool isLoading;
  final String? error;
  final bool isRootScreen;
  final List<FileBrowserItem> storages;

  FileBrowserState({
    this.rootPath,
    this.currentPath = "",
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.isRootScreen = true,
    this.storages = const [],
  });

  FileBrowserState copyWith({
    String? rootPath,
    String? currentPath,
    List<FileBrowserItem>? items,
    bool? isLoading,
    String? error,
    bool? isRootScreen,
    List<FileBrowserItem>? storages,
  }) {
    return FileBrowserState(
      rootPath: rootPath ?? this.rootPath,
      currentPath: currentPath ?? this.currentPath,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isRootScreen: isRootScreen ?? this.isRootScreen,
      storages: storages ?? this.storages,
    );
  }
}

class FileBrowserNotifier extends StateNotifier<FileBrowserState> {
  FileBrowserNotifier() : super(FileBrowserState());

  Future<void> init() async {
    state = state.copyWith(isLoading: true);

    final storages = await _getStorageVolumes();

    state = state.copyWith(
      storages: storages,
      isLoading: false,
      isRootScreen: true,
      items: storages,
    );
  }

  // ---------- PERMISSIONS ----------
  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    // Request permission
    status = await Permission.manageExternalStorage.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return status.isGranted;
  }

  Future<List<FileBrowserItem>> _getStorageVolumes() async {
    final List<FileBrowserItem> result = [];
    final Set<String> added = {};

    // ---------- METHOD 1: Official API ----------
    try {
      final dirs = await getExternalStorageDirectories();
      if (dirs != null) {
        for (final dir in dirs) {
          final parts = dir.path.split('/');
          if (parts.length >= 4 && parts[1] == "storage") {
            final root = "/storage/${parts[2]}";

            if (!added.contains(root)) {
              added.add(root);
              final isPrimary = root == "/storage/emulated";
              result.add(
                FileBrowserItem(
                  path: isPrimary ? "/storage/emulated/0" : root,
                  name: isPrimary ? "Internal Storage" : "SD Card",
                  isPrimary: isPrimary,
                  isDirectory: true,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // ---------- METHOD 2: Raw /storage scan ----------
    try {
      final storageDir = Directory("/storage");
      if (await storageDir.exists()) {
        final entities = storageDir.listSync(
          recursive: false,
          followLinks: false,
        );

        for (final e in entities) {
          final name = p.basename(e.path);

          if (name == "emulated" || name == "self" || name == "sdcard0") {
            continue;
          }

          final isUuid = RegExp(
            r'^[0-9A-F]{4}-[0-9A-F]{4}$',
            caseSensitive: false,
          ).hasMatch(name);

          if (isUuid && !added.contains(e.path)) {
            added.add(e.path);
            result.add(
              FileBrowserItem(
                path: e.path,
                name: "SD Card",
                isPrimary: false,
                isDirectory: true,
              ),
            );
          }
        }
      }
    } catch (_) {}

    // ---------- ALWAYS ENSURE INTERNAL EXISTS ----------
    if (!result.any((v) => v.isPrimary)) {
      result.insert(
        0,
        FileBrowserItem(
          path: "/storage/emulated/0",
          name: "Internal Storage",
          isPrimary: true,
          isDirectory: true,
        ),
      );
    }

    return result;
  }

  // ---------- NAVIGATION ----------
  Future<void> navigateTo(String path, {bool setRoot = false}) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      if (state.isRootScreen) {
        if (!await _ensurePermissions()) {
          state = state.copyWith(error: "Storage permission denied");
          return;
        }
        state = state.copyWith(isRootScreen: false, rootPath: path);
      }
      final dir = Directory(path);
      if (!await dir.exists()) {
        state = state.copyWith(
          isLoading: false,
          error: "Directory does not exist",
        );
        return;
      }

      final entities = await dir
          .list(recursive: false, followLinks: false)
          .toList()
          .catchError((_) => <FileSystemEntity>[]);

      final audioExtensions = {
        '.mp3',
        '.wav',
        '.flac',
        '.m4a',
        '.aac',
        '.ogg',
        '.wma',
        '.opus',
      };

      final items = entities
          .where((e) {
            if (e is Directory) return true;
            final extension = e.path.split('.').last.toLowerCase();
            return audioExtensions.contains('.$extension');
          })
          .map((e) {
            final name = e.path.split("/").last;
            final isDir = e is Directory;
            final pinned = false;

            return FileBrowserItem(
              path: e.path,
              name: name.isEmpty ? "/" : name,
              isDirectory: isDir,
              isPinned: pinned,
              isPrimary: false,
            );
          })
          .toList();

      // folders first + alpha sort
      items.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      state = state.copyWith(
        rootPath: setRoot ? path : state.rootPath,
        currentPath: path,
        items: items,
        isLoading: false,
        isRootScreen: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ---------- GO BACK ----------
  Future<void> goBack() async {
    if (state.isRootScreen) return;
    final currentPath = state.currentPath;
    final rootPath = state.rootPath;

    if (p.normalize(Directory(currentPath!).path) ==
        p.normalize(Directory(rootPath!).path)) {
      state = state.copyWith(
        isRootScreen: true,
        currentPath: "",
        items: state.storages,
      );
      return;
    }
    final parent = Directory(currentPath ?? "").parent.path;
    await navigateTo(parent);
  }

  // ---------- PIN FAVORITES ----------
  Future<void> togglePin(FileBrowserItem item) async {
    // TODO: Implement favorites
  }
}

// ---------- PROVIDER ----------
final fileBrowserProvider =
    StateNotifierProvider<FileBrowserNotifier, FileBrowserState>((ref) {
      final notifier = FileBrowserNotifier();
      notifier.init();
      return notifier;
    });
