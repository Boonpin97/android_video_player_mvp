import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_video_player_mvp/domain/models/media_preview.dart';
import 'package:android_video_player_mvp/data/repositories/media_repository.dart';
import 'package:android_video_player_mvp/data/services/media_library_service.dart';

class PreviewService extends MediaLibraryService {
  @override
  Future<void> clearThumbnailCache() async {}
  int calls = 0;
  bool fail = false;
  @override
  Future<MediaPreview?> thumbnailFor(String id) async {
    calls++;
    if (fail) return null;
    return MediaPreview(Uint8List.fromList([1, 2, 3]));
  }
}

void main() {
  test(
    'thumbnail candidates skip opening frame and stay within short videos',
    () {
      final positions = thumbnailPositions(const Duration(minutes: 30));
      expect(positions.first, const Duration(minutes: 3));
      expect(positions.toSet().length, 3);
      for (final duration in [
        const Duration(milliseconds: 1),
        const Duration(seconds: 1),
      ]) {
        for (final position in thumbnailPositions(duration)) {
          expect(position >= Duration.zero && position < duration, isTrue);
        }
      }
    },
  );
  test(
    'black fades and a tiny corner logo do not count as a useful thumbnail',
    () {
      final pixels = Uint8List(100 * 4);
      for (var i = 3; i < pixels.length; i += 4) {
        pixels[i] = 255;
      }
      expect(hasVisibleThumbnailContent(pixels), isFalse);
      pixels.fillRange(0, 4 * 5, 255);
      expect(hasVisibleThumbnailContent(pixels), isFalse);
      pixels.fillRange(0, 4 * 50, 180);
      expect(hasVisibleThumbnailContent(pixels), isTrue);
    },
  );
  test(
    'failed thumbnail is retried, and successful requests share cached work',
    () async {
      final service = PreviewService()..fail = true;
      final repository = MediaRepository(service);
      expect(await repository.thumbnailFor('one'), isNull);
      service.fail = false;
      final first = repository.thumbnailFor('one');
      final second = repository.thumbnailFor('one');
      expect(identical(first, second), isTrue);
      expect(await first, isNotNull);
      expect(service.calls, 2);
      await repository.clearThumbnailCache();
      await repository.thumbnailFor('one');
      expect(service.calls, 3);
    },
  );
}
