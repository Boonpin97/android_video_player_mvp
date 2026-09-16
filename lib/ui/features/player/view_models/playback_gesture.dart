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

  Duration get targetPosition {
    final span = math.min(duration.inMilliseconds, 120000);
    return Duration(
      milliseconds:
          (position.inMilliseconds +
                  travel.dx /
                      math.max(1, viewport.width) *
                      span *
                      seekSensitivity.clamp(0.25, 4))
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
