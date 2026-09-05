import 'package:flutter/material.dart';

import '../../../../data/repositories/media_repository.dart';
import '../../settings/view_models/settings_view_model.dart';
import '../../settings/views/settings_page.dart';
import '../view_models/library_view_model.dart';
import 'library_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.libraryViewModel,
    required this.settingsViewModel,
    required this.mediaRepository,
  });

  final LibraryViewModel libraryViewModel;
  final SettingsViewModel settingsViewModel;
  final MediaRepository mediaRepository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.libraryViewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      LibraryPage(
        viewModel: widget.libraryViewModel,
        settingsViewModel: widget.settingsViewModel,
        mediaRepository: widget.mediaRepository,
      ),
      SettingsPage(viewModel: widget.settingsViewModel),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Local',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
