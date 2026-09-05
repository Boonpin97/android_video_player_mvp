import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../../domain/models/media_folder.dart';
import '../../domain/models/media_item.dart';

class MediaLibraryService {
  Future<bool> requestAccess() async {
    final permission = await PhotoManager.requestPermissionExtend();
    return permission == PermissionState.authorized ||
        permission == PermissionState.limited;
  }

  Future<List<MediaFolder>> loadFolders() async {
    final folders = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
    );

    final result = <MediaFolder>[];
    for (final folder in folders) {
      final count = await folder.assetCountAsync;
      if (count > 0) {
        result.add(
          MediaFolder(
            id: folder.id,
            name: folder.name.isEmpty ? 'Videos' : folder.name,
            assetCount: count,
          ),
        );
      }
    }
    return result;
  }

  Future<MediaFolderContents> loadFolder(MediaFolder folder) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
    );
    final path = paths.firstWhere(
      (candidate) => candidate.id == folder.id,
      orElse: () => paths.first,
    );
    final count = await path.assetCountAsync;
    final assets = await path.getAssetListRange(start: 0, end: count);
    final items = <MediaItem>[];

    for (final asset in assets) {
      Uint8List? thumbnail;
      try {
        thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(180, 120),
          quality: 72,
        );
      } catch (_) {
        thumbnail = null;
      }
      items.add(await _mapAsset(asset, folder.name, thumbnail));
    }

    return MediaFolderContents(
      folder: folder.copyWith(assetCount: count),
      items: items,
    );
  }

  Future<File?> fileFor(String assetId) async {
    final asset = await AssetEntity.fromId(assetId);
    return asset?.file;
  }

  Future<bool> deleteById(String assetId) async {
    final deletedIds = await PhotoManager.editor.deleteWithIds(<String>[
      assetId,
    ]);
    return deletedIds.contains(assetId);
  }

  Future<MediaItem> _mapAsset(
    AssetEntity asset,
    String folderName,
    Uint8List? thumbnail,
  ) async {
    final title = asset.title ?? await asset.titleAsync;
    return MediaItem(
      id: asset.id,
      title: title,
      duration: Duration(seconds: asset.duration),
      width: asset.orientatedWidth,
      height: asset.orientatedHeight,
      folderName: folderName,
      modifiedAt: asset.modifiedDateSecond == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              asset.modifiedDateSecond! * 1000,
            ),
      thumbnail: thumbnail,
    );
  }
}
