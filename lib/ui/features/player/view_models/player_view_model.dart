import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../../../data/services/playback_controller.dart';
import '../../../../data/services/subtitle_folder_service.dart';
import '../../../../domain/models/decoder_mode.dart';

import '../../../../data/repositories/media_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/media_item.dart';

class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel({
    required MediaRepository mediaRepository,
    required SettingsRepository settingsRepository,
    required AppSettings settings,
    required List<MediaItem> queue,
    required MediaItem initialItem,
  }) : _mediaRepository = mediaRepository,
       _settingsRepository = settingsRepository,
       _settings = settings,
       _queue = queue.isEmpty ? [initialItem] : queue,
       _currentIndex = max(
         0,
         queue.indexWhere((item) => item.id == initialItem.id),
       );

  final MediaRepository _mediaRepository;
  final SettingsRepository _settingsRepository;
  AppSettings _settings;
  final List<MediaItem> _queue;
  int _currentIndex;
  PlaybackController? controller;
  DecoderMode get decoderMode =>
      controller?.decoderMode ?? _settingsRepository.decoderMode;

  Future<void> setDecoderMode(DecoderMode mode) async {
    if (_disposed || isLoading) return;
    if (!isInitialized) {
      await _settingsRepository.setDecoderMode(mode);
      if (!_disposed) await _loadCurrent();
      return;
    }
    await _operate((video) => video.setDecoderMode(mode));
    if (!_disposed && controller?.decoderMode == mode) {
      await _settingsRepository.setDecoderMode(mode);
    }
  }

  Timer? _positionTimer;
  bool _disposed = false;
  bool _firstFile = true;
  bool isLoading = false;
  bool controlsLocked = false;
  bool controlsVisible = true;
  bool fitToScreen = true;
  bool loop = false;
  bool muted = false;
  double volume = 1;
  bool shuffle = false;
  String? errorMessage;
  String? subtitleName;
  bool get hasLoadedSubtitle => isInitialized && subtitleName != null;
  double audioDelay = 0;
  String? subtitleWarning;
  int _subtitleGeneration = 0;

  MediaItem get currentItem => _queue[_currentIndex];
  List<MediaItem> get queue => List.unmodifiable(_queue);
  bool get hasPrevious => _currentIndex > 0;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get isInitialized => controller?.value.isInitialized ?? false;
  PlaybackController? _completedController;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> init() async {
    fitToScreen = _settings.aspectFitMode;
    await _loadCurrent();
  }

  void _onVideoChanged() {
    final video = controller;
    if (video == null) return;
    final value = video.value;
    if (value.hasError) {
      errorMessage = value.errorDescription;
    }
    if (value.isCompleted && !loop && _completedController != video) {
      _completedController = video;
      if (hasNext || (shuffle && _queue.length > 1)) {
        unawaited(next());
      }
    }
    _notify();
  }

  Future<void> _loadCurrent({Duration? position}) async {
    if (_disposed || isLoading) return;
    isLoading = true;
    errorMessage = null;
    subtitleName = null;
    subtitleWarning = null;
    _subtitleGeneration++;
    _positionTimer?.cancel();
    final old = controller;
    controller = null;
    old?.removeListener(_onVideoChanged);
    _notify();
    try {
      await old?.dispose();
      if (_disposed) return;
      final file = await _mediaRepository.fileFor(currentItem.id);
      if (_disposed) return;
      if (file == null) {
        throw StateError('The selected media file is not available.');
      }
      final video = PlaybackController.file(
        file,
        decoderMode: _settingsRepository.decoderMode,
      );
      controller = video;
      await video.initialize();
      if (_disposed) return;
      audioDelay = _settingsRepository.audioDelayFor(currentItem.id);
      await video.setAudioDelay(audioDelay);
      await video.setPlaybackSpeed(_settings.defaultPlaybackSpeed);
      if (_disposed) return;
      await video.setLooping(loop);
      await video.setVolume(muted ? 0 : _playerGain);
      if (_disposed) return;
      final resume =
          position ??
          (_settings.resumePlayback &&
                  (_firstFile ||
                      !_settingsRepository.option('resumeFirst', false))
              ? _settingsRepository.lastPositionFor(currentItem.id)
              : Duration.zero);
      if (resume > Duration.zero &&
          resume < video.value.duration - const Duration(seconds: 1)) {
        await video.seekTo(resume);
      }
      if (_disposed) return;
      _firstFile = false;
      video.addListener(_onVideoChanged);
      await video.play();
      if (_disposed) return;
      await _markCurrentItemAsWatched();
      unawaited(_loadMatchingSubtitle(video, _subtitleGeneration));
      _positionTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _savePosition(),
      );
    } catch (error) {
      if (!_disposed) errorMessage = 'Could not play this video.\n$error';
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> _operate(
    Future<void> Function(PlaybackController) action,
  ) async {
    final video = controller;
    if (_disposed || isLoading || video == null || !video.value.isInitialized) {
      return;
    }
    try {
      await action(video);
    } catch (error) {
      if (!_disposed) errorMessage = 'Playback failed: $error';
    }
    _notify();
  }

  Future<void> setAudioDelay(double seconds) async {
    final video = controller;
    final id = currentItem.id;
    if (_disposed || isLoading || video == null || !isInitialized) return;
    final value = seconds.clamp(-3.0, 3.0);
    await video.setAudioDelay(value);
    if (_disposed || controller != video) return;
    audioDelay = value;
    _notify();
    await _settingsRepository.setAudioDelay(id, value);
  }

  Future<void> togglePlayback() =>
      _operate((video) => video.value.isPlaying ? video.pause() : video.play());
  Future<void> pause() => _operate((video) => video.pause());
  Future<void> seekTo(Duration position) => _operate(
    (video) => video.seekTo(
      Duration(
        milliseconds: position.inMilliseconds.clamp(
          0,
          video.value.duration.inMilliseconds,
        ),
      ),
    ),
  );
  Future<void> seekBy(int seconds) => seekTo(
    (controller?.value.position ?? Duration.zero) + Duration(seconds: seconds),
  );
  Future<void> setPlaybackSpeed(double speed) =>
      _operate((video) => video.setPlaybackSpeed(speed));

  double get _playerGain => volume <= 1 ? 1 : volume;

  Future<void> setVolume(double value) async {
    volume = value.clamp(0.0, 2.0);
    if (volume > 0) muted = false;
    await _operate((video) => video.setVolume(muted ? 0 : _playerGain));
  }

  Future<void> toggleMute() async {
    muted = !muted;
    await _operate((video) => video.setVolume(muted ? 0 : _playerGain));
  }

  Future<void> toggleLoop() async {
    loop = !loop;
    await _operate((video) => video.setLooping(loop));
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    _notify();
  }

  void toggleLock() {
    controlsLocked = !controlsLocked;
    controlsVisible = true;
    _notify();
  }

  void toggleControls() {
    if (!controlsLocked) {
      controlsVisible = !controlsVisible;
      _notify();
    }
  }

  void hideControls() {
    if (!controlsLocked && controlsVisible) {
      controlsVisible = false;
      _notify();
    }
  }

  void toggleFit() {
    fitToScreen = !fitToScreen;
    _notify();
  }

  Future<void> previous() async {
    if (isLoading || _disposed) return;
    if (!hasPrevious ||
        (_settingsRepository.option('smartPrevious', true) &&
            (controller?.value.position.inSeconds ?? 0) > 3)) {
      await seekTo(Duration.zero);
      return;
    }
    await playIndex(_currentIndex - 1);
  }

  Future<void> next() async {
    if (isLoading || _disposed) return;
    if (shuffle && _queue.length > 1) {
      await playIndex(
        (_currentIndex + 1 + Random().nextInt(_queue.length - 1)) %
            _queue.length,
      );
    } else if (hasNext) {
      await playIndex(_currentIndex + 1);
    }
  }

  Future<void> playIndex(int index) async {
    if (_disposed || isLoading || index < 0 || index >= _queue.length) return;
    // Set the loading guard before awaiting persisted state to prevent two queue taps racing.
    isLoading = true;
    await _savePosition();
    if (_disposed) return;
    _currentIndex = index;
    isLoading = false;
    await _loadCurrent();
  }

  Future<void> setBackgroundAudio(bool enabled) async {
    if (_disposed || isLoading) return;
    _settings = _settings.copyWith(backgroundAudio: enabled);
    await _loadCurrent(position: controller?.value.position);
  }

  Future<void> pickSubtitle() async {
    // A manual selection takes precedence over any in-flight automatic lookup.
    _subtitleGeneration++;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['srt', 'vtt'],
      );
      if (_disposed || file?.path == null) return;
      final video = controller;
      if (video == null || !video.value.isInitialized) return;
      await video.setSubtitleFile(file!.path!, file.name);
      if (_disposed || video != controller) return;
      subtitleName = file.name;
      subtitleWarning = null;
      _notify();
    } catch (error) {
      if (!_disposed) {
        errorMessage = 'Could not open subtitles: $error';
        _notify();
      }
    }
  }

  Future<void> _loadMatchingSubtitle(
    PlaybackController video,
    int generation,
  ) async {
    final folder = _settingsRepository.subtitleFolder;
    if (folder == null) return;
    final title = currentItem.title;
    bool isCurrent() =>
        !_disposed && controller == video && generation == _subtitleGeneration;
    try {
      final path = await SubtitleFolderService().findSubtitle(
        folder.uri,
        title,
      );
      if (path == null || !isCurrent()) return;
      await video.setSubtitleFile(
        path,
        SubtitleFolderService.matchingName(title),
      );
      if (!isCurrent()) return;
      subtitleName = SubtitleFolderService.matchingName(title);
      _notify();
    } catch (_) {
      if (!isCurrent()) return;
      subtitleWarning =
          'Could not load the matching subtitle. Check the file or choose your subtitle folder again in Settings > Subtitle.';
      _notify();
    }
  }

  Future<void> _savePosition() async {
    final video = controller;
    final id = currentItem.id;
    if (video == null || !video.value.isInitialized) return;
    try {
      await _settingsRepository.saveLastPosition(id, video.value.position);
    } catch (_) {
      /* Persistence failure must not interrupt playback. */
    }
  }

  Future<void> _markCurrentItemAsWatched() async {
    try {
      await _settingsRepository.markLastWatched(
        mediaId: currentItem.id,
        folderId: currentItem.folderId,
      );
    } catch (_) {
      /* Watch history failure must not interrupt playback. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _positionTimer?.cancel();
    _savePosition();
    controller?.removeListener(_onVideoChanged);
    controller?.dispose();
    super.dispose();
  }
}
