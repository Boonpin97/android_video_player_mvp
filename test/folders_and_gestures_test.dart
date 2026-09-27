import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_video_player_mvp/data/services/media_library_index.dart';
import 'package:android_video_player_mvp/ui/features/player/view_models/playback_gesture.dart';

Map<String, Object?> row(
  String id,
  String directory, {
  String volume = 'external_primary',
}) => {
  'id': id,
  'title': '$id.wmv',
  'directory': directory,
  'volume': volume,
  'duration': 100000,
  'width': 640,
  'height': 480,
};

void main() {
  test(
    'only top level folders appear; descendants are browsed one level at a time',
    () {
      final library = MediaLibraryIndex.fromRows([
        row('1', 'DCIM/Camera/'),
        row('2', 'DCIM/Camera/Trips/'),
        row('3', 'Movies/'),
        row('4', 'Courses/Week 1/'),
        row('5', 'Courses/Week 2/'),
      ]);
      expect(library.roots.map((f) => f.name), ['Courses', 'DCIM', 'Movies']);
      final courses = library.contents(library.roots.first);
      expect(courses.folders.map((f) => f.name), ['Week 1', 'Week 2']);
      expect(courses.folder.assetCount, 2);
      expect(courses.items, isEmpty);
      expect(library.contents(courses.folders.first).items.single.id, '4');
      final dcim = library.contents(library.roots[1]);
      expect(dcim.folders.single.name, 'Camera');
      final camera = library.contents(dcim.folders.single);
      expect(camera.items.single.id, '1');
      expect(camera.folders.single.name, 'Trips');
    },
  );

  test('same named root folders on different volumes do not mix videos', () {
    final library = MediaLibraryIndex.fromRows([
      row('1', 'Movies/'),
      row('2', 'Movies/', volume: 'sdcard'),
    ]);
    expect(library.roots.length, 2);
    expect(library.roots.map((f) => f.id).toSet().length, 2);
    expect(
      library.roots.every((f) => library.contents(f).items.length == 1),
      isTrue,
    );
  });

  test('root files remain accessible without a Recent collection', () {
    final library = MediaLibraryIndex.fromRows([row('1', '')]);
    expect(library.roots.single.name, 'Internal storage');
    expect(library.contents(library.roots.single).items.single.id, '1');
  });

  PlaybackGestureSession gesture(
    Offset origin, {
    Duration position = const Duration(seconds: 60),
  }) => PlaybackGestureSession(
    origin: origin,
    viewport: const Size(800, 400),
    position: position,
    duration: const Duration(seconds: 120),
    brightness: 0.5,
    volume: 0.5,
  );

  test('horizontal dragging seeks forward and backward with bounds', () {
    final forward = gesture(const Offset(100, 100))
      ..update(const Offset(200, 5));
    expect(forward.kind, PlaybackGestureKind.seek);
    expect(forward.targetPosition.inMilliseconds, 63847);
    forward.update(const Offset(10000, 0));
    expect(forward.targetPosition, const Duration(seconds: 120));
    final back = gesture(const Offset(700, 100))
      ..update(const Offset(-10000, 0));
    expect(back.targetPosition, Duration.zero);
  });

  test('left vertical drag controls brightness, right controls volume', () {
    final left = gesture(const Offset(100, 100))..update(const Offset(2, -100));
    expect(left.kind, PlaybackGestureKind.brightness);
    expect(left.targetBrightness, 0.875);
    final right = gesture(const Offset(700, 100))..update(const Offset(2, 100));
    expect(right.kind, PlaybackGestureKind.volume);
    expect(right.targetVolume, 0.125);
    right.update(const Offset(0, 1000));
    expect(right.targetVolume, 0);
    left.update(const Offset(0, -1000));
    expect(left.targetBrightness, 1);
  });

  test('tiny touches do not become drags and a chosen axis stays locked', () {
    final session = gesture(const Offset(50, 50))..update(const Offset(2, 2));
    expect(session.kind, isNull);
    session.update(const Offset(0, 20));
    expect(session.kind, PlaybackGestureKind.brightness);
    session.update(const Offset(500, 0));
    expect(session.kind, PlaybackGestureKind.brightness);
  });

  test('volume gestures can boost audio to 200%', () {
    final boosted = PlaybackGestureSession(
      origin: const Offset(700, 100),
      viewport: const Size(800, 400),
      position: Duration.zero,
      duration: const Duration(seconds: 120),
      brightness: 0.5,
      volume: 1,
    )..update(const Offset(0, -1000));

    expect(boosted.kind, PlaybackGestureKind.volume);
    expect(boosted.targetVolume, 2);
  });
}
