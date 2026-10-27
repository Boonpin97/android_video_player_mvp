import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Pinch-zoom state of the video surface: a scale around the viewport centre
/// plus a pan offset. Zooming out below 100% keeps the picture centred, and
/// zooming in can never pan the picture past its own edges.
@immutable
class VideoZoom {
  const VideoZoom({this.scale = 1, this.offset = Offset.zero});

  static const identity = VideoZoom();
  static const minScale = 0.5, maxScale = 4.0;

  /// Scales this close to 100% snap back to exactly fit the screen.
  static const snapTolerance = 0.05;

  final double scale;
  final Offset offset;

  bool get isIdentity => scale == 1 && offset == Offset.zero;

  /// Applies one pinch update: multiplies the scale by [factor] around the
  /// [focal] point (viewport coordinates) and pans by [focalDelta].
  VideoZoom update({
    required double factor,
    required Offset focal,
    required Offset focalDelta,
    required Size viewport,
  }) {
    final next = (scale * factor).clamp(minScale, maxScale);
    final center = viewport.center(Offset.zero);
    // Keep the content point under the fingers anchored while scaling.
    final anchored =
        focal - center - (focal - center - offset) * (next / scale);
    return VideoZoom(
      scale: next,
      offset: anchored + focalDelta,
    )._clamped(viewport);
  }

  /// Snaps a nearly-unzoomed result back to the plain fitted picture.
  VideoZoom settle(Size viewport) =>
      (scale - 1).abs() <= snapTolerance ? identity : _clamped(viewport);

  VideoZoom _clamped(Size viewport) {
    final maxX = math.max(0.0, (scale - 1) * viewport.width / 2);
    final maxY = math.max(0.0, (scale - 1) * viewport.height / 2);
    return VideoZoom(
      scale: scale,
      offset: Offset(
        offset.dx.clamp(-maxX, maxX),
        offset.dy.clamp(-maxY, maxY),
      ),
    );
  }
}
