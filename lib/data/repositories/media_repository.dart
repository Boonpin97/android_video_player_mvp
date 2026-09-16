import 'dart:io';
import '../../domain/models/media_deletion_result.dart';
import '../../domain/models/media_preview.dart';

import '../../domain/models/media_folder.dart';
import '../services/media_library_service.dart';

class MediaRepository {
  MediaRepository(this._mediaLibraryService);

  final MediaLibraryService _mediaLibraryService;
  final Map<String, Future<MediaPreview?>> _thumbnails = {};

  Future<MediaPreview?> thumbnailFor(String assetId) {
    if (_thumbnails.length >= 120 && !_thumbnails.containsKey(assetId)) {
      _thumbnails.remove(_thumbnails.keys.first);
    }
    final cached = _thumbnails.remove(assetId);
    if (cached != null) {
      _thumbnails[assetId] = cached;
      return cached;
    }
    final result = _mediaLibraryService.thumbnailFor(assetId);
    _thumbnails[assetId] = result;
    void evict() {
      if (identical(_thumbnails[assetId], result)) _thumbnails.remove(assetId);
    }

    result.then<void>(
      (preview) {
        if (preview == null) evict();
      },
      onError: (Object _, StackTrace _) {
        evict();
      },
    );
    return result;
  }

  Future<void> clearThumbnailCache() async {
    _thumbnails.clear();
    await _mediaLibraryService.clearThumbnailCache();
  }

  Future<bool> requestAccess() {
    return _mediaLibraryService.requestAccess();
  }

  Future<List<MediaFolder>> loadFolders() {
    return _mediaLibraryService.loadFolders();
  }

  Future<MediaFolderContents> loadFolder(MediaFolder folder) {
    return _mediaLibraryService.loadFolder(folder);
  }

  Future<File?> fileFor(String assetId) {
    return _mediaLibraryService.fileFor(assetId);
  }

  Future<Set<String>> videoIdsInFolders(Iterable<String> ids) =>
      _mediaLibraryService.videoIdsInFolders(ids);

  Future<MediaDeletionResult> deleteByIds(Iterable<String> ids) async {
    final result = await _mediaLibraryService.deleteByIds(ids);
    for (final id in result.deletedIds) {
      _thumbnails.remove(id);
    }
    return result;
  }
}
