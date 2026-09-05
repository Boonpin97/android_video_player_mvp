import 'package:flutter/material.dart';

import '../view_models/settings_view_model.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.viewModel});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final settings = viewModel.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              const _SectionHeader('Player'),
              SwitchListTile(
                title: const Text('Resume playback'),
                subtitle: const Text(
                  'Continue videos from the last saved position.',
                ),
                value: settings.resumePlayback,
                onChanged: viewModel.setResumePlayback,
              ),
              SwitchListTile(
                title: const Text('Background audio'),
                subtitle: const Text(
                  'Keep audio active when Android allows background playback.',
                ),
                value: settings.backgroundAudio,
                onChanged: viewModel.setBackgroundAudio,
              ),
              SwitchListTile(
                title: const Text('Fit video to screen'),
                subtitle: const Text(
                  'Use contain mode instead of cropping the video.',
                ),
                value: settings.aspectFitMode,
                onChanged: viewModel.setAspectFitMode,
              ),
              ListTile(
                title: const Text('Default playback speed'),
                subtitle: Slider(
                  min: 0.5,
                  max: 2,
                  divisions: 6,
                  value: settings.defaultPlaybackSpeed,
                  label: '${settings.defaultPlaybackSpeed.toStringAsFixed(2)}x',
                  onChanged: viewModel.setDefaultPlaybackSpeed,
                ),
                trailing: Text(
                  '${settings.defaultPlaybackSpeed.toStringAsFixed(2)}x',
                ),
              ),
              const _SectionHeader('Maintenance'),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Clear history'),
                subtitle: const Text('Remove saved playback positions.'),
                onTap: () async {
                  await viewModel.clearHistory();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History cleared')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Clear thumbnail cache'),
                subtitle: const Text(
                  'Thumbnails are provided by the media library plugin cache.',
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Thumbnail cache clear is platform-managed in MVP',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Reset settings'),
                onTap: viewModel.resetSettings,
              ),
              const _SectionHeader('MVP Limits'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Audio/subtitle track picker'),
                subtitle: Text(
                  'The MVP uses Flutter video_player; native track enumeration is planned for a later Media3 bridge.',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.picture_in_picture_alt_outlined),
                title: Text('Picture-in-picture'),
                subtitle: Text(
                  'The UI is prepared; Android native PiP wiring is deferred to a platform channel.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
