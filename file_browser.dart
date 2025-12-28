import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'file_browser_provider.dart';
import 'package:path/path.dart' as p;

class FileBrowserWidget extends ConsumerWidget {
  const FileBrowserWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileBrowserProvider);
    final notifier = ref.read(fileBrowserProvider.notifier);

    return Column(
      children: [
        _TopBar(state: state, notifier: notifier),
        Expanded(child: _buildBody(context, state, notifier)),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    FileBrowserState state,
    FileBrowserNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Error: ${state.error}",
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: notifier.goBack,
                child: const Text("Go Back"),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(child: Text("Folder is empty or access denied"));
    }

    return ListView.builder(
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return ListTile(
          leading: Icon(
            item.isDirectory ? Icons.folder : Icons.music_note,
            color: item.isDirectory ? Colors.amber : Colors.blue,
          ),
          title: Text(item.name),
          trailing: IconButton(
            icon: Icon(
              item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: item.isPinned ? Colors.redAccent : null,
            ),
            onPressed: () => notifier.togglePin(item),
          ),
          onTap: () {
            if (item.isDirectory) {
              notifier.navigateTo(item.path);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Playing: ${item.name}")));
            }
          },
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final FileBrowserState state;
  final FileBrowserNotifier notifier;

  const _TopBar({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    String pathText = "Select Storage";
    IconData? icon;

    if (!state.isRootScreen) {
      if (state.storages.isNotEmpty) {
        icon = state.rootPath == "/storage/emulated/0"
            ? Icons.phone_android_sharp
            : Icons.sd_card_sharp;

        final relative = p.relative(state.currentPath, from: state.rootPath);
        pathText = relative == "." ? "" : "/ $relative";
      }
    }

    Widget pathTextWidget = Row(
      children: [
        if (icon != null) Icon(icon, size: 20, color: Colors.blueGrey),
        if (icon != null) const SizedBox(width: 4),
        Text(
          pathText,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: state.isRootScreen ? null : notifier.goBack,
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: pathTextWidget,
            ),
          ),
        ],
      ),
    );
  }
}
