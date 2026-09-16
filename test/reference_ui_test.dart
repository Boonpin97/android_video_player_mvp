import 'package:android_video_player_mvp/domain/models/decoder_mode.dart';
import 'package:android_video_player_mvp/ui/features/library/views/home_shell.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_video_player_mvp/data/repositories/media_repository.dart';
import 'package:android_video_player_mvp/data/repositories/settings_repository.dart';
import 'package:android_video_player_mvp/data/services/media_library_service.dart';
import 'package:android_video_player_mvp/data/services/preference_service.dart';
import 'package:android_video_player_mvp/domain/models/media_folder.dart';
import 'package:android_video_player_mvp/domain/models/media_item.dart';
import 'package:android_video_player_mvp/ui/core/app_theme.dart';
import 'package:android_video_player_mvp/ui/features/library/view_models/library_view_model.dart';
import 'package:android_video_player_mvp/ui/features/library/views/library_page.dart';
import 'package:android_video_player_mvp/ui/features/player/view_models/player_view_model.dart';
import 'package:android_video_player_mvp/ui/features/player/views/player_page.dart';
import 'package:android_video_player_mvp/ui/features/settings/view_models/settings_view_model.dart';
import 'package:android_video_player_mvp/ui/features/settings/views/settings_page.dart';

const folder = MediaFolder(id: 'folder', name: 'Movies', assetCount: 5000);
const item = MediaItem(
  id: 'video',
  title: 'A video with a long title for a narrow screen',
  duration: Duration(minutes: 4),
  width: 1920,
  height: 1080,
  folderName: 'Movies',
  folderId: 'folder',
  modifiedAt: null,
);

class FakeMedia extends MediaRepository {
  FakeMedia() : super(MediaLibraryService());
  int folderLoads = 0;
  Completer<MediaFolderContents>? pendingFolder;
  Completer<File?>? pendingFile;
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<MediaFolder>> loadFolders() async => [folder];
  @override
  Future<MediaFolderContents> loadFolder(MediaFolder folder) {
    folderLoads++;
    return pendingFolder?.future ??
        Future.value(MediaFolderContents(folder: folder, items: [item]));
  }

  @override
  Future<File?> fileFor(String id) => pendingFile?.future ?? Future.value(null);
}

Future<SettingsViewModel> makeSettings() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = PreferenceService();
  await prefs.init();
  return SettingsViewModel(SettingsRepository(prefs));
}

