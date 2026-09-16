import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../../data/services/device_controls.dart';
import '../../../../domain/models/decoder_mode.dart';
import '../view_models/playback_gesture.dart';
import 'player_seek_bar.dart';

import '../../../../data/repositories/media_repository.dart';
import '../../../../domain/models/media_item.dart';
import '../../../core/ui_helpers.dart';
import '../../../core/player_adjustments.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/settings_page.dart';
import '../view_models/player_view_model.dart';

const _playerBlue = Color(0xff55b8fa);
const _shortcuts = <(String, IconData)>[
  ('Screen Rotation', Icons.screen_rotation_outlined),
  ('Playback Speed', Icons.speed),
  ('Audio sync', Icons.av_timer),
  ('Seek sensitivity', Icons.swipe),
  ('Background Play', Icons.headphones_outlined),
  ('Loop', Icons.repeat),
  ('Mute', Icons.volume_off_outlined),
  ('Shuffle', Icons.shuffle),
  ('Equalizer', Icons.equalizer),
  ('Audio Effect', Icons.surround_sound_outlined),
  ('Sleep Timer', Icons.bedtime_outlined),
  ('A - B Repeat', Icons.repeat_one),
  ('Night Mode', Icons.nightlight_outlined),
  ('Customise Items', Icons.tune),
  ('Screenshot', Icons.photo_camera_outlined),
  ('Mirror Mode', Icons.flip),
  ('Vertical Flip', Icons.flip_camera_android_outlined),
];

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.initialItem,
    required this.queue,
    required this.settingsViewModel,
    required this.mediaRepository,
  });
  final MediaItem initialItem;
  final List<MediaItem> queue;
  final SettingsViewModel settingsViewModel;
  final MediaRepository mediaRepository;
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerViewModel vm;
  int _panel = 0;
  bool _displayVideo = true;
  bool _mirror = false;
  bool _flip = false;
  bool _night = false;
  double _brightness = 0.5;
  double _volume = 0.5;
  final _device = DeviceControls();
  PlaybackGestureSession? _gesture;
  String? _gestureLabel;
  IconData _gestureIcon = Icons.fast_forward;
  double? _gestureLevel;
  Timer? _gestureTimer;
  Timer? _controlsTimer;
  final Set<int> _activePointers = {};
  String _aspect = 'Fit to screen';
  Timer? _sleepTimer;
  DateTime? _lastBack;
  String? _lastSubtitleWarning;
  bool _leaving = false;
  bool _allowPop = false;
  SettingsViewModel get settings => widget.settingsViewModel;

  @override
  void initState() {
    super.initState();
    _readDeviceLevels();
    vm = PlayerViewModel(
      mediaRepository: widget.mediaRepository,
      settingsRepository: settings.repository,
      settings: settings.settings,
      queue: widget.queue,
      initialItem: widget.initialItem,
    );
    _aspect = settings.settings.aspectFitMode
        ? 'Fit to screen'
        : 'Crop to fill';
    vm.addListener(_onPlayback);
    if (settings.option('landscape')) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    vm.init();
    _resetControlsTimeout();
  }

  void _onPlayback() {
    final warning = vm.subtitleWarning;
    if (warning != _lastSubtitleWarning) {
      _lastSubtitleWarning = warning;
      if (warning != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _notice(warning);
        });
      }
    }
    final value = vm.controller?.value;
    if (!_leaving &&
        settings.option('backToList', false) &&
        !vm.loop &&
        value != null &&
        value.isCompleted &&
        !vm.isLoading) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _exitPlayer();
      });
    }
  }

  void _exitPlayer() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _back() {
    if (_panel != 0) {
      _closePanel();
      return;
    }
    if (vm.controlsLocked) {
      _notice('Unlock the controls to leave playback.');
      return;
    }
    if (settings.option('doubleBack', false)) {
      final now = DateTime.now();
      if (_lastBack == null ||
          now.difference(_lastBack!) > const Duration(seconds: 2)) {
        _lastBack = now;
        _notice('Press back again to close playback.');
        return;
      }
    }
    _exitPlayer();
  }

  @override
  void dispose() {
    _gestureTimer?.cancel();
    _controlsTimer?.cancel();
    _device.resetBrightness().catchError((Object _) {});
    _sleepTimer?.cancel();
    vm.removeListener(_onPlayback);
    vm.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void _resetControlsTimeout() {
    _controlsTimer?.cancel();
    if (!vm.controlsVisible ||
        vm.controlsLocked ||
        _panel != 0 ||
        _activePointers.isNotEmpty) {
      return;
    }
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _panel == 0) vm.hideControls();
    });
  }

  void _closePanel() {
    setState(() => _panel = 0);
    _resetControlsTimeout();
  }

  Future<void> _audioSync() async {
    if (!vm.isInitialized) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AudioSyncDialog(
        initialValue: vm.audioDelay,
        onChanged: vm.setAudioDelay,
      ),
    );
  }

  Future<void> _seekSensitivity() async {
    await chooseSeekSensitivity(
      context,
      settings.repository.seekSensitivity,
      settings.setSeekSensitivity,
    );
  }

  Future<void> _speed() async {
    final speed = await chooseValue<double>(context, 'Playback Speed', {
      for (final value in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]) value: '${value}x',
    }, vm.controller?.value.playbackSpeed ?? 1);
    if (speed != null && mounted) await vm.setPlaybackSpeed(speed);
  }

  Future<void> _readDeviceLevels() async {
    try {
      final brightness = await _device.brightness();
      final volume = await _device.volume();
      if (mounted) {
        setState(() {
          _brightness = brightness.clamp(0.02, 1.0);
          // Android exposes only system volume (0–100%). Retain an active
          // in-app boost while the player is using the 101–200% range.
          if (_volume <= 1) _volume = volume;
        });
      }
    } on MissingPluginException {
      /* Device controls are absent in widget tests. */
    } on PlatformException {
      /* Keep default levels if Android cannot read them. */
    }
  }

  void _panStart(DragStartDetails details) {
    if (vm.controlsLocked || _panel != 0 || !vm.isInitialized || vm.isLoading) {
      return;
    }
    _gestureTimer?.cancel();
    _gesture = PlaybackGestureSession(
      origin: details.localPosition,
      viewport: MediaQuery.sizeOf(context),
      position: vm.controller!.value.position,
      duration: vm.controller!.value.duration,
      brightness: _brightness,
      volume: _volume,
      seekSensitivity: settings.repository.seekSensitivity,
    );
  }

  void _panUpdate(DragUpdateDetails details) {
    final gesture = _gesture;
    if (gesture == null || vm.controlsLocked) return;
    gesture.update(details.delta);
    switch (gesture.kind) {
      case PlaybackGestureKind.seek:
        final offset = gesture.targetPosition - gesture.position;
        setState(() {
          _gestureIcon = offset.isNegative
              ? Icons.fast_rewind
              : Icons.fast_forward;
          _gestureLabel =
              '${formatDuration(gesture.targetPosition)}  (${offset.isNegative ? '-' : '+'}${offset.inSeconds.abs()}s)';
          _gestureLevel = null;
        });
      case PlaybackGestureKind.brightness:
        final target = gesture.targetBrightness;
        setState(() {
          _brightness = target;
          _gestureIcon = Icons.brightness_6;
          _gestureLabel = 'Brightness ${(target * 100).round()}%';
          _gestureLevel = target;
        });
        _device.setBrightness(target).catchError((Object _) {
          if (mounted) _notice('Could not change screen brightness.');
        });
      case PlaybackGestureKind.volume:
        final target = gesture.targetVolume;
        setState(() {
          _volume = target;
          _gestureIcon = target == 0 ? Icons.volume_off : Icons.volume_up;
          _gestureLabel = 'Volume ${(target * 100).round()}%';
          _gestureLevel = target / 2;
        });
        vm.setVolume(target);
        _device.setVolume(target.clamp(0.0, 1.0)).catchError((Object _) {
          if (mounted) _notice('Could not change media volume.');
        });
      case null:
        break;
    }
  }

  void _panEnd({bool cancelled = false}) {
    final gesture = _gesture;
    _gesture = null;
    if (!cancelled &&
        !vm.controlsLocked &&
        gesture?.kind == PlaybackGestureKind.seek) {
      vm.seekTo(gesture!.targetPosition);
    }
    _gestureTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _gestureLabel = null);
    });
  }

  Future<void> _decoder() async {
    final selected = await chooseValue<DecoderMode>(context, 'Video decoder', {
      for (final mode in DecoderMode.values)
        mode: '${mode.label} — ${mode.description}',
    }, vm.decoderMode);
    if (selected != null && mounted) await vm.setDecoderMode(selected);
  }

  Future<void> _chooseAspect() async {
    final aspect = await chooseValue<String>(context, 'Aspect Ratio', {
      for (final value in [
        'Fit to screen',
        'Crop to fill',
        'Stretch',
        '16:9',
        '4:3',
      ])
        value: value,
    }, _aspect);
    if (aspect != null && mounted) setState(() => _aspect = aspect);
  }

  Future<void> _bookmark() async {
    final saved = settings.repository.bookmarkFor(vm.currentItem.id);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Bookmark'),
        children: [
          if (saved != null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'jump'),
              child: Text('Go to ${formatDuration(saved)}'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Bookmark current position'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'jump' && saved != null) await vm.seekTo(saved);
    if (choice == 'save' && vm.isInitialized) {
      await settings.repository.saveBookmark(
        vm.currentItem.id,
        vm.controller!.value.position,
      );
      if (mounted) _notice('Bookmark saved');
    }
  }

  void _queue() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff252525),
      builder: (context) => SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Playing Queue',
                style: TextStyle(color: Colors.white, fontSize: 19),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: vm.queue.length,
                itemBuilder: (context, index) {
                  final item = vm.queue[index];
                  return ListTile(
                    leading: Icon(
                      item.id == vm.currentItem.id
                          ? Icons.equalizer
                          : Icons.play_arrow_outlined,
                      color: _playerBlue,
                    ),
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      formatDuration(item.duration),
                      style: const TextStyle(color: Colors.white60),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      vm.playIndex(index);
                      _closePanel();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _info() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Information'),
      content: Text(
        '${vm.currentItem.title}\n\nFolder: ${vm.currentItem.folderName}\nDuration: ${formatDuration(vm.currentItem.duration)}\nResolution: ${vm.currentItem.resolution}\nSelected decoder: ${vm.decoderMode.label}\nActive decoder: ${vm.controller?.activeDecoderLabel ?? "Pending"}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _shortcut(String name) async {
    switch (name) {
      case 'Screen Rotation':
        final landscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        await SystemChrome.setPreferredOrientations(
          landscape
              ? [DeviceOrientation.portraitUp]
              : [
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ],
        );
      case 'Audio sync':
        await _audioSync();
      case 'Seek sensitivity':
        await _seekSensitivity();
      case 'Playback Speed':
        await _speed();
      case 'Background Play':
        final enabled = !settings.settings.backgroundAudio;
        await settings.setBackgroundAudio(enabled);
        if (!mounted) return;
        await vm.setBackgroundAudio(enabled);
        if (mounted) {
          _notice(enabled ? 'Background audio on' : 'Background audio off');
        }
      case 'Loop':
        await vm.toggleLoop();
      case 'Mute':
        await vm.toggleMute();
      case 'Shuffle':
        vm.toggleShuffle();
      case 'Sleep Timer':
        final minutes = await chooseValue<int>(context, 'Sleep Timer', {
          0: 'Off',
          15: '15 minutes',
          30: '30 minutes',
          60: '60 minutes',
        }, 0);
        if (minutes != null && mounted) {
          _sleepTimer?.cancel();
          if (minutes > 0) {
            _sleepTimer = Timer(Duration(minutes: minutes), () {
              if (mounted) {
                vm.pause();
                _notice('Sleep timer finished');
              }
            });
          }
          _notice(
            minutes == 0
                ? 'Sleep timer off'
                : 'Playback will pause in $minutes minutes',
          );
        }
      case 'Night Mode':
        setState(() => _night = !_night);
      case 'Customise Items':
        setState(() => _panel = 2);
      case 'Mirror Mode':
        setState(() => _mirror = !_mirror);
      case 'Vertical Flip':
        setState(() => _flip = !_flip);
      default:
        await showFeatureUnavailable(context, name);
    }
    if (mounted) setState(() {});
  }

  bool _active(String name) => switch (name) {
    'Loop' => vm.loop,
    'Mute' => vm.muted,
    'Shuffle' => vm.shuffle,
    'Night Mode' => _night,
    'Mirror Mode' => _mirror,
    'Vertical Flip' => _flip,
    'Background Play' => settings.settings.backgroundAudio,
    'Sleep Timer' => _sleepTimer?.isActive ?? false,
    _ => false,
  };

  Widget _icon(
    String label,
    IconData icon,
    VoidCallback? action, {
    double size = 24,
    Size? touchTarget,
  }) => IconButton(
    tooltip: label,
    onPressed: action == null
        ? null
        : () {
            action();
            _resetControlsTimeout();
          },
    icon: Icon(icon, size: size),
    color: Colors.white,
    disabledColor: Colors.white30,
    padding: const EdgeInsets.all(8),
    style: IconButton.styleFrom(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    constraints: touchTarget == null
        ? const BoxConstraints(minWidth: 48, minHeight: 48)
        : BoxConstraints.tightFor(
            width: touchTarget.width,
            height: touchTarget.height,
          ),
  );

  Widget _video() {
    final controller = vm.controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_displayVideo) {
      return const SizedBox.expand();
    }
    final size = controller.value.size;
    final aspect = _aspect == '16:9'
        ? 16 / 9
        : _aspect == '4:3'
        ? 4 / 3
        : size.width / size.height;
    Widget surface = SizedBox.expand(
      child: FittedBox(
        fit: _aspect == 'Crop to fill'
            ? BoxFit.cover
            : _aspect == 'Stretch'
            ? BoxFit.fill
            : BoxFit.contain,
        child: SizedBox(
          width: size.height * aspect,
          height: size.height,
          child: IgnorePointer(
            child: Video(
              controller: controller.videoController,
              controls: NoVideoControls,
              fit: BoxFit.fill,
              pauseUponEnteringBackgroundMode:
                  !settings.settings.backgroundAudio,
              subtitleViewConfiguration: const SubtitleViewConfiguration(
                visible: false,
              ),
            ),
          ),
        ),
      ),
    );
    if (_mirror || _flip) {
      surface = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(_mirror ? -1 : 1, _flip ? -1 : 1, 1),
        child: surface,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        surface,
        if (_night) ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
        if (controller.value.caption.text.isNotEmpty)
          Positioned(
            bottom: vm.controlsVisible && _panel == 0 ? 110 : 24,
            left: 24,
            right: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                color: Colors.black54,
                child: Text(
                  controller.value.caption.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: settings.repository.subtitleSize,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _transport() {
    final value = vm.controller?.value;
    final narrow = MediaQuery.sizeOf(context).width < 440;
    final playbackButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon(
          'Previous video',
          Icons.skip_previous,
          vm.isLoading ? null : vm.previous,
          size: 34,
          touchTarget: const Size(72, 72),
        ),
        const SizedBox(width: 12),
        _icon(
          value?.isPlaying == true ? 'Pause' : 'Play',
          value?.isPlaying == true ? Icons.pause : Icons.play_arrow,
          vm.isInitialized && !vm.isLoading ? vm.togglePlayback : null,
          size: 44,
          touchTarget: const Size(80, 72),
        ),
        const SizedBox(width: 12),
        _icon(
          'Next video',
          Icons.skip_next,
          (vm.hasNext || vm.shuffle) && !vm.isLoading ? vm.next : null,
          size: 34,
          touchTarget: const Size(72, 72),
        ),
      ],
    );
    final lock = _icon(
      'Lock controls',
      Icons.lock_open_outlined,
      vm.toggleLock,
    );
    final displayButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon('Aspect ratio', Icons.aspect_ratio, () {
          if (settings.option('quickZoom')) {
            setState(
              () => _aspect = _aspect == 'Fit to screen'
                  ? 'Crop to fill'
                  : 'Fit to screen',
            );
          } else {
            _chooseAspect();
          }
        }),
        _icon(
          'Screen rotation',
          Icons.screen_rotation_outlined,
          () => _shortcut('Screen Rotation'),
        ),
      ],
    );
    // Consume touches in gaps so near misses cannot reach video gestures.
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black54],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              child: PlayerSeekBar(
                key: ObjectKey(vm.controller),
                position: value?.position ?? Duration.zero,
                duration: value?.duration ?? Duration.zero,
                enabled: vm.isInitialized && !vm.isLoading,
                onSeek: vm.seekTo,
              ),
            ),
            const SizedBox(height: 8),
            if (narrow) ...[
              Center(child: playbackButtons),
              Row(children: [lock, const Spacer(), displayButtons]),
            ] else
              Row(
                children: [
                  lock,
                  const Spacer(),
                  playbackButtons,
                  const Spacer(),
                  displayButtons,
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chrome() => Column(
    children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            _icon('Back', Icons.arrow_back, _back),
            Expanded(
              child: Text(
                vm.currentItem.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (MediaQuery.sizeOf(context).width > 500) ...[
              _icon(
                'Picture-in-Picture',
                Icons.picture_in_picture_alt_outlined,
                () => showFeatureUnavailable(context, 'Picture-in-Picture'),
              ),
              _icon(
                'Audio sync',
                Icons.av_timer,
                vm.isInitialized ? _audioSync : null,
              ),
            ],
            _icon(
              vm.hasLoadedSubtitle
                  ? 'Subtitles loaded: ${vm.subtitleName}'
                  : 'Choose subtitles',
              vm.hasLoadedSubtitle ? Icons.subtitles : Icons.subtitles_outlined,
              vm.isInitialized ? vm.pickSubtitle : null,
            ),
            TextButton(
              onPressed: vm.isLoading ? null : _decoder,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(38, 44),
              ),
              child: Text(
                vm.decoderMode.label,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            _icon(
              'More options',
              Icons.more_vert,
              () => setState(() => _panel = 1),
            ),
          ],
        ),
      ),
      if (settings.option('shortcuts'))
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 57,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _shortcutCircle(
                  'Display Settings',
                  Icons.tune,
                  () => setState(() => _panel = 3),
                ),
                for (final shortcut
                    in [
                          'Playback Speed',
                          'Screenshot',
                          'Background Play',
                          'Screen Rotation',
                        ]
                        .map(
                          (name) => _shortcuts.firstWhere((s) => s.$1 == name),
                        )
                        .where((s) => settings.option('shortcut.${s.$1}')))
                  _shortcutCircle(
                    shortcut.$1,
                    shortcut.$2,
                    () => _shortcut(shortcut.$1),
                    text: shortcut.$1 == 'Playback Speed'
                        ? '${(vm.controller?.value.playbackSpeed ?? 1).toString().replaceFirst(RegExp(r'\.0$'), '')}X'
                        : null,
                    active:
                        shortcut.$1 != 'Background Play' &&
                        _active(shortcut.$1),
                  ),
                _shortcutCircle(
                  'All shortcuts',
                  Icons.chevron_right,
                  () => setState(() => _panel = 4),
                ),
              ],
            ),
          ),
        ),
      const Spacer(),
      _transport(),
    ],
  );

  Widget _shortcutCircle(
    String title,
    IconData icon,
    VoidCallback action, {
    String? text,
    bool active = false,
  }) => Padding(
    padding: const EdgeInsets.only(right: 12, top: 3, bottom: 3),
    child: Tooltip(
      message: title,
      child: Material(
        color: active ? _playerBlue.withValues(alpha: 0.5) : Colors.black45,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: action,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: text != null
                  ? Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _menuItem(
    String name,
    IconData icon,
    VoidCallback action, {
    bool selected = false,
  }) => InkWell(
    onTap: action,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
            color: selected
                ? _playerBlue.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 28,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.15,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _actionsPanel() {
    final favourite = settings.option('favourite.${vm.currentItem.id}', false);
    return Column(
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent:
                ((MediaQuery.sizeOf(context).height -
                            MediaQuery.paddingOf(context).vertical -
                            24 -
                            116) /
                        3)
                    .clamp(80.0, 98.0),
          ),
          children: [
            _menuItem('Playing\nQueue', Icons.playlist_play, _queue),
            _menuItem('Aspect Ratio', Icons.aspect_ratio, _chooseAspect),
            _menuItem(
              'Display\nSettings',
              Icons.display_settings_outlined,
              () => setState(() => _panel = 3),
            ),
            _menuItem('Bookmark', Icons.bookmarks_outlined, _bookmark),
            _menuItem(
              'Cut',
              Icons.video_file_outlined,
              () => showFeatureUnavailable(context, 'Cut'),
            ),
            _menuItem(
              'Favourite',
              favourite ? Icons.favorite : Icons.favorite_border,
              () async {
                await settings.setOption(
                  'favourite.${vm.currentItem.id}',
                  !favourite,
                );
                if (mounted) {
                  setState(() {});
                  _notice(
                    favourite
                        ? 'Removed from favourites'
                        : 'Added to favourites',
                  );
                }
              },
              selected: favourite,
            ),
            _menuItem(
              'Add To\nPlaylist',
              Icons.playlist_add,
              () => showFeatureUnavailable(context, 'Add To Playlist'),
            ),
            _menuItem('Information', Icons.format_list_bulleted, _info),
            _menuItem(
              'Share',
              Icons.reply_outlined,
              () => showFeatureUnavailable(context, 'Share'),
            ),
            _menuItem('Tutorial', Icons.lightbulb_outline, _tutorial),
            _menuItem(
              'More',
              Icons.chevron_right,
              () => setState(() => _panel = 4),
            ),
          ],
        ),
        _switch(
          'Video Display',
          _displayVideo,
          (value) => setState(() => _displayVideo = value),
        ),
        _switch('Shortcuts', settings.option('shortcuts'), (value) async {
          await settings.setOption('shortcuts', value);
          if (mounted) setState(() {});
        }),
      ],
    );
  }

  Widget _switch(String title, bool value, ValueChanged<bool> action) =>
      SizedBox(
        height: 58,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            Switch(
              value: value,
              onChanged: action,
              activeThumbColor: _playerBlue,
              activeTrackColor: _playerBlue.withValues(alpha: 0.4),
            ),
          ],
        ),
      );

  void _tutorial() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Player controls'),
      content: const Text(
        'Drag left or right to rewind or fast forward.\n\nDrag up or down on the left half for brightness, or on the right half for volume.\n\nTap to show or hide controls. Double-tap either side to seek 10 seconds. Use the lock button to prevent accidental touches.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Widget _panelContent() {
    if (_panel == 1) return _actionsPanel();
    if (_panel == 2) {
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent:
              ((MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).vertical -
                          24) /
                      8)
                  .clamp(44.0, 64.0),
        ),
        children: [
          for (final (name, _) in _shortcuts)
            InkWell(
              onTap: () async {
                await settings.setOption(
                  'shortcut.$name',
                  !settings.option('shortcut.$name'),
                );
                if (mounted) setState(() {});
              },
              child: Row(
                children: [
                  Checkbox(
                    value: settings.option('shortcut.$name'),
                    activeColor: _playerBlue,
                    checkColor: Colors.white,
                    onChanged: (value) async {
                      await settings.setOption('shortcut.$name', value!);
                      if (mounted) setState(() {});
                    },
                  ),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    if (_panel == 4) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        childAspectRatio: 0.9,
        children: [
          for (final (name, icon) in _shortcuts.where(
            (s) => settings.option('shortcut.${s.$1}'),
          ))
            _menuItem(
              name,
              icon,
              () => _shortcut(name),
              selected: _active(name),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text(
            'Display Settings',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Brightness',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        Row(
          children: [
            const Icon(Icons.brightness_6_outlined, color: Colors.white),
            Expanded(
              child: Slider(
                value: _brightness,
                min: 0.02,
                max: 1,
                activeColor: _playerBlue,
                inactiveColor: Colors.white30,
                onChanged: (value) {
                  setState(() => _brightness = value);
                  _device.setBrightness(value).catchError((Object _) {});
                },
              ),
            ),
          ],
        ),
        _switch(
          'Night Mode',
          _night,
          (value) => setState(() => _night = value),
        ),
        _switch(
          'Mirror Mode',
          _mirror,
          (value) => setState(() => _mirror = value),
        ),
        _switch(
          'Vertical Flip',
          _flip,
          (value) => setState(() => _flip = value),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Aspect Ratio',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            _aspect,
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white),
          onTap: _chooseAspect,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _activePointers.add(event.pointer);
            _controlsTimer?.cancel();
          },
          onPointerUp: (event) {
            _activePointers.remove(event.pointer);
            _resetControlsTimeout();
          },
          onPointerCancel: (event) {
            _activePointers.remove(event.pointer);
            _resetControlsTimeout();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (_) => _readDeviceLevels(),
                onPanStart: _panStart,
                onPanUpdate: _panUpdate,
                onPanEnd: (_) => _panEnd(),
                onPanCancel: () => _panEnd(cancelled: true),
                onTap: () {
                  if (_panel != 0) {
                    _closePanel();
                  } else {
                    vm.toggleControls();
                    _resetControlsTimeout();
                  }
                },
                onDoubleTapDown: (details) {
                  if (!vm.controlsLocked &&
                      _panel == 0 &&
                      settings.option('doubleTapSeek')) {
                    final forward =
                        details.localPosition.dx >=
                        MediaQuery.sizeOf(context).width / 2;
                    vm.seekBy(forward ? 10 : -10);
                  }
                },
                onDoubleTap: () {},
                child: _video(),
              ),
              if (_gestureLabel != null)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _gestureIcon,
                            color: Colors.white,
                            size: 32,
                            shadows: const [
                              Shadow(blurRadius: 3, color: Colors.black87),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _gestureLabel!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              shadows: [
                                Shadow(blurRadius: 3, color: Colors.black87),
                              ],
                            ),
                          ),
                          if (_gestureLevel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: LinearProgressIndicator(
                                value: _gestureLevel,
                                color: _playerBlue,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (vm.isLoading && settings.option('loadingCircle'))
                const IgnorePointer(
                  child: Center(
                    child: CircularProgressIndicator(color: _playerBlue),
                  ),
                ),
              if (vm.errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(50),
                    child: Text(
                      vm.errorMessage!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (vm.controlsLocked)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _shortcutCircle(
                        'Unlock controls',
                        Icons.lock,
                        vm.toggleLock,
                      ),
                    ),
                  ),
                )
              else if (_panel == 0)
                SafeArea(
                  child: IgnorePointer(
                    ignoring: !vm.controlsVisible,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: vm.controlsVisible ? 1 : 0,
                      child: _chrome(),
                    ),
                  ),
                ),
              if (_panel != 0) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closePanel,
                    child: const ColoredBox(color: Colors.black45),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width:
                          MediaQuery.orientationOf(context) ==
                              Orientation.landscape
                          ? math.min(
                              380,
                              MediaQuery.sizeOf(context).width * 0.40,
                            )
                          : MediaQuery.sizeOf(context).width,
                      height: double.infinity,
                      color: Colors.black.withValues(alpha: 0.13),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: _panelContent(),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
