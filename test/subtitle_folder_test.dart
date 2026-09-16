import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_video_player_mvp/data/repositories/settings_repository.dart';
import 'package:android_video_player_mvp/data/services/preference_service.dart';
import 'package:android_video_player_mvp/data/services/subtitle_folder_service.dart';
import 'package:android_video_player_mvp/ui/features/settings/view_models/settings_view_model.dart';
import 'package:android_video_player_mvp/ui/features/settings/views/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('player/device');
  const folderUri =
      'content://com.android.externalstorage.documents/tree/primary%3ASubtitles';
  late SettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferenceService();
    await preferences.init();
    repository = SettingsRepository(preferences);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('SRT matching removes only the final video extension', () {
    expect(
      SubtitleFolderService.matchingName('Movie.Part.2.wmv'),
      'Movie.Part.2.srt',
    );
    expect(
      SubtitleFolderService.matchingName('A movie (2026).MP4'),
      'A movie (2026).srt',
    );
    expect(SubtitleFolderService.matchingName('Movie'), 'Movie.srt');
  });

  test('folder choice survives restart and reset clears it', () async {
    await repository.setSubtitleFolder(
      const SubtitleFolder(uri: folderUri, name: 'Subtitles'),
    );
    final preferences = PreferenceService();
    await preferences.init();
    final reloaded = SettingsRepository(preferences);
    expect(reloaded.subtitleFolder?.uri, folderUri);
    expect(reloaded.subtitleFolder?.name, 'Subtitles');
    await reloaded.resetSettings();
    expect(reloaded.subtitleFolder, isNull);
  });

  test(
    'lookup uses the granted folder and exact SRT name; missing match is optional',
    () async {
      var requests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'findSubtitle');
            expect(call.arguments['uri'], folderUri);
            expect(call.arguments['name'], 'Movie.Part.2.srt');
            requests++;
            return requests == 1 ? '/cache/matched_subtitles/movie.srt' : null;
          });
      final service = SubtitleFolderService();
      expect(
        await service.findSubtitle(folderUri, 'Movie.Part.2.wmv'),
        '/cache/matched_subtitles/movie.srt',
      );
      expect(await service.findSubtitle(folderUri, 'Movie.Part.2.wmv'), isNull);
    },
  );

  testWidgets(
    'folder settings select, display, cancel without losing choice, and clear',
    (tester) async {
      var picks = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'pickSubtitleFolder');
            picks++;
            if (picks == 2) {
              expect(call.arguments['initialUri'], folderUri);
              return null;
            }
            return {'uri': folderUri, 'name': 'My subtitles'};
          });
      final settings = SettingsViewModel(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsCategoryPage(title: 'Subtitle', viewModel: settings),
        ),
      );
      await tester.tap(find.text('Subtitle Folder'));
      await tester.pumpAndSettle();
      expect(find.textContaining('My subtitles'), findsOneWidget);
      expect(repository.subtitleFolder?.uri, folderUri);
      await tester.tap(find.text('Subtitle Folder'));
      await tester.pumpAndSettle();
      expect(repository.subtitleFolder?.uri, folderUri);
      await tester.tap(find.text('Clear subtitle folder'));
      await tester.pumpAndSettle();
      expect(repository.subtitleFolder, isNull);
      expect(find.textContaining('My subtitles'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
    },
  );
}
