import 'package:flutter/foundation.dart';

import '../../../../data/repositories/media_repository.dart';
import '../../../../domain/models/media_folder.dart';
import '../../../../domain/models/media_item.dart';

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel(this._mediaRepository);

  final MediaRepository _mediaRepository;

  bool isLoading = false;
  bool hasAccess = false;
  String? errorMessage;
  List<MediaFolder> folders = const [];
  MediaFolder? selectedFolder;
  List<MediaItem> items = const [];
  String query = '';
  bool gridMode = false;

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
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      hasAccess = await _mediaRepository.requestAccess();
      if (!hasAccess) {
        folders = const [];
        items = const [];
        return;
      }

      folders = await _mediaRepository.loadFolders();
      if (folders.isNotEmpty) {
        await selectFolder(folders.first, notifyAtEnd: false);
      }
    } catch (error) {
      errorMessage = 'Could not load videos: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectFolder(
    MediaFolder folder, {
    bool notifyAtEnd = true,
  }) async {
    selectedFolder = folder;
    errorMessage = null;
    if (notifyAtEnd) {
      isLoading = true;
      notifyListeners();
    }

    try {
      final contents = await _mediaRepository.loadFolder(folder);
      selectedFolder = contents.folder;
      items = contents.items;
    } catch (error) {
      errorMessage = 'Could not open folder: $error';
    } finally {
      if (notifyAtEnd) {
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

  Future<void> delete(MediaItem item) async {
    final deleted = await _mediaRepository.deleteById(item.id);
    if (deleted) {
      items = items.where((candidate) => candidate.id != item.id).toList();
    } else {
      errorMessage = 'Delete was not completed by the system.';
    }
    notifyListeners();
  }
}
