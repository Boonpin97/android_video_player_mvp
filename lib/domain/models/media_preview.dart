import 'dart:typed_data';

class MediaPreview {
  const MediaPreview(this.bytes, {this.duration = Duration.zero});
  final Uint8List bytes;
  final Duration duration;
}

/// Skip opening fades and try another scene before accepting a blank thumbnail.
List<Duration> thumbnailPositions(Duration duration) {
  if (duration <= Duration.zero) {
    return const [Duration(seconds: 10), Duration(seconds: 30), Duration.zero];
  }
  final end = (duration.inMilliseconds - 1).clamp(0, duration.inMilliseconds);
  return [0.1, 0.33, 0.6]
      .map(
        (fraction) => Duration(
          milliseconds: (duration.inMilliseconds * fraction).round().clamp(
            0,
            end,
          ),
        ),
      )
      .toSet()
      .toList();
}

bool hasVisibleThumbnailContent(Uint8List rgba) {
  if (rgba.length < 4) return false;
  var visible = 0;
  final pixels = rgba.length ~/ 4;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final luminance =
        (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
    if (luminance > 24 && rgba[i + 3] > 0) visible++;
  }
  return visible / pixels >= 0.12;
}
