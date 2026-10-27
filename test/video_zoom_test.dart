import 'package:android_video_player_mvp/ui/features/player/view_models/video_zoom.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(800, 400);
  const center = Offset(400, 200);

  VideoZoom pinch(
    VideoZoom zoom,
    double factor, {
    Offset focal = center,
    Offset delta = Offset.zero,
  }) => zoom.update(
    factor: factor,
    focal: focal,
    focalDelta: delta,
    viewport: viewport,
  );

  test('pinching zooms in and out within limits', () {
    final zoomedIn = pinch(VideoZoom.identity, 2);
    expect(zoomedIn.scale, 2);
    expect(zoomedIn.offset, Offset.zero);
    expect(pinch(zoomedIn, 0.5).scale, 1);

    expect(pinch(VideoZoom.identity, 10).scale, VideoZoom.maxScale);
    expect(pinch(VideoZoom.identity, 0.1).scale, VideoZoom.minScale);
  });

  test('the point under the fingers stays anchored while zooming', () {
    const focal = Offset(600, 300);
    final zoom = pinch(VideoZoom.identity, 2, focal: focal);
    // Content point p maps to center + offset + (p - center) * scale.
    final mapped = center + zoom.offset + (focal - center) * zoom.scale;
    expect(mapped, focal);
  });

  test('panning cannot drag the picture past its edges', () {
    final zoomed = pinch(VideoZoom.identity, 2);
    final panned = pinch(zoomed, 1, delta: const Offset(5000, -5000));
    expect(panned.offset, const Offset(400, -200));

    // Zoomed out, the smaller picture stays centred.
    final out = pinch(VideoZoom.identity, 0.5, delta: const Offset(80, 40));
    expect(out.offset, Offset.zero);
  });

  test('releasing near 100% snaps back to the fitted picture', () {
    final near = pinch(VideoZoom.identity, 1.04, focal: const Offset(700, 50));
    expect(near.isIdentity, isFalse);
    expect(near.settle(viewport).isIdentity, isTrue);

    final zoomed = pinch(VideoZoom.identity, 1.5);
    expect(zoomed.settle(viewport).scale, 1.5);
  });
}
