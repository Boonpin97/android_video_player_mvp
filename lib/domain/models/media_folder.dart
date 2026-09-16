import 'media_item.dart';

class MediaFolder {
  const MediaFolder({
    required this.id,
    required this.name,
    required this.assetCount,
    this.folderCount = 0,
  });
  final String id;
  final String name;
  final int assetCount;
  final int folderCount;
  MediaFolder copyWith({int? assetCount, int? folderCount}) => MediaFolder(
    id: id,
    name: name,
    assetCount: assetCount ?? this.assetCount,
    folderCount: folderCount ?? this.folderCount,
  );
}

class MediaFolderContents {
  const MediaFolderContents({
    required this.folder,
    required this.items,
    this.folders = const [],
  });
  final MediaFolder folder;
  final List<MediaItem> items;
  final List<MediaFolder> folders;
}
