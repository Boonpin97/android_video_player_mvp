import 'media_item.dart';

class MediaFolder {
  const MediaFolder({
    required this.id,
    required this.name,
    required this.assetCount,
  });

  final String id;
  final String name;
  final int assetCount;

  MediaFolder copyWith({int? assetCount}) {
    return MediaFolder(
      id: id,
      name: name,
      assetCount: assetCount ?? this.assetCount,
    );
  }
}

class MediaFolderContents {
  const MediaFolderContents({required this.folder, required this.items});

  final MediaFolder folder;
  final List<MediaItem> items;
}
