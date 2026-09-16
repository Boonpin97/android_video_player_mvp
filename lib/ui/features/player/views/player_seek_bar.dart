import 'package:flutter/material.dart';

import '../../../core/ui_helpers.dart';

/// Keeps drag previews local so scrubbing does not rebuild the video surface.
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.enabled,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final bool enabled;
  final Future<void> Function(Duration) onSeek;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _preview;
  int _seekGeneration = 0;

  Future<void> _commit(double value) async {
    final generation = ++_seekGeneration;
    try {
      await widget.onSeek(Duration(milliseconds: value.round()));
    } finally {
      if (mounted && generation == _seekGeneration) {
        setState(() => _preview = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.clamp(1, 1 << 53).toDouble();
    final enabled = widget.enabled && widget.duration > Duration.zero;
    final value = (_preview ?? widget.position.inMilliseconds.toDouble()).clamp(
      0.0,
      max,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 28),
            ),
            child: Slider(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              activeColor: const Color(0xff55b8fa),
              inactiveColor: Colors.white30,
              min: 0,
              max: max,
              value: value,
              semanticFormatterCallback: (value) =>
                  formatDuration(Duration(milliseconds: value.round())),
              onChangeStart: enabled
                  ? (value) {
                      _seekGeneration++;
                      setState(() => _preview = value);
                    }
                  : null,
              onChanged: enabled
                  ? (value) => setState(() => _preview = value)
                  : null,
              onChangeEnd: enabled ? _commit : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(Duration(milliseconds: value.round()))),
              Text(formatDuration(widget.duration)),
            ],
          ),
        ),
      ],
    );
  }
}
