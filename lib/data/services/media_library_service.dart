import 'dart:io';
import '../../domain/models/media_deletion_result.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../domain/models/media_folder.dart';
import 'media_library_index.dart';
import 'video_thumbnail_service.dart';
import '../../domain/models/media_preview.dart';

class MediaLibraryService {
  static const _channel = MethodChannel('player/device');
  MediaLibraryIndex? _index;

  Future<bool> requestAccess() async {
    final permission = await PhotoManager.requestPermissionExtend();
    return permission == PermissionState.authorized ||
        permission == PermissionState.limited;
  }

  Future<List<MediaFolder>> loadFolders() async {
    final rows = await _channel.invokeListMethod<Object?>('scanVideos') ?? [];
    _index = MediaLibraryIndex.fromRows(
      rows.map((row) => Map<String, Object?>.from(row as Map)).toList(),
    );
    return _index!.roots;
  }

  Future<MediaFolderContents> loadFolder(MediaFolder folder) async {
    if (_index == null) await loadFolders();
    return _index!.contents(folder);
  }

  Future<File?> fileFor(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    return asset?.file;
  }

  final _thumbnailService = VideoThumbnailService();
  Future<MediaPreview?> thumbnailFor(String assetId) =>
      _thumbnailService.load(assetId);

  Future<void> clearThumbnailCache() => _thumbnailService.clearCache();

  Future<Set<String>> videoIdsInFolders(Iterable<String> folderIds) async {
    if (_index == null) await loadFolders();
    return _index!.videoIdsInFolders(folderIds);
  }

  Future<MediaDeletionResult> deleteByIds(Iterable<String> assetIds) async {
    final ids = assetIds.toSet().toList();
    final deleted = <String>[];
    // Recent Android versions cap a single media consent request at 2,000 URIs.
    for (var start = 0; start < ids.length; start += 2000) {
      final batch = ids.sublist(start, (start + 2000).clamp(0, ids.length));
      try {
        final result = (await PhotoManager.editor.deleteWithIds(batch)).toSet();
        final confirmed = batch.where(result.contains).toList();
        deleted.addAll(confirmed);
        if (confirmed.isNotEmpty) _index = null;
        if (confirmed.length != batch.length) {
          return MediaDeletionResult(deletedIds: deleted, cancelled: true);
        }
      } catch (_) {
        return MediaDeletionResult(
          deletedIds: deleted,
          error: 'Could not delete all selected videos.',
        );
      }
    }
    return MediaDeletionResult(deletedIds: deleted);
  }
}
