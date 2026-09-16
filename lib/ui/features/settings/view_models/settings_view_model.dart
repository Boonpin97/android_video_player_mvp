import 'package:flutter/foundation.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/decoder_mode.dart';
import '../../../../data/services/subtitle_folder_service.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._settingsRepository)
    : settings = _settingsRepository.load();

  final SettingsRepository _settingsRepository;
  AppSettings settings;

  SettingsRepository get repository => _settingsRepository;
  Future<void> chooseSubtitleFolder() async {
    final folder = await SubtitleFolderService().pickFolder(
      initialUri: repository.subtitleFolder?.uri,
    );
    if (folder != null) {
      await repository.setSubtitleFolder(folder);
      notifyListeners();
    }
  }

  Future<void> clearSubtitleFolder() async {
    await repository.setSubtitleFolder(null);
    notifyListeners();
  }

  Future<void> setDecoderMode(DecoderMode mode) async {
    await repository.setDecoderMode(mode);
    notifyListeners();
  }

  bool option(String key, [bool fallback = true]) =>
      repository.option(key, fallback);
  Future<void> setOption(String key, bool value) async {
    await repository.setOption(key, value);
    notifyListeners();
  }

  Future<void> setSeekSensitivity(double value) async {
    await repository.setSeekSensitivity(value);
    notifyListeners();
  }

  Future<void> setSubtitleSize(double value) async {
    await repository.setSubtitleSize(value);
    notifyListeners();
  }

  Future<void> update(AppSettings value) async {
    settings = value;
    notifyListeners();
    await _settingsRepository.save(value);
  }

  Future<void> setResumePlayback(bool value) {
    return update(settings.copyWith(resumePlayback: value));
  }

  Future<void> setBackgroundAudio(bool value) {
    return update(settings.copyWith(backgroundAudio: value));
  }

  Future<void> setAspectFitMode(bool value) {
    return update(settings.copyWith(aspectFitMode: value));
  }

  Future<void> setDefaultPlaybackSpeed(double value) {
    return update(settings.copyWith(defaultPlaybackSpeed: value));
  }

  Future<void> clearHistory() async {
    await _settingsRepository.clearHistory();
  }

  Future<void> resetSettings() async {
    await _settingsRepository.resetSettings();
    settings = _settingsRepository.load();
    notifyListeners();
  }
}
