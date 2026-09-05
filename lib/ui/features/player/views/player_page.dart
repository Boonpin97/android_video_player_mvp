import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../data/repositories/media_repository.dart';
import '../../../../domain/models/media_item.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../view_models/player_view_model.dart';

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
  late final PlayerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PlayerViewModel(
      mediaRepository: widget.mediaRepository,
      settingsRepository: widget.settingsViewModel.repository,
      settings: widget.settingsViewModel.settings,
      queue: widget.queue,
      initialItem: widget.initialItem,
    );
    _viewModel.init();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: GestureDetector(
              onTap: _viewModel.toggleControls,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: _VideoSurface(viewModel: _viewModel)),
                  if (_viewModel.controlsVisible || _viewModel.controlsLocked)
                    _PlayerChrome(viewModel: _viewModel),
                  if (_viewModel.isLoading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.viewModel});

  final PlayerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final controller = viewModel.controller;
    if (viewModel.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          viewModel.errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final video = AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );

    return viewModel.fitToScreen
        ? FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: video,
            ),
          )
        : SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: video,
              ),
            ),
          );
  }
}

class _PlayerChrome extends StatelessWidget {
  const _PlayerChrome({required this.viewModel});

  final PlayerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        children: [
          _TopBar(viewModel: viewModel),
          const Spacer(),
          if (!viewModel.controlsLocked) _CenterControls(viewModel: viewModel),
          const Spacer(),
          _BottomBar(viewModel: viewModel),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.viewModel});

  final PlayerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: Text(
            viewModel.currentItem.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Subtitles',
          color: Colors.white,
          onPressed: viewModel.pickSubtitle,
          icon: const Icon(Icons.subtitles_outlined),
        ),
        PopupMenuButton<String>(
          color: Colors.grey.shade900,
          iconColor: Colors.white,
          onSelected: (value) {
            switch (value) {
              case 'fit':
                viewModel.toggleFit();
              case 'speed':
                _showSpeedSheet(context, viewModel);
              case 'info':
                _showInfo(context, viewModel);
              case 'tracks':
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Native audio track selection is planned after the MVP bridge.',
                    ),
                  ),
                );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'fit', child: Text('Toggle screen fit')),
            PopupMenuItem(value: 'speed', child: Text('Playback speed')),
            PopupMenuItem(value: 'tracks', child: Text('Audio track')),
            PopupMenuItem(value: 'info', child: Text('Information')),
          ],
        ),
      ],
    );
  }
}

class _CenterControls extends StatelessWidget {
  const _CenterControls({required this.viewModel});

  final PlayerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final controller = viewModel.controller;
    final playing = controller?.value.isPlaying ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          iconSize: 34,
          onPressed: viewModel.previous,
          icon: const Icon(Icons.skip_previous),
        ),
        const SizedBox(width: 24),
        IconButton.filled(
          iconSize: 56,
          onPressed: viewModel.togglePlayback,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        ),
        const SizedBox(width: 24),
        IconButton.filledTonal(
          iconSize: 34,
          onPressed: viewModel.next,
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.viewModel});

  final PlayerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final controller = viewModel.controller;
    final value = controller?.value;
    final position = value?.position ?? Duration.zero;
    final duration = value?.duration ?? Duration.zero;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: viewModel.controlsLocked
                    ? 'Unlock controls'
                    : 'Lock controls',
                color: Colors.white,
                onPressed: viewModel.toggleLock,
                icon: Icon(
                  viewModel.controlsLocked ? Icons.lock : Icons.lock_open,
                ),
              ),
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: duration.inMilliseconds <= 0
                      ? 1
                      : duration.inMilliseconds.toDouble(),
                  value: position.inMilliseconds
                      .clamp(
                        0,
                        duration.inMilliseconds <= 0
                            ? 1
                            : duration.inMilliseconds,
                      )
                      .toDouble(),
                  onChanged: viewModel.controlsLocked
                      ? null
                      : (value) => viewModel.seekTo(
                          Duration(milliseconds: value.round()),
                        ),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                tooltip: viewModel.fitToScreen
                    ? 'Crop to fill'
                    : 'Fit to screen',
                color: Colors.white,
                onPressed: viewModel.controlsLocked
                    ? null
                    : viewModel.toggleFit,
                icon: Icon(
                  viewModel.fitToScreen ? Icons.fit_screen : Icons.fullscreen,
                ),
              ),
            ],
          ),
          if (viewModel.subtitleName != null)
            Text(
              'Subtitles: ${viewModel.subtitleName}',
              style: const TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

void _showSpeedSheet(BuildContext context, PlayerViewModel viewModel) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
              .map(
                (speed) => ListTile(
                  title: Text('${speed.toStringAsFixed(2)}x'),
                  onTap: () {
                    viewModel.setPlaybackSpeed(speed);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      );
    },
  );
}

void _showInfo(BuildContext context, PlayerViewModel viewModel) {
  final item = viewModel.currentItem;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(item.title),
      content: Text(
        'Folder: ${item.folderName}\n'
        'Duration: ${_formatDuration(item.duration)}\n'
        'Resolution: ${item.resolution}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
