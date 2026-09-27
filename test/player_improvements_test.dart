import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_video_player_mvp/data/services/thumbnail_disk_cache.dart';
import 'package:android_video_player_mvp/domain/models/media_preview.dart';
import 'package:android_video_player_mvp/ui/features/player/view_models/playback_gesture.dart';
import 'package:android_video_player_mvp/ui/core/player_adjustments.dart';
import 'package:android_video_player_mvp/data/services/preference_service.dart';
import 'package:android_video_player_mvp/data/repositories/settings_repository.dart';

void main() {
  for (final size in [const Size(393, 852), const Size(852, 393)]) {
    testWidgets(
      'seek sensitivity saves slider changes, nudges and reset at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final values = <double>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      chooseSeekSensitivity(context, 1, (value) async {
                        values.add(value);
                      }),
                  child: const Text('Adjust'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Adjust'));
        await tester.pumpAndSettle();
        expect(find.text('1.00x'), findsOneWidget);
        final slider = tester.widget<Slider>(find.byType(Slider));
        expect(slider.min, 0.25);
        expect(slider.max, 4);
        // Release the slider between the old presets: the precise value must save.
        slider.onChanged!(1.35);
        slider.onChangeEnd!(1.35);
        await tester.pumpAndSettle();
        expect(values.last, 1.35);
        await tester.tap(find.text('+0.05x'));
        await tester.pumpAndSettle();
        expect(values.last, 1.4);
        await tester.tap(find.text('-0.05x'));
        await tester.pumpAndSettle();
        expect(values.last, 1.35);
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        expect(values.last, 1);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('Seek drag sensitivity'), findsNothing);
      },
    );
  }

  test(
    'disk thumbnails survive a new cache instance and modified videos miss',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'player_preview_test_',
      );
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final first = ThumbnailDiskCache(directory: () async => directory);
      await first.write(
        '42_100',
        MediaPreview(
          Uint8List.fromList([1, 2, 3]),
          duration: const Duration(seconds: 90),
        ),
        first.generation,
      );
      final restarted = ThumbnailDiskCache(directory: () async => directory);
      expect(
        (await restarted.read('42_100'))?.duration,
        const Duration(seconds: 90),
      );
      expect((await restarted.read('42_100'))?.bytes, [1, 2, 3]);
      expect(await restarted.read('42_101'), isNull);
      final oldGeneration = restarted.generation;
      await restarted.clear();
      await restarted.write(
        '42_100',
        MediaPreview(Uint8List(1)),
        oldGeneration,
      );
      expect(await restarted.read('42_100'), isNull);
    },
  );

  test(
    'worker queue runs two native jobs together and recovers after failure',
    () async {
      final queue = ThumbnailWorkQueue(2);
      final first = Completer<int>();
      final second = Completer<int>();
      var thirdStarted = false;
      final one = queue.run(() => first.future);
      final two = queue.run(() => second.future);
      final three = queue.run(() async {
        thirdStarted = true;
        return 3;
      });
      expect(thirdStarted, isFalse);
      first.complete(1);
      expect(await one, 1);
      expect(await three, 3);
      second.completeError(StateError('decode failure'));
      await expectLater(two, throwsStateError);
      expect(await queue.run(() async => 4), 4);
    },
  );

  test('sensitivity changes horizontal seek distance, with safe bounds', () {
    PlaybackGestureSession gesture(double sensitivity) =>
        PlaybackGestureSession(
          origin: const Offset(100, 100),
          viewport: const Size(1000, 500),
          position: const Duration(minutes: 5),
          duration: const Duration(minutes: 20),
          brightness: 0.5,
          volume: 0.5,
          seekSensitivity: sensitivity,
        )..update(const Offset(100, 0));
    expect(gesture(0.5).targetPosition.inSeconds, 302);
    expect(gesture(1).targetPosition.inSeconds, 305);
    expect(gesture(4).targetPosition.inSeconds, 322);
    final backward = gesture(4)..update(const Offset(-10000, 0));
    expect(backward.targetPosition, Duration.zero);
  });

  test('horizontal seek accelerates exponentially with drag length', () {
    Duration offsetFor(double dx) {
      final session = PlaybackGestureSession(
        origin: Offset.zero,
        viewport: const Size(1000, 500),
        position: const Duration(hours: 1),
        duration: const Duration(hours: 2),
        brightness: 0.5,
        volume: 0.5,
      )..update(Offset(dx, 0));
      return session.targetPosition - const Duration(hours: 1);
    }

    // Short drags seek finely; longer drags grow faster than linearly.
    expect(offsetFor(50).inSeconds, 2);
    expect(offsetFor(250).inSeconds, 19);
    expect(offsetFor(500).inSeconds, 71);
    expect(offsetFor(1000).inSeconds, 600);
    expect(offsetFor(500) > offsetFor(250) * 3, isTrue);
    expect(offsetFor(-250), -offsetFor(250));
  });

  test(
    'audio delay is bounded per video and sensitivity survives restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = PreferenceService();
      await preferences.init();
      final settings = SettingsRepository(preferences);
      await settings.setAudioDelay('one', 7);
      await settings.setAudioDelay('two', -7);
      await settings.setSeekSensitivity(2);
      final freshPreferences = PreferenceService();
      await freshPreferences.init();
      final fresh = SettingsRepository(freshPreferences);
      expect(fresh.audioDelayFor('one'), 3);
      expect(fresh.audioDelayFor('two'), -3);
      expect(fresh.audioDelayFor('three'), 0);
      expect(fresh.seekSensitivity, 2);
      await fresh.resetSettings();
      expect(fresh.seekSensitivity, 1);
      expect(fresh.audioDelayFor('one'), 0);
    },
  );

  test(
    'watch history persists the current video and clears with history',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = PreferenceService();
      await preferences.init();
      final settings = SettingsRepository(preferences);

      await settings.saveLastPosition('one', const Duration(minutes: 2));
      await settings.markLastWatched(mediaId: 'one', folderId: 'movies');

      final restartedPreferences = PreferenceService();
      await restartedPreferences.init();
      final restarted = SettingsRepository(restartedPreferences);
      expect(restarted.lastWatchedMediaId, 'one');
      expect(restarted.lastWatchedFolderId, 'movies');
      expect(restarted.lastPositionFor('one'), const Duration(minutes: 2));

      await restarted.clearHistory();
      expect(restarted.lastWatchedMediaId, isNull);
      expect(restarted.lastWatchedFolderId, isNull);
      expect(restarted.lastPositionFor('one'), Duration.zero);
    },
  );

  testWidgets(
    'audio sync controls apply live, clamp at range limits, and reset',
    (tester) async {
      final values = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: AudioSyncDialog(
            initialValue: 3,
            onChanged: (value) async {
              values.add(value);
            },
          ),
        ),
      );
      await tester.tap(find.text('+0.05 s'));
      await tester.pumpAndSettle();
      expect(values.last, 3);
      await tester.tap(find.text('-0.05 s'));
      await tester.pumpAndSettle();
      expect(values.last, 2.95);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(values.last, 0);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, -3);
      expect(slider.max, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
