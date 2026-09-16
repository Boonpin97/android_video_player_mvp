# Player

Android video player with a reference-inspired folder library, settings pages, and landscape playback controls.

## Library

- Local and Me tabs, without the Music/Transfer tabs or top shortcut strip.
- Only main storage folders appear at the root. Open a folder to browse its immediate subfolders and videos. No synthetic Recent folder.
- Android MediaStore scanning, runtime media permission requests, search, list/grid layouts, and lazy thumbnails with a bounded cache. Thumbnails sample later scenes instead of frame zero, retry nearly black frames, and use a silent software decoder when Android cannot extract a frame. Two ordinary thumbnails can be extracted concurrently, while software fallbacks use a separate single-worker queue. Generated previews are saved in a bounded disk cache keyed by video modification time, so reopening the app reuses them. Failed cache entries can be retried, and Clear thumbnail cache clears both disk and memory.

## Playback

Playback uses media_kit/libmpv, including software decoding for WMV formats that the previous platform player could not open.

- HW: MediaCodec with frame copying (`mediacodec-copy`).
- HW+: direct MediaCodec rendering (`mediacodec`).
- SW: software decoding (`no`).

Select a decoder in the player or save a default under Settings > Decoder. Hardware modes fall back to software when the device cannot decode a format. Information shows the selected and active decoder. These labels describe this app's backend settings.

Drag horizontally to seek forward/backward. Drag vertically on the left half to change window brightness, or on the right half to change media volume. Brightness returns to the system default on leaving playback. A locked player ignores these gestures.

Settings > Subtitle > Subtitle Folder opens the Android folder picker. The selection persists across launches. Each video automatically loads a same-name SRT directly from that folder (Movie.wmv -> Movie.srt); filename matching also accepts differences in letter case. Missing files leave playback running, and manual subtitle selection still overrides the automatic choice. Clear subtitle folder disables the lookup. Gesture indicators have a transparent background with lightly shadowed text and icons.

Other working actions include queue selection, seek bar, speed, aspect ratio, rotation, mute, loop, shuffle, background audio, sleep timer, night mode, mirror/flip, external subtitles, bookmarks, favourites, and resume position.

Advanced reference features still show availability explanations: equalizer/audio effects, PiP, cutting, sharing, playlists, rename, and several advanced preferences. Background playback is not a persistent Android media service.

## Branding

The generated launcher icon is in `assets/branding/app-logo.png`. Generation details and the exact prompt are in [assets/branding/README.md](assets/branding/README.md). Regenerate Android icon resources with `dart run flutter_launcher_icons`.

## Verification

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Tests cover folder hierarchy, loading races, decoder preference persistence, simplified navigation, gesture direction and limits, disposal during media lookup, and reference menu layout in both orientations.

Backend references: [media_kit](https://pub.dev/packages/media_kit), [mpv hardware decoding](https://mpv.io/manual/master/#options-hwdec).

## Playback adjustments

The subtitle icon is outlined until an external subtitle track loads successfully, then becomes solid and names the loaded file in its tooltip. Matching SRTs must have the same base filename as their video.

Audio sync is available from the player toolbar or More menu. It adjusts audio relative to video from -3 to +3 seconds in 0.05-second increments, applies during playback, and remembers the value per video. Negative values make sound earlier; positive values make sound later. Reset returns to zero.

Seek sensitivity is available in the player More menu and Settings > Player > Controls. The 0.25x to 4x slider and +/-0.05x buttons save adjustments immediately. Reset restores 1x. This multiplier affects horizontal drag distance only.

## Library selection

Long-press a folder or video in list or grid view to select it. Tap more entries or Select all, then use the toolbar delete icon. Selected folders include all indexed videos in their subfolders; other files and physical directories are preserved. Android provides the shared-media deletion confirmation without an extra app dialog. Cancelling keeps the remaining selection; only confirmed deletions update the library.

