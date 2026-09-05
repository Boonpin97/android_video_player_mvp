import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

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
       _queue = queue,
       _currentIndex = queue.indexWhere((item) => item.id == initialItem.id);

  final MediaRepository _mediaRepository;
  final SettingsRepository _settingsRepository;
  final AppSettings _settings;
  final List<MediaItem> _queue;
  int _currentIndex;
  VideoPlayerController? controller;
  Timer? _positionTimer;

  bool isLoading = false;
  bool controlsLocked = false;
  bool controlsVisible = true;
  bool fitToScreen = true;
  String? errorMessage;
  String? subtitleName;

  MediaItem get currentItem => _queue[_currentIndex < 0 ? 0 : _currentIndex];
  bool get hasPrevious => _currentIndex > 0;
  bool get hasNext => _currentIndex < _queue.length - 1;
  bool get isInitialized => controller?.value.isInitialized ?? false;

  Future<void> init() async {
    fitToScreen = _settings.aspectFitMode;
    if (_currentIndex < 0) {
      _currentIndex = 0;
    }
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    await controller?.dispose();
    controller = null;

    try {
      final file = await _mediaRepository.fileFor(currentItem.id);
      if (file == null) {
        throw StateError('The selected media file is not available.');
      }

      final newController = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: !_settings.backgroundAudio,
          allowBackgroundPlayback: _settings.backgroundAudio,
        ),
      );
      controller = newController;
      await newController.initialize();
      await newController.setPlaybackSpeed(_settings.defaultPlaybackSpeed);

      if (_settings.resumePlayback) {
        final lastPosition = _settingsRepository.lastPositionFor(
          currentItem.id,
        );
        if (lastPosition > Duration.zero &&
            lastPosition <
                newController.value.duration - const Duration(seconds: 5)) {
          await newController.seekTo(lastPosition);
        }
      }
      await newController.play();
      _startPositionTimer();
    } catch (error) {
      errorMessage = '$error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayback() async {
    final video = controller;
    if (video == null) {
      return;
    }
    if (video.value.isPlaying) {
      await video.pause();
    } else {
      await video.play();
    }
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await controller?.seekTo(position);
    notifyListeners();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await controller?.setPlaybackSpeed(speed);
    notifyListeners();
  }

  void toggleLock() {
    controlsLocked = !controlsLocked;
    controlsVisible = true;
    notifyListeners();
  }

  void toggleControls() {
    if (controlsLocked) {
      return;
    }
    controlsVisible = !controlsVisible;
    notifyListeners();
  }

  void toggleFit() {
    fitToScreen = !fitToScreen;
    notifyListeners();
  }

  Future<void> previous() async {
    if (!hasPrevious) {
      await seekTo(Duration.zero);
      return;
    }
    await _savePosition();
    _currentIndex -= 1;
    await _loadCurrent();
  }

  Future<void> next() async {
    if (!hasNext) {
      return;
    }
    await _savePosition();
    _currentIndex += 1;
    await _loadCurrent();
  }

  Future<void> pickSubtitle() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt'],
    );
    final selectedFile = result;
    final path = selectedFile?.path;
    final video = controller;
    if (selectedFile == null || path == null || video == null) {
      return;
    }

    final subtitleFile = File(path);
    final contents = await subtitleFile.readAsString();
    final caption = path.toLowerCase().endsWith('.vtt')
        ? WebVTTCaptionFile(contents)
        : SubRipCaptionFile(contents);
    await video.setClosedCaptionFile(Future.value(caption));
    subtitleName = selectedFile.name;
    notifyListeners();
  }

  Future<void> _savePosition() async {
    final video = controller;
    if (video == null || !video.value.isInitialized) {
      return;
    }
    await _settingsRepository.saveLastPosition(
      currentItem.id,
      video.value.position,
    );
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _savePosition();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _savePosition();
    controller?.dispose();
    super.dispose();
  }
}
