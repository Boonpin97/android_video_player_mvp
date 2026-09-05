import 'package:flutter/material.dart';

import '../../../../data/repositories/media_repository.dart';
import '../../../../domain/models/media_item.dart';
import '../../player/views/player_page.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../view_models/library_view_model.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.viewModel,
    required this.settingsViewModel,
    required this.mediaRepository,
  });

  final LibraryViewModel viewModel;
  final SettingsViewModel settingsViewModel;
  final MediaRepository mediaRepository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Videos'),
            actions: [
              IconButton(
                tooltip: viewModel.gridMode
                    ? 'Use list layout'
                    : 'Use grid layout',
                onPressed: viewModel.toggleGridMode,
                icon: Icon(
                  viewModel.gridMode ? Icons.view_list : Icons.grid_view,
                ),
              ),
              IconButton(
                tooltip: 'Refresh library',
                onPressed: viewModel.load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _LibraryBody(
            viewModel: viewModel,
            settingsViewModel: settingsViewModel,
            mediaRepository: mediaRepository,
          ),
        );
      },
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({
    required this.viewModel,
    required this.settingsViewModel,
    required this.mediaRepository,
  });

  final LibraryViewModel viewModel;
  final SettingsViewModel settingsViewModel;
  final MediaRepository mediaRepository;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && viewModel.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!viewModel.hasAccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.perm_media_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                'Media access is required to scan local videos.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: viewModel.load,
                icon: const Icon(Icons.folder_open),
                label: const Text('Grant access'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchBar(
            hintText: 'Search videos',
            leading: const Icon(Icons.search),
            onChanged: viewModel.updateQuery,
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final folder = viewModel.folders[index];
              final selected = folder.id == viewModel.selectedFolder?.id;
              return ChoiceChip(
                selected: selected,
                label: Text('${folder.name} (${folder.assetCount})'),
                onSelected: (_) => viewModel.selectFolder(folder),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemCount: viewModel.folders.length,
          ),
        ),
        if (viewModel.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              viewModel.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: viewModel.gridMode
              ? _VideoGrid(
                  items: viewModel.filteredItems,
                  viewModel: viewModel,
                  settingsViewModel: settingsViewModel,
                  mediaRepository: mediaRepository,
                )
              : _VideoList(
                  items: viewModel.filteredItems,
                  viewModel: viewModel,
                  settingsViewModel: settingsViewModel,
                  mediaRepository: mediaRepository,
                ),
        ),
      ],
    );
  }
}

class _VideoList extends StatelessWidget {
  const _VideoList({
    required this.items,
    required this.viewModel,
    required this.settingsViewModel,
    required this.mediaRepository,
  });

  final List<MediaItem> items;
  final LibraryViewModel viewModel;
  final SettingsViewModel settingsViewModel;
  final MediaRepository mediaRepository;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No videos found'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: _Thumbnail(item: item),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${_formatDuration(item.duration)} • ${item.resolution}',
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDelete(context, viewModel, item);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          onTap: () => _openPlayer(
            context,
            item,
            items,
            settingsViewModel,
            mediaRepository,
          ),
        );
      },
    );
  }
}

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({
    required this.items,
    required this.viewModel,
    required this.settingsViewModel,
    required this.mediaRepository,
  });

  final List<MediaItem> items;
  final LibraryViewModel viewModel;
  final SettingsViewModel settingsViewModel;
  final MediaRepository mediaRepository;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No videos found'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openPlayer(
              context,
              item,
              items,
              settingsViewModel,
              mediaRepository,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Thumbnail(item: item, fill: true)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, this.fill = false});

  final MediaItem item;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final bytes = item.thumbnail;
    final child = bytes == null
        ? ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.movie_outlined)),
          )
        : Image.memory(bytes, fit: BoxFit.cover);
    return SizedBox(
      width: fill ? double.infinity : 88,
      height: fill ? double.infinity : 56,
      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
    );
  }
}

void _openPlayer(
  BuildContext context,
  MediaItem item,
  List<MediaItem> queue,
  SettingsViewModel settingsViewModel,
  MediaRepository mediaRepository,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerPage(
        initialItem: item,
        queue: queue,
        settingsViewModel: settingsViewModel,
        mediaRepository: mediaRepository,
      ),
    ),
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  LibraryViewModel viewModel,
  MediaItem item,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete video?'),
      content: Text(item.title),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await viewModel.delete(item);
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
