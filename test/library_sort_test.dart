import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_video_player_mvp/data/repositories/media_repository.dart';
import 'package:android_video_player_mvp/data/repositories/settings_repository.dart';
import 'package:android_video_player_mvp/data/services/media_library_index.dart';
import 'package:android_video_player_mvp/data/services/media_library_service.dart';
import 'package:android_video_player_mvp/data/services/preference_service.dart';
import 'package:android_video_player_mvp/domain/models/library_sort.dart';
import 'package:android_video_player_mvp/domain/models/media_folder.dart';
import 'package:android_video_player_mvp/domain/models/media_preview.dart';
import 'package:android_video_player_mvp/ui/features/library/view_models/library_view_model.dart';
import 'package:android_video_player_mvp/ui/features/library/views/library_page.dart';
import 'reference_ui_test.dart' show makeSettings;

Map<String, Object?> video(String id, String title, int modified) => {
  'id': id,
  'title': title,
  'directory': 'Movies/',
  'volume': 'external_primary',
  'duration': 100000,
  'width': 640,
  'height': 480,
  'modified': modified,
};

class SortMedia extends MediaRepository {
  SortMedia() : super(MediaLibraryService());
  final rows = [
    video('1', 'beta.wmv', 300),
    video('2', 'Alpha.wmv', 100),
    video('3', 'gamma.wmv', 200),
  ];
  MediaLibraryIndex get index => MediaLibraryIndex.fromRows(rows);
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<MediaFolder>> loadFolders() async => index.roots;
  @override
  Future<MediaFolderContents> loadFolder(MediaFolder folder) async =>
      index.contents(folder);
  @override
  Future<MediaPreview?> thumbnailFor(String assetId) async => null;
  @override
  Future<File?> fileFor(String id) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'videos sort by name and modification date in both directions',
    () async {
      final vm = LibraryViewModel(SortMedia());
      await vm.load();
      await vm.selectFolder(vm.folders.single);
      // Name order is case-insensitive, matching the MediaStore scan.
      expect(vm.filteredItems.map((v) => v.id), ['2', '1', '3']);
      vm.setSort(LibrarySort.nameDesc);
      expect(vm.filteredItems.map((v) => v.id), ['3', '1', '2']);
      expect(vm.sortedItems.map((v) => v.id), ['3', '1', '2']);
      vm.setSort(LibrarySort.dateNewest);
      expect(vm.filteredItems.map((v) => v.id), ['1', '3', '2']);
      vm.setSort(LibrarySort.dateOldest);
      expect(vm.filteredItems.map((v) => v.id), ['2', '3', '1']);
      // Sorting also applies while searching (every title contains 'a').
      vm.updateQuery('a');
      expect(vm.filteredItems.map((v) => v.id), ['2', '3', '1']);
      vm.dispose();
    },
  );

  test('library sort persists across restarts and resets', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferenceService();
    await preferences.init();
    final settings = SettingsRepository(preferences);
    expect(settings.librarySort, LibrarySort.nameAsc);
    await settings.setLibrarySort(LibrarySort.dateNewest);
    final freshPreferences = PreferenceService();
    await freshPreferences.init();
    final fresh = SettingsRepository(freshPreferences);
    expect(fresh.librarySort, LibrarySort.dateNewest);
    await fresh.resetSettings();
    expect(fresh.librarySort, LibrarySort.nameAsc);
  });

  testWidgets('sort menu hides at the root and reorders folder videos', (
    tester,
  ) async {
    final media = SortMedia();
    final vm = LibraryViewModel(media);
    await vm.load();
    final settings = await makeSettings();
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(
          viewModel: vm,
          settingsViewModel: settings,
          mediaRepository: media,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sort videos'), findsNothing);
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    double topOf(String title) => tester.getTopLeft(find.text(title)).dy;
    expect(topOf('Alpha.wmv'), lessThan(topOf('beta.wmv')));
    expect(topOf('beta.wmv'), lessThan(topOf('gamma.wmv')));

    await tester.tap(find.byTooltip('Sort videos'));
    await tester.pumpAndSettle();
    for (final option in LibrarySort.values) {
      expect(find.text(option.label), findsOneWidget);
    }
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    await tester.tap(find.text(LibrarySort.dateNewest.label));
    await tester.pumpAndSettle();

    expect(vm.sort, LibrarySort.dateNewest);
    expect(settings.repository.librarySort, LibrarySort.dateNewest);
    expect(topOf('beta.wmv'), lessThan(topOf('gamma.wmv')));
    expect(topOf('gamma.wmv'), lessThan(topOf('Alpha.wmv')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
    settings.dispose();
  });
}
