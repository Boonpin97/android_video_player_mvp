import 'package:flutter/material.dart';
import '../../../core/player_adjustments.dart';

import '../../../../data/repositories/media_repository.dart';
import '../../../../domain/models/decoder_mode.dart';
import '../../../core/app_theme.dart';
import '../../../core/ui_helpers.dart';
import '../view_models/settings_view_model.dart';
import 'settings_catalog.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.viewModel,
    this.mediaRepository,
  });
  final SettingsViewModel viewModel;
  final MediaRepository? mediaRepository;

  @override
  Widget build(BuildContext context) {
    const categories = <(String, IconData)>[
      ('List', Icons.format_list_bulleted),
      ('Player', Icons.hexagon_outlined),
      ('Decoder', Icons.memory),
      ('Audio', Icons.music_video_outlined),
      ('Subtitle', Icons.subtitles_outlined),
      ('General', Icons.report_gmailerrorred),
      ('Development', Icons.developer_mode),
      ('App Language', Icons.translate),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          for (final (title, icon) in categories)
            ListTile(
              minTileHeight: 48,
              minLeadingWidth: 20,
              horizontalTitleGap: 12,
              leading: Icon(icon, size: 22),
              title: Text(title),
              onTap: () {
                if (title == 'App Language') {
                  showLanguageDialog(context);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsCategoryPage(
                        title: title,
                        viewModel: viewModel,
                        mediaRepository: mediaRepository,
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

class SettingsCategoryPage extends StatelessWidget {
  const SettingsCategoryPage({
    super.key,
    required this.title,
    required this.viewModel,
    this.mediaRepository,
  });
  final String title;
  final SettingsViewModel viewModel;
  final MediaRepository? mediaRepository;

  bool _checked(SettingEntry entry) => switch (entry.action) {
    'backgroundCheck' => viewModel.settings.backgroundAudio,
    'fit' => viewModel.settings.aspectFitMode,
    null => entry.checked ?? false,
    final key => viewModel.option(key, entry.checked ?? false),
  };

  Future<void> _activate(BuildContext context, SettingEntry entry) async {
    final action = entry.action;
    if (action == null) {
      await showFeatureUnavailable(context, entry.title);
      return;
    }
    if (entry.checked != null) {
      final value = !_checked(entry);
      if (action == 'backgroundCheck') {
        await viewModel.setBackgroundAudio(value);
      } else if (action == 'fit') {
        await viewModel.setAspectFitMode(value);
      } else {
        await viewModel.setOption(action, value);
      }
      return;
    }
    if (settingsCatalog.containsKey(action)) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SettingsCategoryPage(
            title: action,
            viewModel: viewModel,
            mediaRepository: mediaRepository,
          ),
        ),
      );
      return;
    }
    switch (action) {
      case 'decoder':
        final mode =
            await chooseValue<DecoderMode>(context, 'Default decoder', {
              for (final mode in DecoderMode.values)
                mode: '${mode.label} — ${mode.description}',
            }, viewModel.repository.decoderMode);
        if (mode != null) await viewModel.setDecoderMode(mode);
      case 'decoderInfo':
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Automatic fallback'),
              content: const Text(
                'HW and HW+ use your phone’s hardware decoder when the format is supported. Other formats use software decoding. Select SW to always decode in software.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      case 'resume':
        final choice = await chooseValue<bool>(context, 'Resume', {
          true: 'Resume from last position',
          false: 'Start from the beginning',
        }, viewModel.settings.resumePlayback);
        if (choice != null) await viewModel.setResumePlayback(choice);
      case 'speed':
        final choice = await chooseValue<double>(
          context,
          'Default playback speed',
          {
            for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              speed: '${speed}x',
          },
          viewModel.settings.defaultPlaybackSpeed,
        );
        if (choice != null) await viewModel.setDefaultPlaybackSpeed(choice);
      case 'background':
        final choice = await chooseValue<bool>(context, 'Background play', {
          true: 'Keep playing audio',
          false: 'Pause in background',
        }, viewModel.settings.backgroundAudio);
        if (choice != null) await viewModel.setBackgroundAudio(choice);
      case 'seekSensitivity':
        await chooseSeekSensitivity(
          context,
          viewModel.repository.seekSensitivity,
          viewModel.setSeekSensitivity,
        );
      case 'subtitleSize':
        final choice = await chooseValue<double>(
          context,
          'Subtitle text size',
          {16: 'Small', 20: 'Medium', 26: 'Large', 32: 'Extra large'},
          viewModel.repository.subtitleSize,
        );
        if (choice != null) await viewModel.setSubtitleSize(choice);
      case 'language':
        if (context.mounted) await showLanguageDialog(context);
      case 'history':
      case 'cache':
      case 'reset':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${entry.title}?'),
            content: Text(
              action == 'history'
                  ? 'Saved playback positions will be removed.'
                  : action == 'reset'
                  ? 'Your preferences will return to their defaults.'
                  : 'Video thumbnails will be loaded again when you open a folder.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        if (action == 'history') await viewModel.clearHistory();
        if (action == 'reset') await viewModel.resetSettings();
        if (action == 'cache') await mediaRepository?.clearThumbnailCache();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                action == 'history'
                    ? 'Playback history cleared'
                    : action == 'reset'
                    ? 'Settings reset'
                    : 'Thumbnail cache cleared',
              ),
            ),
          );
        }
      case 'licenses':
        if (context.mounted) {
          showLicensePage(
            context: context,
            applicationName: 'Player',
            applicationVersion: '1.0.0',
          );
        }
      case 'version':
        if (context.mounted) {
          showAboutDialog(
            context: context,
            applicationName: 'Player',
            applicationVersion: '1.0.0',
          );
        }
      case 'subtitleFolder':
        try {
          await viewModel.chooseSubtitleFolder();
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not open the subtitle folder. Please try again.',
                ),
              ),
            );
          }
        }
      case 'clearSubtitleFolder':
        await viewModel.clearSubtitleFolder();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final entries = settingsCatalog[title] ?? const <SettingEntry>[];
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView.builder(
          padding: EdgeInsets.only(
            bottom: 20 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            if (entry.section) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      index == 0 ? 16 : 12,
                      17,
                      16,
                      10,
                    ),
                    child: Text(
                      entry.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: index == 0
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }
            return Semantics(
              hint: entry.action == null
                  ? 'Feature not available in this version'
                  : null,
              child: InkWell(
                onTap: () => _activate(context, entry),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 17),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.ink,
                                height: 1.25,
                              ),
                            ),
                            if (entry.subtitle != null)
                              Text(
                                entry.action == 'subtitleFolder' &&
                                        viewModel.repository.subtitleFolder !=
                                            null
                                    ? '${viewModel.repository.subtitleFolder!.name}\nAutomatically load matching .srt files.'
                                    : entry.subtitle!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xff707070),
                                  height: 1.2,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (entry.checked != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Checkbox(
                              value: _checked(entry),
                              onChanged: (_) => _activate(context, entry),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

Future<T?> chooseValue<T>(
  BuildContext context,
  String title,
  Map<T, String> choices,
  T selected,
) => showDialog<T>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title),
    children: [
      for (final entry in choices.entries)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, entry.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Icon(
                  entry.key == selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: entry.key == selected ? AppTheme.blue : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(entry.value)),
              ],
            ),
          ),
        ),
    ],
  ),
);

Future<void> showLanguageDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('App Language'),
    content: const Text(
      'English · System default\n\nAdditional translations are not available yet.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('OK'),
      ),
    ],
  ),
);
