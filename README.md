# Android Video Player MVP

Flutter Android MVP for the reference video player project.

## Implemented MVP Surface

- Local video library scanning through `photo_manager`.
- Runtime media permission flow.
- Folder chips with media counts.
- List/grid video browsing.
- Video search.
- Thumbnail display when the platform media store provides thumbnails.
- Fullscreen-style video player screen using `video_player`.
- Playback overlay with title, play/pause, previous, next, seek bar, current time, duration, lock control, fit/crop toggle, subtitle picker, speed menu, information dialog, and more menu.
- Resume playback by saving playback position in `shared_preferences`.
- Playback speed control.
- Basic SRT/WebVTT subtitle loading through file picker.
- Basic settings screen for resume playback, background audio flag, fit mode, default speed, clear history, clear thumbnail cache notice, and reset settings.
- Delete video action through `photo_manager` system media deletion.
- Android manifest permissions for media reads, internet playback groundwork, and activity PiP support.

## MVP Limits

- Audio track enumeration and native audio track switching are not exposed by Flutter `video_player`; this needs a later Android Media3 platform bridge.
- Native picture-in-picture entry is declared in the Android manifest but not wired to a platform-channel button yet.
- Background audio behavior is configured through `VideoPlayerOptions`, but exact behavior depends on Android version and plugin support.
- File rename is not implemented yet because Android MediaStore rename requires more native/platform-specific handling than the MVP plugin stack exposes cleanly.
- Network URL playback is in the backlog, not the MVP implementation.
- Advanced decoder tuning, volume boost, and resume-only-first-file are logged in the spec backlog but not implemented in this MVP pass.

## Project Structure

```text
lib/
  data/
    repositories/
    services/
  domain/
    models/
  ui/
    core/
    features/
      library/
      player/
      settings/
```

## Verification

Run:

```bash
flutter analyze
flutter test
```

Android build requires an Android SDK on the host:

```bash
flutter build apk --debug
```
