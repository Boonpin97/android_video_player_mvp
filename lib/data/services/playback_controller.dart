import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../domain/models/decoder_mode.dart';

class PlaybackCaption {
  const PlaybackCaption(this.text);
  final String text;
}

class PlaybackValue {
  const PlaybackValue({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.size = Size.zero,
    this.playbackSpeed = 1,
    this.volume = 1,
    this.errorDescription,
    this.caption = const PlaybackCaption(''),
  });
  final bool isInitialized, isPlaying, isCompleted;
  final Duration position, duration;
  final Size size;
  final double playbackSpeed, volume;
  final String? errorDescription;
  final PlaybackCaption caption;
  bool get hasError => errorDescription != null;
}

/// Keeps player widgets independent of mpv's asynchronous event streams.
class PlaybackController extends ValueNotifier<PlaybackValue> {
  PlaybackController.file(this.file, {required this.decoderMode})
    : super(const PlaybackValue()) {
    player = Player(configuration: const PlayerConfiguration(title: 'Player'));
    videoController = VideoController(
      player,
      configuration: VideoControllerConfiguration(hwdec: decoderMode.hwdec),
    );
    _ready.future.ignore();
    for (final stream in <Stream<dynamic>>[
      player.stream.playing,
      player.stream.position,
      player.stream.duration,
      player.stream.width,
      player.stream.height,
      player.stream.rate,
      player.stream.volume,
      player.stream.completed,
      player.stream.subtitle,
    ]) {
      _subscriptions.add(stream.listen((_) => _sync()));
    }
    _subscriptions.add(
      player.stream.error.listen((message) {
        if (_disposed) return;
        _error = message;
        if (!_ready.isCompleted) _ready.completeError(StateError(message));
        _sync();
      }),
    );
  }
  final File file;
  late final Player player;
  late final VideoController videoController;
  DecoderMode decoderMode;
  String activeDecoder = '';
  String get activeDecoderLabel =>
      activeDecoder.isEmpty || activeDecoder == 'no'
      ? 'SW (software)'
      : activeDecoder == 'mediacodec-copy'
      ? 'HW'
      : activeDecoder == 'mediacodec'
      ? 'HW+'
      : activeDecoder;
  String? _error;
  bool _disposed = false;
  final _ready = Completer<void>();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  void _sync() {
    if (_disposed) return;
    final state = player.state;
    final width = state.width ?? 0;
    final height = state.height ?? 0;
    final initialized = width > 0 && height > 0;
    value = PlaybackValue(
      isInitialized: initialized,
      isPlaying: state.playing,
      isCompleted: state.completed,
      position: state.position,
      duration: state.duration,
      size: Size(width.toDouble(), height.toDouble()),
      playbackSpeed: state.rate,
      volume: state.volume / 100,
      errorDescription: _error,
      caption: PlaybackCaption(
        state.subtitle.where((s) => s.isNotEmpty).join('\n'),
      ),
    );
    if (initialized && !_ready.isCompleted) _ready.complete();
  }

  Future<void> initialize() async {
    await videoController.platform.future;
    if (_disposed) return;
    final native = player.platform;
    if (native is NativePlayer) {
      await native.setProperty('hwdec-codecs', 'all');
      await native.observeProperty('hwdec-current', (value) async {
        if (_disposed) return;
        activeDecoder = value;
        debugPrint(
          'Player decoder: requested=${decoderMode.label}, active=${value.isEmpty ? "SW" : value}',
        );
        _sync();
      });
    }
    if (_disposed) return;
    await player.open(Media(file.path), play: false);
    await _ready.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw StateError('Timed out while opening this video.'),
    );
    if (!_disposed) {
      debugPrint(
        'Player opened: ${value.size.width.toInt()}x${value.size.height.toInt()}, duration=${value.duration.inSeconds}s',
      );
    }
  }

  Future<void> setDecoderMode(DecoderMode mode) async {
    if (_disposed) return;
    final native = player.platform;
    if (native is! NativePlayer) {
      throw UnsupportedError(
        'Decoder selection is not available on this platform.',
      );
    }
    _error = null;
    await native.setProperty('hwdec', mode.hwdec);
    if (_disposed) return;
    decoderMode = mode;
    _sync();
  }

  Future<void> setAudioDelay(double seconds) async {
    final native = player.platform;
    if (native is! NativePlayer) {
      throw UnsupportedError('Audio sync is unavailable.');
    }
    await native.setProperty(
      'audio-delay',
      seconds.clamp(-3, 3).toStringAsFixed(2),
    );
  }

  Future<void> play() => player.play();
  Future<void> pause() => player.pause();
  Future<void> seekTo(Duration value) => player.seek(value);
  Future<void> setPlaybackSpeed(double speed) => player.setRate(speed);
  Future<void> setVolume(double volume) =>
      player.setVolume(volume.clamp(0.0, 2.0) * 100);
  Future<void> setLooping(bool looping) =>
      player.setPlaylistMode(looping ? PlaylistMode.single : PlaylistMode.none);
  Future<void> setSubtitleFile(String path, String title) async {
    await player.setSubtitleTrack(SubtitleTrack.uri(path, title: title));
    final native = player.platform;
    if (native is NativePlayer) {
      final selected = await native.getProperty('sid');
      if (selected == 'no' || selected == 'auto' || selected.isEmpty) {
        throw StateError('No subtitle track was loaded.');
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (!_ready.isCompleted) _ready.complete();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
    super.dispose();
  }
}