void main() {
  test('decoder choice persists across repositories', () async {
    final settings = await makeSettings();
    expect(settings.repository.decoderMode, DecoderMode.hwPlus);
    await settings.setDecoderMode(DecoderMode.sw);
    final reloaded = PreferenceService();
    await reloaded.init();
    expect(SettingsRepository(reloaded).decoderMode, DecoderMode.sw);
    settings.dispose();
  });

  test('back from nested folder returns to parent then root', () async {
    final vm = LibraryViewModel(FakeMedia());
    await vm.load();
    await vm.selectFolder(folder);
    const child = MediaFolder(id: 'child', name: 'Child', assetCount: 1);
    await vm.selectFolder(child);
    await vm.goUp();
    expect(vm.selectedFolder?.id, folder.id);
    await vm.goUp();
    expect(vm.selectedFolder, isNull);
    expect(vm.folders, [folder]);
    vm.dispose();
  });

  testWidgets('Local has only Local and Me tabs without shortcut headers', (
    tester,
  ) async {
    final settings = await makeSettings();
    final media = FakeMedia();
    final library = LibraryViewModel(media);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeShell(
          libraryViewModel: library,
          settingsViewModel: settings,
          mediaRepository: media,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.items.map((item) => item.label), ['Local', 'Me']);
    for (final label in ['Music', 'Transfer', 'File Transfer', 'Recent']) {
      expect(find.text(label), findsNothing);
    }
    expect(find.text('Movies'), findsOneWidget);
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    expect(find.text('Your video player'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    library.dispose();
    settings.dispose();
  });

  test('initial library load lists folders without opening videos', () async {
    final media = FakeMedia();
    final vm = LibraryViewModel(media);
    await vm.load();
    expect(vm.folders, [folder]);
    expect(vm.selectedFolder, isNull);
    expect(vm.items, isEmpty);
    expect(media.folderLoads, 0);
    expect(vm.isLoading, isFalse);
    vm.dispose();
  });

  testWidgets('last watched video and its folder use blue titles', (
    tester,
  ) async {
    final settings = await makeSettings();
    await settings.repository.markLastWatched(
      mediaId: item.id,
      folderId: folder.id,
    );
    final media = FakeMedia();
    final library = LibraryViewModel(media);
    await library.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LibraryPage(
          viewModel: library,
          settingsViewModel: settings,
          mediaRepository: media,
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Movies')).style?.color,
      AppTheme.blue,
    );
    await tester.tap(find.text('Movies'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Text>(find.text(item.title)).style?.color,
      AppTheme.blue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    library.dispose();
    settings.dispose();
  });

  test('returning to folders ignores a late video load', () async {
    final media = FakeMedia()..pendingFolder = Completer();
    final vm = LibraryViewModel(media);
    await vm.load();
    final opening = vm.selectFolder(folder);
    vm.showFolders();
    media.pendingFolder!.complete(
      MediaFolderContents(folder: folder, items: [item]),
    );
    await opening;
    expect(vm.selectedFolder, isNull);
    expect(vm.items, isEmpty);
    expect(vm.isLoading, isFalse);
    vm.dispose();
  });

  test('late folder error cannot replace a newer screen', () async {
    final media = FakeMedia()..pendingFolder = Completer();
    final vm = LibraryViewModel(media);
    final opening = vm.selectFolder(folder);
    vm.showFolders();
    media.pendingFolder!.completeError(StateError('Folder removed'));
    await opening;
    expect(vm.errorMessage, isNull);
    vm.dispose();
  });

  test(
    'closing player during media lookup does not notify after disposal',
    () async {
      final settings = await makeSettings();
      final media = FakeMedia()..pendingFile = Completer();
      final vm = PlayerViewModel(
        mediaRepository: media,
        settingsRepository: settings.repository,
        settings: settings.settings,
        queue: [item],
        initialItem: item,
      );
      final opening = vm.init();
      await Future<void>.delayed(Duration.zero);
      vm.dispose();
      media.pendingFile!.complete(null);
      await expectLater(opening, completes);
      settings.dispose();
    },
  );

  testWidgets('settings categories navigate and supported checkbox persists', (
    tester,
  ) async {
    final settings = await makeSettings();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SettingsPage(viewModel: settings),
      ),
    );
    for (final label in [
      'List',
      'Player',
      'Decoder',
      'Audio',
      'Subtitle',
      'General',
      'Development',
      'App Language',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Player'));
    await tester.pumpAndSettle();
    expect(find.text('Interface'), findsOneWidget);
    await tester.tap(find.text('Double-tap the back button'));
    await tester.pumpAndSettle();
    expect(settings.repository.option('doubleBack', false), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unavailable audio controls explain availability without toggling',
    (tester) async {
      final settings = await makeSettings();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SettingsCategoryPage(title: 'Audio', viewModel: settings),
        ),
      );
      await tester.tap(find.text('Volume boost'));
      await tester.pumpAndSettle();
      expect(
        find.text('This feature is not available in this version yet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'player controls fade after idle time and use larger skip targets',
    (tester) async {
      final settings = await makeSettings();
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerPage(
            initialItem: item,
            queue: [item],
            settingsViewModel: settings,
            mediaRepository: FakeMedia(),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byTooltip('Previous video')),
        const Size(72, 72),
      );
      expect(tester.getSize(find.byTooltip('Next video')), const Size(72, 72));
      expect(tester.getSize(find.byTooltip('Play')), const Size(80, 72));

      // A stationary finger must keep controls visible, and touching the gap
      // next to a button must not toggle the underlying video controls.
      final previous = tester.getRect(find.byTooltip('Previous video'));
      final pointer = await tester.startGesture(
        Offset(previous.right + 6, previous.center.dy),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      await pointer.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0,
      );

      await tester.tapAt(const Offset(200, 200));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      settings.dispose();
    },
  );

  for (final size in [const Size(393, 852), const Size(852, 393)]) {
    testWidgets('player menus fit ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = await makeSettings();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PlayerPage(
            initialItem: item,
            queue: [item],
            settingsViewModel: settings,
            mediaRepository: FakeMedia(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Video Display'), findsOneWidget);
      expect(
        tester.getRect(find.text('Shortcuts')).bottom,
        lessThanOrEqualTo(size.height),
      );
      expect(find.byType(Switch).last.hitTestable(), findsOneWidget);
      expect(find.text('Bookmark'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Screen Rotation'), findsOneWidget);
      expect(find.text('Playback Speed'), findsOneWidget);
      expect(find.text('Audio sync').hitTestable(), findsOneWidget);
      expect(find.text('Seek sensitivity').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Vertical Flip'));
      await tester.pumpAndSettle();
      expect(find.text('Vertical Flip').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
