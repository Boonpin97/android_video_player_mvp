import 'dart:io';

import '../../domain/models/media_folder.dart';
import '../services/media_library_service.dart';

class MediaRepository {
  MediaRepository(this._mediaLibraryService);

  final MediaLibraryService _mediaLibraryService;

  Future<bool> requestAccess() {
    return _mediaLibraryService.requestAccess();
  }

  Future<List<MediaFolder>> loadFolders() {
    return _mediaLibraryService.loadFolders();
  }

  Future<MediaFolderContents> loadFolder(MediaFolder folder) {
    return _mediaLibraryService.loadFolder(folder);
  }

  Future<File?> fileFor(String assetId) {
    return _mediaLibraryService.fileFor(assetId);
  }

  Future<bool> deleteById(String assetId) {
    return _mediaLibraryService.deleteById(assetId);
  }
}
