import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../domain/models/media_preview.dart';
import 'thumbnail_disk_cache.dart';

class VideoThumbnailService {
  final _nativeQueue = ThumbnailWorkQueue(2);
  final _softwareQueue = ThumbnailWorkQueue(1);
  final _disk = ThumbnailDiskCache();

  Future<MediaPreview?> load(String assetId) async {
    final generation = _disk.generation;
    final elapsed = Stopwatch()..start();
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return null;
      final key =
          '${asset.id}_${asset.modifiedDateTime.millisecondsSinceEpoch}';
      final cached = await _disk.read(key);
      if (cached != null) {
        debugPrint(
          'Thumbnail cache hit: $assetId in ${elapsed.elapsedMilliseconds}ms',
        );
        return cached;
      }
      final preview = await _load(asset);
      debugPrint(
        'Thumbnail generated: $assetId in ${elapsed.elapsedMilliseconds}ms',
      );
      if (preview != null) unawaited(_disk.write(key, preview, generation));
      return preview;
    } catch (error) {
      debugPrint('Thumbnail unavailable for asset $assetId: $error');
      return null;
    }
  }

  Future<void> clearCache() => _disk.clear();
  Future<bool> _hasContent(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 24,
      targetHeight: 16,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        return pixels != null &&
            hasVisibleThumbnailContent(pixels.buffer.asUint8List());
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<MediaPreview?> _load(AssetEntity asset) async {
    // WMV is known to require the software fallback on Android.
    if ((asset.title ?? '').toLowerCase().endsWith('.wmv')) {
      return _softwareQueue.run(() async {
        final file = await asset.file;
        return file == null ? null : _softwarePreview(file);
      });
    }
    final native = await _nativeQueue.run(() async {
      MediaPreview? last;
      for (final position in thumbnailPositions(asset.videoDuration)) {
        try {
          final bytes = await asset.thumbnailDataWithOption(
            ThumbnailOption(
              size: const ThumbnailSize(320, 200),
              quality: 85,
              frame: position.inMicroseconds,
            ),
          );
          if (bytes == null) break;
          last = MediaPreview(bytes, duration: asset.videoDuration);
          if (await _hasContent(bytes)) return (last, true);
        } catch (_) {
          break;
        }
      }
      return (last, false);
    });
    if (native.$2) return native.$1;
    return _softwareQueue.run(() async {
      final file = await asset.file;
      return (file == null ? null : await _softwarePreview(file)) ?? native.$1;
    });
  }

  Future<MediaPreview?> _softwarePreview(File file) async {
    final player = Player(
      configuration: const PlayerConfiguration(
        title: 'Thumbnail',
        muted: true,
        bufferSize: 4 * 1024 * 1024,
      ),
    );
    final output = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'no'),
    );
    // The controller initializes after a Flutter frame, even when no Video widget is displayed.
    WidgetsBinding.instance.scheduleFrame();
    try {
      await output.platform.future;
      final native = player.platform as NativePlayer;
      await native.setProperty('aid', 'no');
      await native.setProperty('sid', 'no');
      await native.setProperty('vf', 'scale=320:-2');
      await player.open(Media(file.path), play: false);
      await output.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 12),
      );
      final duration = player.state.duration;
      MediaPreview? last;
      for (final position in thumbnailPositions(duration)) {
        // Wait for mpv's seek restart event before sampling the new frame.
        final rendered = Completer<void>();
        await native.observeProperty('seeking', (value) async {
          if (value == 'no' && !rendered.isCompleted) rendered.complete();
        });
        await player.seek(position);
        try {
          await rendered.future.timeout(const Duration(seconds: 4));
        } on TimeoutException {
          // A still frame may nevertheless be available for short videos.
        }
        await native.unobserveProperty('seeking');
        // Surface initialization and frame delivery may trail the seek event briefly.
        for (var attempt = 0; attempt < 5; attempt++) {
          final bytes = await player.screenshot();
          if (bytes != null) {
            last = MediaPreview(bytes, duration: duration);
            if (await _hasContent(bytes)) return last;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      return last;
    } catch (error) {
      debugPrint('Software thumbnail unavailable: $error');
      return null;
    } finally {
      await player.dispose();
    }
  }
}
