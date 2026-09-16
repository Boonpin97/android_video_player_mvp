import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/media_preview.dart';

/// Disposable, versioned app cache. A video's modification time is part of its key.
class ThumbnailDiskCache {
  ThumbnailDiskCache({Future<Directory> Function()? directory})
    : _directory =
          directory ??
          (() async => Directory(
            '${(await getTemporaryDirectory()).path}/video_previews_v2',
          ));
  final Future<Directory> Function() _directory;
  Future<void> _writes = Future.value();
  int generation = 0;
  int _writesSinceTrim = 0;

  Future<MediaPreview?> read(String key) async {
    try {
      final file = File(
        '${(await _directory()).path}/${Uri.encodeComponent(key)}.json',
      );
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final bytes = base64Decode(data['image'] as String);
      if (bytes.isEmpty) return null;
      return MediaPreview(
        bytes,
        duration: Duration(milliseconds: data['duration'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, MediaPreview preview, int expectedGeneration) {
    final operation = _writes.then((_) async {
      if (generation != expectedGeneration) return;
      try {
        final directory = await _directory();
        await directory.create(recursive: true);
        final file = File('${directory.path}/${Uri.encodeComponent(key)}.json');
        await file.writeAsString(
          jsonEncode({
            'image': base64Encode(preview.bytes),
            'duration': preview.duration.inMilliseconds,
          }),
        );
        if (_writesSinceTrim++ % 32 == 0) {
          final files = await directory
              .list()
              .where((entry) => entry is File && entry.path.endsWith('.json'))
              .cast<File>()
              .toList();
          if (files.length > 400) {
            final ages = <String, DateTime>{};
            for (final file in files) {
              ages[file.path] = await file.lastModified();
            }
            files.sort((a, b) => ages[a.path]!.compareTo(ages[b.path]!));
            for (final file in files.take(files.length - 400)) {
              await file.delete();
            }
          }
        }
      } catch (_) {
        /* Cache failure must not prevent thumbnails from displaying. */
      }
    });
    _writes = operation;
    return operation;
  }

  Future<void> clear() {
    generation++;
    final operation = _writes.then((_) async {
      final directory = await _directory();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }
}

/// Small bounded worker pool; the software decoder has its own one-worker pool.
class ThumbnailWorkQueue {
  ThumbnailWorkQueue(this.limit);
  final int limit;
  int _active = 0;
  final List<void Function()> _waiting = [];

  Future<T> run<T>(Future<T> Function() work) {
    final result = Completer<T>();
    void start() {
      _active++;
      Future<T>.sync(
        work,
      ).then(result.complete, onError: result.completeError).whenComplete(() {
        _active--;
        if (_waiting.isNotEmpty) _waiting.removeAt(0)();
      });
    }

    if (_active < limit) {
      start();
    } else {
      _waiting.add(start);
    }
    return result.future;
  }
}
