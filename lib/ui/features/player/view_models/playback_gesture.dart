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
  });
  final Offset origin;
  final Size viewport;
  final Duration position, duration;
  final double brightness, volume, seekSensitivity;
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

  /// Curve steepness for horizontal seeking. Short drags seek finely, and the
  /// seek distance grows exponentially as the drag gets longer.
  static const seekCurve = 4.0;

  Duration get targetPosition {
    // A full-width swipe covers the whole video, bounded to 2–10 minutes.
    final fullSwipe = duration.inMilliseconds.clamp(120000, 600000);
    final fraction = travel.dx.abs() / math.max(1, viewport.width);
    final offset =
        fullSwipe *
        (math.exp(seekCurve * fraction) - 1) /
        (math.exp(seekCurve) - 1) *
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
