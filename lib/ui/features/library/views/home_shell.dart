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

  void _settings() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => SettingsPage(
        viewModel: widget.settingsViewModel,
        mediaRepository: widget.mediaRepository,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _currentIndex == 0
        ? LibraryPage(
            viewModel: widget.libraryViewModel,
            settingsViewModel: widget.settingsViewModel,
            mediaRepository: widget.mediaRepository,
          )
        : Scaffold(
            appBar: AppBar(title: const Text('Me')),
            body: ListView(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 30, 20, 28),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/branding/app-logo.png',
                          width: 56,
                          height: 56,
                        ),
                      ),
                      SizedBox(width: 18),
                      Text('Your video player', style: TextStyle(fontSize: 19)),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _settings,
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Player',
                    applicationVersion: '1.0.0',
                  ),
                ),
              ],
            ),
          ),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        if (widget.libraryViewModel.isDeleting) return;
        widget.libraryViewModel.clearSelection();
        setState(() => _currentIndex = index);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.folder, size: 25),
          label: 'Local',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_circle, size: 25),
          label: 'Me',
        ),
      ],
    ),
  );
}
