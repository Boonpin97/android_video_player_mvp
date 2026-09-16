import '../../../../domain/models/media_preview.dart';
import 'package:flutter/material.dart';
import '../../../../data/repositories/media_repository.dart';
import '../../../../domain/models/media_folder.dart';
import '../../../../domain/models/media_item.dart';
import '../../../core/app_theme.dart';
import '../../../core/ui_helpers.dart';
import '../../player/views/player_page.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../view_models/library_view_model.dart';

class LibraryPage extends StatefulWidget {
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
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  bool _searching = false;
  final _search = TextEditingController();
  LibraryViewModel get vm => widget.viewModel;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    _searching = false;
    vm.updateQuery('');
  }

  void _back() {
    if (vm.isDeleting) return;
    if (vm.isSelecting) {
      vm.clearSelection();
      return;
    }
    _clearSearch();
    vm.goUp();
  }

  void _root() {
    _clearSearch();
    vm.showFolders();
  }

  void _openFolder(MediaFolder folder) {
    if (vm.isDeleting) return;
    if (vm.isSelecting) {
      vm.toggleFolderSelection(folder.id);
      return;
    }
    _clearSearch();
    vm.selectFolder(folder);
  }

  Future<void> _open(MediaItem item) async {
    if (vm.isDeleting) return;
    if (vm.isSelecting) {
      vm.toggleVideoSelection(item.id);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          initialItem: item,
          queue: vm.items,
          settingsViewModel: widget.settingsViewModel,
          mediaRepository: widget.mediaRepository,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _delete(MediaItem item) async {
    if (vm.isDeleting) return;
    vm.clearSelection();
    vm.toggleVideoSelection(item.id);
    await vm.deleteSelection();
  }

  Widget _selectionFrame(bool selected, Widget child) => Semantics(
    selected: selected,
    child: ColoredBox(
      color: selected
          ? AppTheme.blue.withValues(alpha: 0.14)
          : Colors.transparent,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          if (vm.isSelecting)
            Positioned(
              right: 6,
              top: 6,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? AppTheme.blue : Colors.grey,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  String _folderDetail(MediaFolder folder) => folder.folderCount == 0
      ? '${folder.assetCount} videos'
      : '${folder.folderCount} folders · ${folder.assetCount} videos';

  Widget _folderTile(MediaFolder folder, {bool grid = false}) {
    final watched =
        widget.settingsViewModel.repository.lastWatchedFolderId == folder.id;
    final titleStyle = TextStyle(
      color: watched ? AppTheme.blue : AppTheme.ink,
      fontSize: grid ? 14 : 16,
    );
    return _selectionFrame(
      vm.selectedFolderIds.contains(folder.id),
      InkWell(
        onTap: () => _openFolder(folder),
        onLongPress: widget.settingsViewModel.option('allowEditing')
            ? () => vm.toggleFolderSelection(folder.id)
            : null,
        child: grid
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, color: Color(0xffe0e3e8), size: 68),
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  Text(
                    _folderDetail(folder),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xff999faa),
                      fontSize: 11,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(12, 3, 16, 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder,
                      color: Color(0xffe0e3e8),
                      size: 68,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _folderDetail(folder),
                            style: const TextStyle(
                              color: Color(0xff999faa),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _videoTile(MediaItem item, {bool grid = false}) {
    final watched =
        widget.settingsViewModel.repository.lastWatchedMediaId == item.id;
    final titleStyle = TextStyle(
      color: watched ? AppTheme.blue : AppTheme.ink,
      fontSize: 14,
    );
    final editable = widget.settingsViewModel.option('allowEditing');
    final onLongPress = editable
        ? () => vm.toggleVideoSelection(item.id)
        : null;
    if (grid) {
      return _selectionFrame(
        vm.selectedVideoIds.contains(item.id),
        InkWell(
          onTap: () => _open(item),
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: VideoThumbnail(
                  key: ValueKey(item.id),
                  item: item,
                  repository: widget.mediaRepository,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ],
          ),
        ),
      );
    }
    return _selectionFrame(
      vm.selectedVideoIds.contains(item.id),
      ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 5, 4, 5),
        leading: SizedBox(
          width: 96,
          height: 60,
          child: VideoThumbnail(
            key: ValueKey(item.id),
            item: item,
            repository: widget.mediaRepository,
          ),
        ),
        title: Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        subtitle: Text(
          item.resolution,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: vm.isSelecting
            ? const SizedBox(width: 40)
            : editable
            ? PopupMenuButton<String>(
                enabled: !vm.isDeleting,
                onSelected: (_) => _delete(item),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            : null,
        onTap: () => _open(item),
        onLongPress: onLongPress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final root = vm.selectedFolder == null;
      final folders = vm.folders
          .where(
            (f) => f.name.toLowerCase().contains(vm.query.trim().toLowerCase()),
          )
          .toList();
      final videos = vm.filteredItems;
      return PopScope(
        canPop: root && !vm.isSelecting && !vm.isDeleting,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: vm.isSelecting
                ? IconButton(
                    tooltip: 'Clear selection',
                    icon: const Icon(Icons.close),
                    onPressed: vm.isDeleting ? null : vm.clearSelection,
                  )
                : root
                ? null
                : IconButton(
                    tooltip: 'Parent folder',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _back,
                  ),
            title: vm.isSelecting
                ? Text('${vm.selectionCount} selected')
                : _searching
                ? TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: vm.updateQuery,
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      border: InputBorder.none,
                    ),
                  )
                : Text(root ? 'Videos' : vm.selectedFolder!.name),
            actions: [
              if (vm.isSelecting) ...[
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.select_all),
                  onPressed: vm.isDeleting ? null : vm.selectVisible,
                ),
              ] else ...[
                if (!root && !_searching)
                  IconButton(
                    tooltip: 'Root folders',
                    icon: const Icon(Icons.folder_open),
                    onPressed: _root,
                  ),
                IconButton(
                  tooltip: _searching ? 'Close search' : 'Search',
                  icon: Icon(_searching ? Icons.close : Icons.search),
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _search.clear();
                      vm.updateQuery('');
                    }
                  }),
                ),
                IconButton(
                  tooltip: vm.gridMode ? 'Use list layout' : 'Use grid layout',
                  icon: Icon(
                    vm.gridMode
                        ? Icons.view_list_outlined
                        : Icons.view_quilt_outlined,
                  ),
                  onPressed: vm.toggleGridMode,
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        vm.selectedFolderIds.isNotEmpty
                            ? 'Includes videos in selected folders and subfolders'
                            : root
                            ? 'Folders'
                            : vm.selectedFolder!.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (!vm.isSelecting)
                      IconButton(
                        tooltip: 'Refresh library',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: vm.isLoading ? null : vm.refresh,
                      ),
                  ],
                ),
              ),
              if (vm.isLoading || vm.isDeleting)
                const LinearProgressIndicator(minHeight: 2),
              if (vm.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Expanded(
                child: !vm.hasAccess && !vm.isLoading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.video_library_outlined,
                                size: 56,
                                color: Color(0xffc1c7d0),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Allow access to find videos on your phone.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton(
                                onPressed: vm.load,
                                child: const Text('Grant access'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: vm.refresh,
                        child: folders.isEmpty && videos.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.sizeOf(context).height *
                                        0.55,
                                    child: Center(
                                      child: Text(
                                        vm.isLoading
                                            ? 'Loading folders…'
                                            : 'No videos found',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  if (folders.isNotEmpty)
                                    vm.gridMode
                                        ? SliverPadding(
                                            padding: const EdgeInsets.all(12),
                                            sliver: SliverGrid(
                                              gridDelegate:
                                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                                    maxCrossAxisExtent: 180,
                                                    childAspectRatio: 1.2,
                                                  ),
                                              delegate:
                                                  SliverChildBuilderDelegate(
                                                    (context, index) =>
                                                        _folderTile(
                                                          folders[index],
                                                          grid: true,
                                                        ),
                                                    childCount: folders.length,
                                                  ),
                                            ),
                                          )
                                        : SliverList(
                                            delegate:
                                                SliverChildBuilderDelegate(
                                                  (context, index) =>
                                                      _folderTile(
                                                        folders[index],
                                                      ),
                                                  childCount: folders.length,
                                                ),
                                          ),
                                  if (videos.isNotEmpty && folders.isNotEmpty)
                                    const SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          16,
                                          20,
                                          16,
                                          10,
                                        ),
                                        child: Text(
                                          'Videos',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  if (videos.isNotEmpty)
                                    vm.gridMode
                                        ? SliverPadding(
                                            padding: const EdgeInsets.all(12),
                                            sliver: SliverGrid(
                                              gridDelegate:
                                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                                    maxCrossAxisExtent: 230,
                                                    childAspectRatio: 1.15,
                                                    crossAxisSpacing: 12,
                                                    mainAxisSpacing: 12,
                                                  ),
                                              delegate:
                                                  SliverChildBuilderDelegate(
                                                    (context, index) =>
                                                        _videoTile(
                                                          videos[index],
                                                          grid: true,
                                                        ),
                                                    childCount: videos.length,
                                                  ),
                                            ),
                                          )
                                        : SliverList(
                                            delegate:
                                                SliverChildBuilderDelegate(
                                                  (context, index) =>
                                                      _videoTile(videos[index]),
                                                  childCount: videos.length,
                                                ),
                                          ),
                                ],
                              ),
                      ),
              ),
            ],
          ),
          floatingActionButton: vm.isSelecting
              ? FloatingActionButton(
                  tooltip: 'Delete selected videos',
                  onPressed: vm.isDeleting ? null : vm.deleteSelection,
                  child: const Icon(Icons.delete_outline),
                )
              : null,
        ),
      );
    },
  );
}

class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({
    super.key,
    required this.item,
    required this.repository,
  });
  final MediaItem item;
  final MediaRepository repository;
  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late Future<MediaPreview?> _thumbnail;
  @override
  void initState() {
    super.initState();
    _thumbnail = widget.repository.thumbnailFor(widget.item.id);
  }

  @override
  void didUpdateWidget(covariant VideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _thumbnail = widget.repository.thumbnailFor(widget.item.id);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MediaPreview?>(
    future: _thumbnail,
    builder: (context, snapshot) {
      final preview = snapshot.data;
      final duration = preview != null && preview.duration > Duration.zero
          ? preview.duration
          : widget.item.duration;
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(
              color: Color(0xffe9ecf0),
              child: Icon(
                Icons.movie_outlined,
                color: Color(0xffb5bbc5),
                size: 30,
              ),
            ),
            if (preview != null)
              Image.memory(
                preview.bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.movie_outlined, color: AppTheme.ink),
              ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            if (duration > Duration.zero)
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  color: Colors.black54,
                  child: Text(
                    formatDuration(duration),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
