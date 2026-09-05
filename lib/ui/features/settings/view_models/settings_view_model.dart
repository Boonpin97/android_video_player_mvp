import 'package:flutter/foundation.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/models/app_settings.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._settingsRepository)
    : settings = _settingsRepository.load();

  final SettingsRepository _settingsRepository;
  AppSettings settings;

  SettingsRepository get repository => _settingsRepository;

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
