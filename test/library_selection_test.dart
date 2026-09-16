import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_video_player_mvp/data/repositories/media_repository.dart';
import 'package:android_video_player_mvp/data/services/media_library_service.dart';
import 'package:android_video_player_mvp/data/services/media_library_index.dart';
import 'package:android_video_player_mvp/domain/models/media_deletion_result.dart';
import 'package:android_video_player_mvp/domain/models/media_folder.dart';
import 'package:android_video_player_mvp/domain/models/media_preview.dart';
import 'package:android_video_player_mvp/ui/features/library/view_models/library_view_model.dart';
import 'package:android_video_player_mvp/ui/features/library/views/library_page.dart';
import 'reference_ui_test.dart' show makeSettings;
import 'folders_and_gestures_test.dart' show row;

class SelectionMedia extends MediaRepository {
  SelectionMedia() : super(MediaLibraryService());
  final rows = [
    row('a', 'Movies/'),
    row('b', 'Movies/'),
    row('c', 'Movies/Series/'),
    row('d', 'Download/'),
  ];
  MediaLibraryIndex get index => MediaLibraryIndex.fromRows(rows);
  final requests = <Set<String>>[];
  Completer<MediaDeletionResult>? pending;
  MediaDeletionResult? response;
  int openedFiles = 0;
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<List<MediaFolder>> loadFolders() async => index.roots;
  @override
  Future<MediaFolderContents> loadFolder(MediaFolder folder) async =>
      index.contents(folder);
  @override
  Future<Set<String>> videoIdsInFolders(Iterable<String> ids) async =>
      index.videoIdsInFolders(ids);
  @override
  Future<MediaPreview?> thumbnailFor(String assetId) async => null;
  @override
  Future<File?> fileFor(String id) async {
    openedFiles++;
    return null;
  }

  @override
  Future<MediaDeletionResult> deleteByIds(Iterable<String> ids) async {
    requests.add(ids.toSet());
    final result = pending != null
        ? await pending!.future
        : response ?? MediaDeletionResult(deletedIds: ids.toList());
    rows.removeWhere((row) => result.deletedIds.contains(row['id']));
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'folder expansion deduplicates descendants and isolates siblings and volumes',
    () {
      final index = MediaLibraryIndex.fromRows([
        row('a', 'Movies/'),
        row('b', 'Movies/Series/'),
        row('c', 'MoviesExtras/'),
        row('d', 'Movies/', volume: 'sdcard'),
      ]);
      expect(
        index.videoIdsInFolders([
          'external_primary|Movies',
          'external_primary|Movies/Series',
        ]),
        {'a', 'b'},
      );
      expect(index.videoIdsInFolders(['missing']), isEmpty);
    },
  );

  test(
    'folder deletion refreshes counts and returns from an emptied folder',
    () async {
      final media = SelectionMedia();
      final vm = LibraryViewModel(media);
      await vm.load();
      await vm.selectFolder(vm.folders.firstWhere((f) => f.name == 'Movies'));
      vm.selectVisible();
      await vm.deleteSelection();
      expect(media.requests.single, {'a', 'b', 'c'});
      expect(vm.selectedFolder, isNull);
      expect(vm.folders.map((f) => f.name), ['Download']);
      expect(vm.isSelecting, isFalse);
      expect(vm.errorMessage, isNull);
      vm.dispose();
    },
  );

  test('refresh leaves a folder removed outside the app', () async {
    final media = SelectionMedia();
    final vm = LibraryViewModel(media);
    await vm.load();
    await vm.selectFolder(
      vm.folders.firstWhere((folder) => folder.name == 'Movies'),
    );
    media.rows.removeWhere(
      (row) =>
          row['directory'] == 'Movies/' || row['directory'] == 'Movies/Series/',
    );

    await vm.refresh();

    expect(vm.selectedFolder, isNull);
    expect(vm.folders.map((folder) => folder.name), ['Download']);
    expect(vm.items, isEmpty);
    vm.dispose();
  });

