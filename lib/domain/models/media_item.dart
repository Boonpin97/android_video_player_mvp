import 'dart:typed_data';

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.width,
    required this.height,
    required this.folderName,
    required this.modifiedAt,
    this.thumbnail,
  });

  final String id;
  final String title;
  final Duration duration;
  final int width;
  final int height;
  final String folderName;
  final DateTime? modifiedAt;
  final Uint8List? thumbnail;

  String get resolution {
    if (width <= 0 || height <= 0) {
      return 'Unknown resolution';
    }
    return '${width}x$height';
  }
}
