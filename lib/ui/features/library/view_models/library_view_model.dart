import 'package:flutter/foundation.dart';

import '../../../../data/repositories/media_repository.dart';
import '../../../../domain/models/media_folder.dart';
import '../../../../domain/models/media_item.dart';

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel(this._mediaRepository);

  final MediaRepository _mediaRepository;

  bool isLoading = false;
  bool isDeleting = false;
  bool _disposed = false;
  final Set<String> selectedVideoIds = {};
  final Set<String> selectedFolderIds = {};
  int get selectionCount => selectedVideoIds.length + selectedFolderIds.length;
  bool get isSelecting => selectionCount > 0;

  void clearSelection() {
    if (isDeleting) return;
    errorMessage = null;
    selectedVideoIds.clear();
    selectedFolderIds.clear();
    notifyListeners();
  }

  void toggleVideoSelection(String id) {
    if (isDeleting || isLoading) return;
    if (!selectedVideoIds.remove(id)) selectedVideoIds.add(id);
    notifyListeners();
  }

  void toggleFolderSelection(String id) {
    if (isDeleting || isLoading) return;
    if (!selectedFolderIds.remove(id)) selectedFolderIds.add(id);
    notifyListeners();
  }

  void selectVisible() {
    if (isDeleting || isLoading) return;
    selectedVideoIds.addAll(filteredItems.map((item) => item.id));
    selectedFolderIds.addAll(
      folders
          .where(
            (folder) =>
                folder.name.toLowerCase().contains(query.trim().toLowerCase()),
          )
          .map((folder) => folder.id),
    );
    notifyListeners();
  }

  bool hasAccess = false;
  String? errorMessage;
  List<MediaFolder> folders = const [];
  MediaFolder? selectedFolder;
  List<MediaItem> items = const [];
  String query = '';
  bool gridMode = false;
  int _loadGeneration = 0;
  List<MediaFolder> _rootFolders = const [];
  final List<MediaFolder> _parents = [];

  Future<void> goUp() async {
    if (isDeleting) return;
    if (_parents.isEmpty) {
      showFolders();
    } else {
      await selectFolder(_parents.removeLast(), rememberParent: false);
    }
  }

  void showFolders() {
    if (isDeleting) return;
    errorMessage = null;
    selectedVideoIds.clear();
    selectedFolderIds.clear();
    _loadGeneration++;
    selectedFolder = null;
    folders = _rootFolders;
    _parents.clear();
    items = const [];
    query = '';
    isLoading = false;
    notifyListeners();
  }

  List<MediaItem> get filteredItems {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return items;
    }
    return items
        .where((item) => item.title.toLowerCase().contains(trimmed))
        .toList(growable: false);
  }

  Future<void> load() async {
    if (isDeleting) return;
    errorMessage = null;
    selectedVideoIds.clear();
    selectedFolderIds.clear();
    final generation = ++_loadGeneration;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      hasAccess = await _mediaRepository.requestAccess();
      if (generation != _loadGeneration) return;
      if (!hasAccess) {
        folders = const [];
        items = const [];
        return;
      }

      final result = await _mediaRepository.loadFolders();
      if (generation != _loadGeneration) return;
      folders = result;
      _rootFolders = result;
      _parents.clear();
      selectedFolder = null;
      items = const [];
    } catch (error) {
      if (generation != _loadGeneration) return;
      errorMessage = 'Could not load videos: $error';
    } finally {
      if (generation == _loadGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Re-scan MediaStore and restore the deepest folder that still exists.
  /// This reflects changes made outside the app without forcing a return to
  /// the library root when the current folder remains available.
  Future<void> refresh() async {
    if (isDeleting || _disposed) return;
    final generation = ++_loadGeneration;
    final path = <MediaFolder>[..._parents];
    if (selectedFolder != null) path.add(selectedFolder!);
    isLoading = true;
    errorMessage = null;
    selectedVideoIds.clear();
    selectedFolderIds.clear();
    notifyListeners();

    try {
      hasAccess = await _mediaRepository.requestAccess();
      if (generation != _loadGeneration || !hasAccess) return;
      final roots = await _mediaRepository.loadFolders();
      if (generation != _loadGeneration) return;
      _rootFolders = roots;

      for (var index = path.length - 1; index >= 0; index--) {
        final contents = await _mediaRepository.loadFolder(path[index]);
        if (generation != _loadGeneration) return;
        if (contents.folder.assetCount > 0) {
          selectedFolder = contents.folder;
          folders = contents.folders;
          items = contents.items;
          _parents
            ..clear()
            ..addAll(path.take(index));
          return;
        }
      }

      selectedFolder = null;
      _parents.clear();
      folders = roots;
      items = const [];
    } catch (error) {
      if (generation == _loadGeneration) {
        errorMessage = 'Could not refresh videos: $error';
      }
    } finally {
      if (generation == _loadGeneration && !_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectFolder(
    MediaFolder folder, {
    bool notifyAtEnd = true,
    bool rememberParent = true,
  }) async {
    if (isDeleting) return;
    selectedVideoIds.clear();
    selectedFolderIds.clear();
    final generation = ++_loadGeneration;
    if (rememberParent && selectedFolder != null) _parents.add(selectedFolder!);
    selectedFolder = folder;
    folders = const [];
    query = '';
    items = const [];
    errorMessage = null;
    if (notifyAtEnd) {
      isLoading = true;
      notifyListeners();
    }

    try {
      final contents = await _mediaRepository.loadFolder(folder);
      if (generation != _loadGeneration) return;
      selectedFolder = contents.folder;
      folders = contents.folders;
      items = contents.items;
    } catch (error) {
      if (generation != _loadGeneration) return;
      errorMessage = 'Could not open folder: $error';
    } finally {
      if (notifyAtEnd && generation == _loadGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void updateQuery(String value) {
    query = value;
    notifyListeners();
  }

  void toggleGridMode() {
    gridMode = !gridMode;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }

  Future<void> deleteSelection() async {
    if (isDeleting || !isSelecting || _disposed) return;
    isDeleting = true;
    errorMessage = null;
    final videoIds = Set<String>.of(selectedVideoIds);
    final folderIds = Set<String>.of(selectedFolderIds);
    notifyListeners();
    try {
      videoIds.addAll(await _mediaRepository.videoIdsInFolders(folderIds));
      if (_disposed) return;
      if (videoIds.isEmpty) {
        errorMessage = 'No videos found in the selection.';
        return;
      }
      final result = await _mediaRepository.deleteByIds(videoIds);
      if (_disposed) return;
      if (result.deletedIds.isNotEmpty) {
        selectedVideoIds.removeAll(result.deletedIds);
        items = items
            .where((item) => !result.deletedIds.contains(item.id))
            .toList();
        await _refreshAfterDeletion();
        if (_disposed) return;
      }
      if (result.error != null) {
        errorMessage = result.error;
      } else if (result.cancelled) {
        errorMessage = result.deletedIds.isEmpty
            ? 'Deletion cancelled.'
            : 'Deletion stopped. Some videos were deleted.';
      } else {
        selectedVideoIds.clear();
        selectedFolderIds.clear();
      }
    } catch (_) {
      if (!_disposed) {
        errorMessage =
            'Could not delete the selected videos. Please refresh and try again.';
      }
    } finally {
      isDeleting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _refreshAfterDeletion() async {
    final roots = await _mediaRepository.loadFolders();
    if (_disposed) return;
    _rootFolders = roots;
    while (selectedFolder != null) {
      final contents = await _mediaRepository.loadFolder(selectedFolder!);
      if (_disposed) return;
      if (contents.folder.assetCount > 0) {
        selectedFolder = contents.folder;
        folders = contents.folders;
        items = contents.items;
        selectedFolderIds.retainAll(folders.map((folder) => folder.id));
        return;
      }
      selectedFolder = _parents.isEmpty ? null : _parents.removeLast();
    }
    folders = roots;
    items = const [];
    selectedFolderIds.retainAll(roots.map((folder) => folder.id));
  }
}