  test(
    'partial deletion removes only confirmed videos and keeps remaining selection',
    () async {
      final media = SelectionMedia()
        ..response = const MediaDeletionResult(
          deletedIds: ['a'],
          cancelled: true,
        );
      final vm = LibraryViewModel(media);
      await vm.load();
      await vm.selectFolder(vm.folders.firstWhere((f) => f.name == 'Movies'));
      vm.toggleVideoSelection('a');
      vm.toggleVideoSelection('b');
      await vm.deleteSelection();
      expect(vm.items.map((v) => v.id), ['b']);
      expect(vm.selectedVideoIds, {'b'});
      expect(vm.selectedFolder!.assetCount, 2);
      expect(vm.errorMessage, contains('Some videos were deleted'));
      vm.clearSelection();
      expect(vm.errorMessage, isNull);
      vm.dispose();
    },
  );

  test(
    'pending consent blocks duplicate deletes and navigation; cancel keeps selection',
    () async {
      final media = SelectionMedia()..pending = Completer();
      final vm = LibraryViewModel(media);
      await vm.load();
      final folder = vm.folders.firstWhere((f) => f.name == 'Movies');
      vm.toggleFolderSelection(folder.id);
      final deleting = vm.deleteSelection();
      await Future<void>.delayed(Duration.zero);
      await vm.deleteSelection();
      await vm.selectFolder(folder);
      vm.clearSelection();
      expect(vm.selectedFolder, isNull);
      expect(vm.selectedFolderIds, {folder.id});
      expect(media.requests.length, 1);
      media.pending!.complete(const MediaDeletionResult(cancelled: true));
      await deleting;
      expect(vm.selectedFolderIds, {folder.id});
      expect(vm.isDeleting, isFalse);
      expect(media.rows.length, 4);
      vm.dispose();
    },
  );

  test(
    'finishing consent after disposal does not notify disposed listeners',
    () async {
      final media = SelectionMedia()..pending = Completer();
      final vm = LibraryViewModel(media);
      await vm.load();
      vm.toggleVideoSelection('a');
      final deleting = vm.deleteSelection();
      await Future<void>.delayed(Duration.zero);
      vm.dispose();
      media.pending!.complete(const MediaDeletionResult(deletedIds: ['a']));
      await expectLater(deleting, completes);
    },
  );

  for (final grid in [false, true]) {
    testWidgets(
      'long press folders and videos selects without opening in grid=$grid',
      (tester) async {
        final media = SelectionMedia()
          ..response = const MediaDeletionResult(cancelled: true);
        final vm = LibraryViewModel(media);
        await vm.load();
        if (grid) vm.toggleGridMode();
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
        await tester.longPress(find.text('Movies'));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        await tester.tap(find.text('Download'));
        await tester.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);
        expect(vm.selectedFolder, isNull);
        expect(find.byTooltip('Delete selected videos'), findsOneWidget);
        await tester.tap(find.byTooltip('Clear selection'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Movies'));
        await tester.pumpAndSettle();
        await tester.longPress(find.text('a.wmv'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('b.wmv'));
        await tester.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);
        expect(media.openedFiles, 0);
        await tester.tap(find.byTooltip('Delete selected videos'));
        await tester.pumpAndSettle();
        expect(media.requests.single, {'a', 'b'});
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('2 selected'), findsOneWidget);
        expect(find.text('a.wmv'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        vm.dispose();
        settings.dispose();
      },
    );
  }

  test(
    'native deletion deduplicates, batches 2000 IDs and stops on cancellation',
    () async {
      const channel = MethodChannel('com.fluttercandies/photo_manager');
      final requests = <List<String>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'deleteWithIds');
            final ids = List<String>.from((call.arguments as Map)['ids']);
            requests.add(ids);
            return requests.length == 1 ? ids : <String>[];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final service = MediaLibraryService();
      expect((await service.deleteByIds([])).deletedIds, isEmpty);
      expect(requests, isEmpty);
      final ids = List.generate(4500, (i) => '$i');
      final result = await service.deleteByIds([...ids, ...ids]);
      expect(requests.map((r) => r.length), [2000, 2000]);
      expect(result.deletedIds, ids.take(2000).toList());
      expect(result.cancelled, isTrue);
    },
  );
}
