import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:android_video_player_mvp/data/repositories/media_repository.dart';
import 'package:android_video_player_mvp/data/repositories/settings_repository.dart';
import 'package:android_video_player_mvp/data/services/media_library_service.dart';
import 'package:android_video_player_mvp/data/services/playback_controller.dart';
import 'package:android_video_player_mvp/data/services/preference_service.dart';
import 'package:android_video_player_mvp/domain/models/app_settings.dart';
import 'package:android_video_player_mvp/domain/models/media_item.dart';
import 'package:android_video_player_mvp/ui/features/player/view_models/player_view_model.dart';

MediaItem video(String id) => MediaItem(
  id: id,
  title: id,
  duration: const Duration(minutes: 4),
  width: 1920,
  height: 1080,
  folderName: 'Movies',
  folderId: 'folder',
  modifiedAt: null,
);

class FakeMedia extends MediaRepository {
  FakeMedia() : super(MediaLibraryService());
  @override
  Future<File?> fileFor(String id) async => File('$id.mp4');
}

class FakeController extends PlaybackController {
  FakeController(super.file, super.decoderMode) : super.stub();

  static const _duration = Duration(minutes: 4);
  static const _size = Size(1920, 1080);
  int plays = 0;
  bool isDisposed = false;

  @override
  Future<void> initialize() async {
    value = const PlaybackValue(
      isInitialized: true,
      duration: _duration,
      size: _size,
    );
  }

  @override
  Future<void> play() async {
    plays++;
    value = const PlaybackValue(
      isInitialized: true,
      isPlaying: true,
      duration: _duration,
      size: _size,
    );
  }

  @override
  Future<void> pause() async {
    value = const PlaybackValue(
      isInitialized: true,
      position: Duration(minutes: 2),
      duration: _duration,
      size: _size,
    );
  }

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setAudioDelay(double seconds) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> dispose() async {
    isDisposed = true;
    await super.dispose();
  }

  void finish() {
    value = const PlaybackValue(
      isInitialized: true,
      isCompleted: true,
      position: _duration,
      duration: _duration,
      size: _size,
    );
  }

  void stallAtEnd() {
    value = PlaybackValue(
      isInitialized: true,
      position: _duration - const Duration(milliseconds: 200),
      duration: _duration,
      size: _size,
    );
  }
}

Future<void> flush() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<SettingsRepository> makeRepository() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = PreferenceService();
  await prefs.init();
  return SettingsRepository(prefs);
}

Future<({PlayerViewModel vm, List<FakeController> created})> startPlayer(
  List<MediaItem> queue,
  MediaItem initial,
) async {
  final created = <FakeController>[];
  final vm = PlayerViewModel(
    mediaRepository: FakeMedia(),
    settingsRepository: await makeRepository(),
    settings: AppSettings.defaults(),
    queue: queue,
    initialItem: initial,
    controllerFactory: (file, decoderMode) {
      final controller = FakeController(file, decoderMode);
      created.add(controller);
      return controller;
    },
  );
  await vm.init();
  await flush();
  return (vm: vm, created: created);
}

void main() {
  final first = video('first');
  final second = video('second');

  test('finishing a video auto plays the next queue item', () async {
    final player = await startPlayer([first, second], first);
    expect(player.vm.currentItem.id, first.id);
    expect(player.created.single.plays, 1);

    player.created.single.finish();
    await flush();

    expect(player.vm.currentItem.id, second.id);
    expect(player.created, hasLength(2));
    expect(player.created.first.isDisposed, isTrue);
    expect(player.created.last.plays, 1);
    expect(player.vm.hasReachedEnd, isFalse);
    player.vm.dispose();
  });

  test(
    'a decoder that stalls at the end without completing still advances',
    () async {
      final player = await startPlayer([first, second], first);

      player.created.single.stallAtEnd();
      await flush();

      expect(player.vm.currentItem.id, second.id);
      expect(player.created.last.plays, 1);
      player.vm.dispose();
    },
  );

  test('loop keeps replaying instead of advancing', () async {
    final player = await startPlayer([first, second], first);
    await player.vm.toggleLoop();

    player.created.single.finish();
    await flush();

    expect(player.vm.currentItem.id, first.id);
    expect(player.created, hasLength(1));
    expect(player.vm.hasReachedEnd, isTrue);
    player.vm.dispose();
  });

  test('pausing mid-video does not advance', () async {
    final player = await startPlayer([first, second], first);

    await player.vm.pause();
    await flush();

    expect(player.vm.currentItem.id, first.id);
    expect(player.created, hasLength(1));
    player.vm.dispose();
  });

  test('finishing the last queue item stays on it', () async {
    final player = await startPlayer([first, second], second);
    expect(player.vm.hasNext, isFalse);

    player.created.single.finish();
    await flush();

    expect(player.vm.currentItem.id, second.id);
    expect(player.created, hasLength(1));
    expect(player.vm.hasReachedEnd, isTrue);
    player.vm.dispose();
  });
}
