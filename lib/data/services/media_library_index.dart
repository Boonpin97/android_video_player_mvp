import '../../domain/models/media_folder.dart';
import '../../domain/models/media_item.dart';

/// A hierarchy built from MediaStore relative paths, without a synthetic Recent album.
class MediaLibraryIndex {
  MediaLibraryIndex.fromRows(List<Map<String, Object?>> rows) {
    for (final row in rows) {
      final volume = (row['volume'] as String?) ?? 'external_primary';
      final parts = ((row['directory'] as String?) ?? '')
          .replaceAll('\\', '/')
          .split('/')
          .where((part) => part.isNotEmpty && part != '.')
          .toList();
      if (parts.contains('..')) continue;
      final parentId = '$volume|${parts.join('/')}';
      final item = MediaItem(
        id: row['id'] as String,
        title: (row['title'] as String?) ?? 'Video',
        duration: Duration(
          milliseconds: (row['duration'] as num?)?.toInt() ?? 0,
        ),
        width: (row['width'] as num?)?.toInt() ?? 0,
        height: (row['height'] as num?)?.toInt() ?? 0,
        folderName: parts.isEmpty ? 'Internal storage' : parts.last,
        folderId: parentId,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(
          ((row['modified'] as num?)?.toInt() ?? 0) * 1000,
        ),
      );
      _items.putIfAbsent(parentId, () => []).add(item);
      if (parts.isEmpty) {
        _names[parentId] = volume == 'external_primary'
            ? 'Internal storage'
            : 'Storage ($volume)';
        _roots.add(parentId);
        _counts.update(parentId, (count) => count + 1, ifAbsent: () => 1);
      }
      for (var depth = 1; depth <= parts.length; depth++) {
        final id = '$volume|${parts.take(depth).join('/')}';
        _names[id] = parts[depth - 1];
        _counts.update(id, (count) => count + 1, ifAbsent: () => 1);
        if (depth == 1) {
          _roots.add(id);
        } else {
          final parent = '$volume|${parts.take(depth - 1).join('/')}';
          _children.putIfAbsent(parent, () => {}).add(id);
        }
      }
    }
  }
  final Map<String, List<MediaItem>> _items = {};
  final Map<String, Set<String>> _children = {};
  final Map<String, String> _names = {};
  final Map<String, int> _counts = {};
  final Set<String> _roots = {};

  Set<String> videoIdsInFolders(Iterable<String> folderIds) {
    final result = <String>{};
    final visited = <String>{};
    final pending = folderIds.toList();
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!visited.add(id)) continue;
      result.addAll((_items[id] ?? []).map((item) => item.id));
      pending.addAll(_children[id] ?? {});
    }
    return result;
  }

  MediaFolder _folder(String id) => MediaFolder(
    id: id,
    name: _names[id]!,
    assetCount: _counts[id] ?? 0,
    folderCount: _children[id]?.length ?? 0,
  );
  List<MediaFolder> _folders(Iterable<String> ids) =>
      ids.map(_folder).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  List<MediaFolder> get roots => _folders(_roots);
  MediaFolderContents contents(MediaFolder folder) => MediaFolderContents(
    folder: _names.containsKey(folder.id)
        ? _folder(folder.id)
        : folder.copyWith(assetCount: 0, folderCount: 0),
    folders: _folders(_children[folder.id] ?? {}),
    items: List.unmodifiable(_items[folder.id] ?? []),
  );
}
