import 'package:android_video_player_mvp/domain/models/media_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolution reports known dimensions', () {
    const item = MediaItem(
      id: '1',
      title: 'sample.mp4',
      duration: Duration(seconds: 10),
      width: 1920,
      height: 1080,
      folderName: 'Movies',
      modifiedAt: null,
    );

    expect(item.resolution, '1920x1080');
  });

  test('resolution reports unknown dimensions', () {
    const item = MediaItem(
      id: '1',
      title: 'sample.mp4',
      duration: Duration(seconds: 10),
      width: 0,
      height: 0,
      folderName: 'Movies',
      modifiedAt: null,
    );

    expect(item.resolution, 'Unknown resolution');
  });
}
