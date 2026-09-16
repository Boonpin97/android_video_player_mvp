import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'data/repositories/media_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/media_library_service.dart';
import 'data/services/preference_service.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/library/view_models/library_view_model.dart';
import 'ui/features/library/views/home_shell.dart';
import 'ui/features/settings/view_models/settings_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final preferenceService = PreferenceService();
  await preferenceService.init();

  final mediaRepository = MediaRepository(MediaLibraryService());
  final settingsRepository = SettingsRepository(preferenceService);

  runApp(
    VideoPlayerApp(
      libraryViewModel: LibraryViewModel(mediaRepository),
      settingsViewModel: SettingsViewModel(settingsRepository),
      mediaRepository: mediaRepository,
    ),
  );
}

class VideoPlayerApp extends StatelessWidget {
  const VideoPlayerApp({
    super.key,
    required this.libraryViewModel,
    required this.settingsViewModel,
    required this.mediaRepository,
  });

  final LibraryViewModel libraryViewModel;
  final SettingsViewModel settingsViewModel;
  final MediaRepository mediaRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Player MVP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      darkTheme: AppTheme.dark(),
      home: HomeShell(
        libraryViewModel: libraryViewModel,
        settingsViewModel: settingsViewModel,
        mediaRepository: mediaRepository,
      ),
    );
  }
}
