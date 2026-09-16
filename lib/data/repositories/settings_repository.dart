import '../../domain/models/app_settings.dart';
import '../../domain/models/decoder_mode.dart';
import '../services/preference_service.dart';
import '../services/subtitle_folder_service.dart';

class SettingsRepository {
  SettingsRepository(this._preferenceService);

  final PreferenceService _preferenceService;
  SubtitleFolder? get subtitleFolder {
    final uri = _preferenceService.getString('settings.subtitleFolderUri');
    if (uri == null) return null;
    return SubtitleFolder(
      uri: uri,
      name:
          _preferenceService.getString('settings.subtitleFolderName') ??
          'Selected folder',
    );
  }

  Future<void> setSubtitleFolder(SubtitleFolder? folder) async {
    if (folder == null) {
      await _preferenceService.remove('settings.subtitleFolderUri');
      await _preferenceService.remove('settings.subtitleFolderName');
    } else {
      await _preferenceService.setString(
        'settings.subtitleFolderName',
        folder.name,
      );
      await _preferenceService.setString(
        'settings.subtitleFolderUri',
        folder.uri,
      );
    }
  }

  DecoderMode get decoderMode {
    final index = _preferenceService.getInt(
      'settings.decoderMode',
      DecoderMode.hwPlus.index,
    );
    return DecoderMode.values[index.clamp(0, DecoderMode.values.length - 1)];
  }

  Future<void> setDecoderMode(DecoderMode mode) =>
      _preferenceService.setInt('settings.decoderMode', mode.index);

  static const _resumePlayback = 'settings.resumePlayback';
  static const _backgroundAudio = 'settings.backgroundAudio';
  static const _clearHistoryOnExit = 'settings.clearHistoryOnExit';
  static const _aspectFitMode = 'settings.aspectFitMode';
  static const _defaultPlaybackSpeed = 'settings.defaultPlaybackSpeed';
  static const _playbackPositionPrefix = 'playback.position.';
  static const _lastWatchedMediaId = 'playback.lastWatchedMediaId';
  static const _lastWatchedFolderId = 'playback.lastWatchedFolderId';

  double get seekSensitivity =>
      _preferenceService.getDouble('ui.seekSensitivity', 1).clamp(0.25, 4);
  Future<void> setSeekSensitivity(double value) =>
      _preferenceService.setDouble('ui.seekSensitivity', value.clamp(0.25, 4));
  double audioDelayFor(String id) =>
      _preferenceService.getDouble('audioDelay.$id', 0).clamp(-3, 3);
  Future<void> setAudioDelay(String id, double seconds) =>
      _preferenceService.setDouble('audioDelay.$id', seconds.clamp(-3, 3));

  bool option(String key, bool fallback) =>
      _preferenceService.getBool('ui.$key', fallback);
  Future<void> setOption(String key, bool value) =>
      _preferenceService.setBool('ui.$key', value);
  double get subtitleSize =>
      _preferenceService.getDouble('ui.subtitleSize', 20);
  Future<void> setSubtitleSize(double value) =>
      _preferenceService.setDouble('ui.subtitleSize', value);
  Duration? bookmarkFor(String id) {
    final value = _preferenceService.getInt('bookmark.$id', -1);
    return value < 0 ? null : Duration(milliseconds: value);
  }

  Future<void> saveBookmark(String id, Duration value) =>
      _preferenceService.setInt('bookmark.$id', value.inMilliseconds);

  AppSettings load() {
    final defaults = AppSettings.defaults();
    return AppSettings(
      resumePlayback: _preferenceService.getBool(
        _resumePlayback,
        defaults.resumePlayback,
      ),
      backgroundAudio: _preferenceService.getBool(
        _backgroundAudio,
        defaults.backgroundAudio,
      ),
      clearHistoryOnExit: _preferenceService.getBool(
        _clearHistoryOnExit,
        defaults.clearHistoryOnExit,
      ),
      aspectFitMode: _preferenceService.getBool(
        _aspectFitMode,
        defaults.aspectFitMode,
      ),
      defaultPlaybackSpeed: _preferenceService.getDouble(
        _defaultPlaybackSpeed,
        defaults.defaultPlaybackSpeed,
      ),
    );
  }

  Future<void> save(AppSettings settings) async {
    await _preferenceService.setBool(_resumePlayback, settings.resumePlayback);
    await _preferenceService.setBool(
      _backgroundAudio,
      settings.backgroundAudio,
    );
    await _preferenceService.setBool(
      _clearHistoryOnExit,
      settings.clearHistoryOnExit,
    );
    await _preferenceService.setBool(_aspectFitMode, settings.aspectFitMode);
    await _preferenceService.setDouble(
      _defaultPlaybackSpeed,
      settings.defaultPlaybackSpeed,
    );
  }

  Duration lastPositionFor(String mediaId) {
    final millis = _preferenceService.getInt(
      '$_playbackPositionPrefix$mediaId',
      0,
    );
    return Duration(milliseconds: millis);
  }

  Future<void> saveLastPosition(String mediaId, Duration position) {
    return _preferenceService.setInt(
      '$_playbackPositionPrefix$mediaId',
      position.inMilliseconds,
    );
  }

  String? get lastWatchedMediaId =>
      _preferenceService.getString(_lastWatchedMediaId);
  String? get lastWatchedFolderId =>
      _preferenceService.getString(_lastWatchedFolderId);

  Future<void> markLastWatched({
    required String mediaId,
    String? folderId,
  }) async {
    await _preferenceService.setString(_lastWatchedMediaId, mediaId);
    if (folderId == null) {
      await _preferenceService.remove(_lastWatchedFolderId);
    } else {
      await _preferenceService.setString(_lastWatchedFolderId, folderId);
    }
  }

  Future<void> clearHistory() async {
    await _preferenceService.clearByPrefix(_playbackPositionPrefix);
    await _preferenceService.remove(_lastWatchedMediaId);
    await _preferenceService.remove(_lastWatchedFolderId);
  }

  Future<void> resetSettings() async {
    await _preferenceService.clearByPrefix('audioDelay.');
    await setSubtitleFolder(null);
    await setDecoderMode(DecoderMode.hwPlus);
    await _preferenceService.clearByPrefix('ui.');
    await save(AppSettings.defaults());
  }
}
