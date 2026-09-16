import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class SubtitleFolder {
  const SubtitleFolder({required this.uri, required this.name});
  final String uri;
  final String name;
}

/// Uses Android's document picker so the selected folder stays readable after restart.
class SubtitleFolderService {
  static const _channel = MethodChannel('player/device');

  Future<SubtitleFolder?> pickFolder({String? initialUri}) async {
    final result = await _channel.invokeMapMethod<String, String>(
      'pickSubtitleFolder',
      {'initialUri': initialUri},
    );
    if (result == null) return null;
    return SubtitleFolder(uri: result['uri']!, name: result['name']!);
  }

  static String matchingName(String videoTitle) =>
      '${p.basenameWithoutExtension(videoTitle)}.srt';

  Future<String?> findSubtitle(String folderUri, String videoTitle) =>
      _channel.invokeMethod<String>('findSubtitle', {
        'uri': folderUri,
        'name': matchingName(videoTitle),
      });
}
