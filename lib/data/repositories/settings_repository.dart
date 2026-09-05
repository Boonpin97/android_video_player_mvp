import '../../domain/models/app_settings.dart';
import '../services/preference_service.dart';

class SettingsRepository {
  SettingsRepository(this._preferenceService);

  final PreferenceService _preferenceService;

  static const _resumePlayback = 'settings.resumePlayback';
  static const _backgroundAudio = 'settings.backgroundAudio';
  static const _clearHistoryOnExit = 'settings.clearHistoryOnExit';
  static const _aspectFitMode = 'settings.aspectFitMode';
  static const _defaultPlaybackSpeed = 'settings.defaultPlaybackSpeed';
  static const _playbackPositionPrefix = 'playback.position.';

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

  Future<void> clearHistory() {
    return _preferenceService.clearByPrefix(_playbackPositionPrefix);
  }

  Future<void> resetSettings() async {
    await save(AppSettings.defaults());
  }
}
