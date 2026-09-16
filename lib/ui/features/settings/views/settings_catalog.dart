/// Reference screen rows. An action is present only when the app supports it.
class SettingEntry {
  const SettingEntry(
    this.title, {
    this.subtitle,
    this.checked,
    this.action,
    this.section = false,
  });
  const SettingEntry.section(this.title)
    : subtitle = null,
      checked = null,
      action = null,
      section = true;
  final String title;
  final String? subtitle;
  final bool? checked;
  final String? action;
  final bool section;
}

const settingsCatalog = <String, List<SettingEntry>>{
  'List': [
    SettingEntry.section('Appearance'),
    SettingEntry(
      'Last media in each folder',
      subtitle: 'Mark last played media in each folder.',
      checked: true,
    ),
    SettingEntry(
      'Scroll down to last media',
      subtitle: 'Auto-scroll to position of the last played media.',
      checked: false,
    ),
    SettingEntry(
      'Select thumbnail',
      subtitle: 'Switch to selection mode by touching the thumbnail or icon.',
      checked: false,
    ),
    SettingEntry(
      'Floating button',
      subtitle:
          'Place a floating button on the bottom right corner of the screen to start last played media.',
      checked: true,
    ),
    SettingEntry(
      'Period tagged as "NEW"',
      subtitle:
          '"NEW" tag will be displayed if the file was modified within this period.',
    ),
    SettingEntry.section('Scan'),
    SettingEntry(
      'Folders',
      subtitle: 'Select folders to be included in the media library.',
    ),
    SettingEntry(
      'File extensions',
      subtitle:
          'Select file extensions for folder scanning. It is possible to configure decoders per extension types.',
    ),
    SettingEntry(
      'Recognize .nomedia',
      subtitle:
          'Exclude any media file from video list if a ".nomedia" file exists in that folder or a parent folder.',
      checked: true,
    ),
    SettingEntry(
      'Show hidden files and folders',
      subtitle: 'Show hidden folders and files starting with "." (dot).',
      checked: false,
    ),
  ],
  'Player': [
    SettingEntry.section('Interface'),
    SettingEntry('Style', action: 'Style'),
    SettingEntry(
      'Screen',
      subtitle: 'Screen settings: Orientation, Full Screen, Brightness, etc.',
      action: 'Screen',
    ),
    SettingEntry(
      'Controls',
      subtitle: 'Input controls: Touch actions, gestures, lock mode, etc.',
      action: 'Controls',
    ),
    SettingEntry(
      'Navigation',
      subtitle:
          'Navigation settings: seeking settings, forward/backward buttons, etc.',
      action: 'Navigation',
    ),
    SettingEntry(
      'Double-tap the back button',
      subtitle: 'Press the back button twice to close playback screen.',
      checked: false,
      action: 'doubleBack',
    ),
    SettingEntry(
      'Quick zoom',
      subtitle:
          "Skip zoom steps between 100% and 'fit to screen' (150%, 200%, etc.).",
      checked: true,
      action: 'quickZoom',
    ),
    SettingEntry.section('Playback'),
    SettingEntry(
      'Resume',
      subtitle: 'Select whether to resume from the point where you stopped.',
      action: 'resume',
    ),
    SettingEntry(
      'Resume only the first file',
      subtitle:
          'Apply resume setting only on the first file. Next files will start from the beginning.',
      checked: false,
      action: 'resumeFirst',
    ),
    SettingEntry('Default playback speed', action: 'speed'),
    SettingEntry(
      'Remember selections',
      subtitle:
          'Remember selections for each file such as choice of audio track, subtitle track, decoder...',
      checked: true,
    ),
    SettingEntry(
      'Back to list',
      subtitle: 'Return to the list after playback is completed.',
      checked: false,
      action: 'backToList',
    ),
    SettingEntry(
      'Preview while seeking',
      subtitle: 'Display preview image while changing playback position.',
      checked: true,
    ),
    SettingEntry(
      'Preview while seeking (network)',
      subtitle: 'Display preview image for network play.',
    ),
    SettingEntry(
      'Fast seeking',
      subtitle:
          'Seek to nearest key-frame position instead of exact position. This setting applies to HW+ and SW decoder.',
      checked: true,
    ),
    SettingEntry(
      'Play alone',
      subtitle:
          'Stop other players while playing back videos or audios. Also pause when other players begin to play or you make a phone call.',
      checked: true,
    ),
    SettingEntry(
      'Media buttons',
      subtitle:
          'Respond to media control buttons from headset, Bluetooth, etc.',
      checked: true,
    ),
    SettingEntry(
      'Double/Triple Press â†’ Next/Prev',
      subtitle: 'Treat Double/Triple press events as Next/Prev',
      checked: true,
    ),
    SettingEntry(
      'Next/Prev â†’ FF/Rew',
      subtitle: 'Treat Next/Prev media buttons as FF/Rew button.',
      checked: false,
    ),
    SettingEntry(
      'Toggle playback with play button',
      subtitle:
          "Toggle playback in response to 'play' media button. This option is useful only for devices having trouble with the play button.",
      checked: false,
    ),
    SettingEntry(
      'Smart Previous Button',
      subtitle:
          "If you select 'previous' button, it will resume again from the beginning or open the previous file depending upon the current playback position.",
      checked: true,
      action: 'smartPrevious',
    ),
    SettingEntry(
      'Suppress error message',
      subtitle:
          'Skip to next video without displaying error message if video loading fails.',
      checked: false,
    ),
    SettingEntry(
      'Use custom Picture-in-Picture popup',
      subtitle: 'Use custom Picture-in-Picture resizable popup.',
      checked: true,
    ),
    SettingEntry.section('Background Play'),
    SettingEntry(
      'Background/PiP mode',
      subtitle:
          'Allows you to control the player behavior when switching to another app.',
      action: 'background',
    ),
    SettingEntry(
      'Background play (audio)',
      subtitle: 'Use background play for audio playback.',
      checked: true,
      action: 'backgroundCheck',
    ),
    SettingEntry(
      'Album art',
      subtitle: 'Display cover art on the lock screen.',
      checked: true,
    ),
    SettingEntry(
      'Smooth switch',
      subtitle:
          'Fade in and out audio when switching to and return back from background play.',
      checked: false,
    ),
    SettingEntry.section('Miscellaneous'),
    SettingEntry(
      'Video resizing delay',
      subtitle:
          'Set delay time for resizing videos on hardware decoders. Set higher value if screen flickers severely or freezes while resizing.',
    ),
    SettingEntry(
      'Limit Video Resizing',
      subtitle:
          'Do not increase video size if it exceeds its display size. (HW decoder only)',
      checked: false,
    ),
    SettingEntry(
      'Turn off button backlight',
      subtitle: "Turn off main buttons' back-light during playback.",
      checked: true,
    ),
    SettingEntry(
      'Loading circle animation',
      checked: true,
      action: 'loadingCircle',
    ),
    SettingEntry(
      'Software navigation buttons',
      subtitle:
          'This device has software navigation buttons (back, home, menu, etc.) Check this option if buttons are not hidden automatically.',
      checked: true,
    ),
    SettingEntry(
      'Android 4.0 compatible mode',
      subtitle: 'Use this mode if you have problem with screen layout.',
      checked: false,
    ),
  ],
  'Decoder': [
    SettingEntry.section('Video decoder'),
    SettingEntry(
      'Default decoder',
      subtitle: 'Choose HW, HW+ or SW for video playback.',
      action: 'decoder',
    ),
    SettingEntry(
      'HW',
      subtitle: 'Hardware decoding with compatibility rendering.',
      action: 'decoder',
    ),
    SettingEntry(
      'HW+',
      subtitle: 'Hardware decoding with direct rendering.',
      action: 'decoder',
    ),
    SettingEntry(
      'SW',
      subtitle: 'Software decoding, including WMV and other legacy formats.',
      action: 'decoder',
    ),
    SettingEntry(
      'Automatic fallback',
      subtitle:
          'If the phone cannot decode a format in hardware, software decoding is used.',
      action: 'decoderInfo',
    ),
  ],
  'Audio': [
    SettingEntry(
      'Audio player',
      subtitle: 'Use as audio player.',
      checked: false,
    ),
    SettingEntry(
      'Audio output',
      subtitle: 'Change the method used to output audio.',
    ),
    SettingEntry(
      'Volume boost',
      subtitle:
          'Audio volume can be boosted up to 200% if you use HW+ or SW decoder.',
      checked: true,
    ),
    SettingEntry(
      'System volume',
      subtitle: 'Synchronize sound volume with the system media volume.',
      checked: true,
    ),
    SettingEntry(
      'System volume panel',
      subtitle:
          'Show system volume panel while changing volume with the headset plugged in.',
      checked: true,
    ),
    SettingEntry(
      'Pause on headset disconnected',
      subtitle:
          'Pause playback when wired/Bluetooth headset disconnected from the device.',
      checked: true,
    ),
    SettingEntry('Fade on start', checked: true),
    SettingEntry('Fade on seek', checked: true),
    SettingEntry(
      'Preferred audio language',
      subtitle:
          'Language of the audio track you want to use. It may not be used with HW decoder.',
    ),
    SettingEntry(
      'Audio delay',
      subtitle:
          'Set audio delay time for audio synchronization. It may not be used with HW decoder.',
    ),
    SettingEntry(
      'Bluetooth audio delay',
      subtitle:
          'Set Bluetooth audio delay time for audio synchronization. It may not be used with HW decoder.',
    ),
    SettingEntry(
      'Prefer audio passthrough mode',
      subtitle:
          "Whenever possible, prefer audio passthrough mode over internal decoders. It allows you to pass the sourceâ€™s audio signal to an external receiver directly. It may not be used with HW decoder.",
      checked: true,
    ),
    SettingEntry('Audio equalizer', checked: false),
  ],
  'Subtitle': [
    SettingEntry(
      'Subtitle Folder',
      subtitle:
          'Choose a folder to automatically load .srt files with the same name as each video.',
      action: 'subtitleFolder',
    ),
    SettingEntry(
      'Clear subtitle folder',
      subtitle: 'Stop automatically loading subtitles from a folder.',
      action: 'clearSubtitleFolder',
    ),
    SettingEntry(
      'Character encoding',
      subtitle: 'Select character encoding of your subtitle file.',
    ),
    SettingEntry(
      'Preferred subtitle language',
      subtitle:
          'Language of the subtitle track you want to use. It may not be used with HW decoder.',
    ),
    SettingEntry(
      'Default sync',
      subtitle:
          'Set default time adjustment for subtitle track synchronization.',
    ),
    SettingEntry(
      'Sync for HW decoder',
      subtitle: 'Adjust subtitle track synchronization for HW decoder.',
    ),
    SettingEntry.section('Appearance'),
    SettingEntry(
      'Text',
      subtitle: 'Subtitle text settings: font, size, color, border, etc.',
      action: 'Text',
    ),
    SettingEntry(
      'Layout',
      subtitle:
          'Subtitle layout settings: alignment, padding, background color.',
    ),
    SettingEntry('Font Folder', subtitle: '/storage/emulated/0'),
    SettingEntry.section('Text processing'),
    SettingEntry(
      'Italic effect',
      subtitle:
          'Sentences that start with "/" (forward slash) will be displayed in italics.',
      checked: false,
    ),
  ],
  'General': [
    SettingEntry(
      'App Language',
      subtitle: 'System default',
      action: 'language',
    ),
    SettingEntry(
      'Play media links',
      subtitle:
          'Play HTTP/HTTPS media links. This option can interfere with file downloading.',
      checked: true,
    ),
    SettingEntry(
      'Http User-Agent',
      subtitle:
          "Override 'User-Agent' on connecting to web server. Leave blank to use default value.",
    ),
    SettingEntry(
      'Quit Button',
      subtitle:
          "Display Quit button on the Me page (mobile devices) / menu (TV mode). This will terminate the app completely unlike 'back' or 'home' button.",
      checked: false,
    ),
    SettingEntry.section('Edit'),
    SettingEntry(
      'Allow editing',
      subtitle:
          'Enable edit menu which allows you to delete or rename files and folders.',
      checked: true,
      action: 'allowEditing',
    ),
    SettingEntry('Delete subtitle files together', checked: true),
    SettingEntry.section('User data'),
    SettingEntry(
      'Clear history',
      subtitle:
          'Clear all user activity records, including playback and search history.',
      action: 'history',
    ),
    SettingEntry(
      'Clear thumbnail cache',
      subtitle:
          'Clear cached thumbnails. Thumbnails will be generated again when media list is opened.',
      action: 'cache',
    ),
    SettingEntry('Cache thumbnail', checked: true),
    SettingEntry(
      'Clear font cache',
      subtitle:
          'Clear font cache for SubStation Alpha subtitle in case of corruption.',
    ),
    SettingEntry(
      'Reset settings',
      subtitle: 'Reset all settings to their default condition.',
      action: 'reset',
    ),
    SettingEntry(
      'Export',
      subtitle: 'Export settings and activity records to a file.',
    ),
    SettingEntry(
      'Import',
      subtitle: 'Import settings and activity records from a file.',
    ),
  ],
  'Style': [
    SettingEntry.section('Player appearance'),
    SettingEntry(
      'Shortcuts',
      subtitle: 'Show the circular shortcut buttons over the video.',
      checked: true,
      action: 'shortcuts',
    ),
    SettingEntry(
      'Loading circle animation',
      checked: true,
      action: 'loadingCircle',
    ),
  ],
  'Screen': [
    SettingEntry(
      'Fit to screen',
      subtitle: 'Fit the entire video inside the screen.',
      checked: true,
      action: 'fit',
    ),
    SettingEntry(
      'Landscape playback',
      subtitle: 'Open videos in landscape orientation.',
      checked: true,
      action: 'landscape',
    ),
  ],
  'Controls': [
    SettingEntry(
      'Seek drag sensitivity',
      subtitle: 'Adjust how far horizontal dragging seeks.',
      action: 'seekSensitivity',
    ),
    SettingEntry(
      'Double-tap to seek',
      subtitle: 'Tap twice on the left or right to seek 10 seconds.',
      checked: true,
      action: 'doubleTapSeek',
    ),
    SettingEntry(
      'Double-tap the back button',
      checked: false,
      action: 'doubleBack',
    ),
  ],
  'Navigation': [
    SettingEntry(
      'Smart Previous Button',
      subtitle: 'Restart the current video after 3 seconds of playback.',
      checked: true,
      action: 'smartPrevious',
    ),
    SettingEntry(
      'Back to list',
      subtitle: 'Return to the library when playback ends.',
      checked: false,
      action: 'backToList',
    ),
  ],
  'Text': [SettingEntry('Subtitle text size', action: 'subtitleSize')],
  'Development': [
    SettingEntry('Version', subtitle: 'Player Â· 1.0.0', action: 'version'),
    SettingEntry('Open source licenses', action: 'licenses'),
  ],
};
