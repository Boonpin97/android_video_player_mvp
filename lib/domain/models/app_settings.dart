class AppSettings {
  const AppSettings({
    required this.resumePlayback,
    required this.backgroundAudio,
    required this.clearHistoryOnExit,
    required this.aspectFitMode,
    required this.defaultPlaybackSpeed,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      resumePlayback: true,
      backgroundAudio: true,
      clearHistoryOnExit: false,
      aspectFitMode: true,
      defaultPlaybackSpeed: 1,
    );
  }

  final bool resumePlayback;
  final bool backgroundAudio;
  final bool clearHistoryOnExit;
  final bool aspectFitMode;
  final double defaultPlaybackSpeed;

  AppSettings copyWith({
    bool? resumePlayback,
    bool? backgroundAudio,
    bool? clearHistoryOnExit,
    bool? aspectFitMode,
    double? defaultPlaybackSpeed,
  }) {
    return AppSettings(
      resumePlayback: resumePlayback ?? this.resumePlayback,
      backgroundAudio: backgroundAudio ?? this.backgroundAudio,
      clearHistoryOnExit: clearHistoryOnExit ?? this.clearHistoryOnExit,
      aspectFitMode: aspectFitMode ?? this.aspectFitMode,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
    );
  }
}
