import 'dart:math' as math;
import 'package:flutter/widgets.dart';

enum PlaybackGestureKind { seek, brightness, volume }

class PlaybackGestureSession {
  PlaybackGestureSession({
    required this.origin,
    required this.viewport,
    required this.position,
    required this.duration,
    required this.brightness,
    required this.volume,
    this.seekSensitivity = 1,
    this.seekCurve = defaultSeekCurve,
  });
  final Offset origin;
  final Size viewport;
  final Duration position, duration;
  final double brightness, volume, seekSensitivity, seekCurve;
  Offset travel = Offset.zero;
  PlaybackGestureKind? kind;

  void update(Offset delta) {
    travel += delta;
    if (kind == null && travel.distance >= 12) {
      kind = travel.dx.abs() >= travel.dy.abs()
          ? PlaybackGestureKind.seek
          : origin.dx < viewport.width / 2
          ? PlaybackGestureKind.brightness
          : PlaybackGestureKind.volume;
    }
  }

  /// Default steepness of the horizontal seek curve. Low values are near
  /// linear; high values keep short drags fine and avalanche near the end.
  static const defaultSeekCurve = 4.0;

  Duration get targetPosition {
    // A full-width swipe covers the whole video, bounded to 2–10 minutes.
    final fullSwipe = duration.inMilliseconds.clamp(120000, 600000);
    final fraction = travel.dx.abs() / math.max(1, viewport.width);
    final curve = seekCurve.clamp(0.5, 8);
    final offset =
        fullSwipe *
        (math.exp(curve * fraction) - 1) /
        (math.exp(curve) - 1) *
        seekSensitivity.clamp(0.25, 4);
    return Duration(
      milliseconds: (position.inMilliseconds + offset * travel.dx.sign)
          .round()
          .clamp(0, duration.inMilliseconds),
    );
  }

  double get targetBrightness =>
      (brightness - travel.dy / math.max(1, viewport.height) * 1.5).clamp(
        0.02,
        1.0,
      );
  double get targetVolume =>
      (volume - travel.dy / math.max(1, viewport.height) * 1.5).clamp(0.0, 2.0);
}
