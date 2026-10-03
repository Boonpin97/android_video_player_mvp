import 'package:flutter/material.dart';

Future<void> chooseSeekSensitivity(
  BuildContext context, {
  required double sensitivity,
  required double curve,
  required Future<void> Function(double) onSensitivity,
  required Future<void> Function(double) onCurve,
}) => showDialog<void>(
  context: context,
  builder: (_) => SeekSensitivityDialog(
    initialSensitivity: sensitivity,
    initialCurve: curve,
    onSensitivityChanged: onSensitivity,
    onCurveChanged: onCurve,
  ),
);

class SeekSensitivityDialog extends StatefulWidget {
  const SeekSensitivityDialog({
    super.key,
    required this.initialSensitivity,
    required this.initialCurve,
    required this.onSensitivityChanged,
    required this.onCurveChanged,
  });
  final double initialSensitivity;
  final double initialCurve;
  final Future<void> Function(double) onSensitivityChanged;
  final Future<void> Function(double) onCurveChanged;

  /// Restored by Reset; matches `PlaybackGestureSession.defaultSeekCurve`.
  static const defaultCurve = 4.0;

  @override
  State<SeekSensitivityDialog> createState() => _SeekSensitivityDialogState();
}

class _SeekSensitivityDialogState extends State<SeekSensitivityDialog> {
  late double _sensitivity = widget.initialSensitivity;
  late double _appliedSensitivity = widget.initialSensitivity;
  late double _curve = widget.initialCurve;
  late double _appliedCurve = widget.initialCurve;
  bool _saving = false;
  String? _error;

  Future<void> _applySensitivity(double value) async {
    final previous = _appliedSensitivity;
    value = (value * 20).round().clamp(5, 80) / 20;
    setState(() {
      _sensitivity = value;
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSensitivityChanged(value);
      _appliedSensitivity = value;
    } catch (_) {
      if (mounted) {
        setState(() {
          _sensitivity = previous;
          _error = 'Could not save seek sensitivity. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyCurve(double value) async {
    final previous = _appliedCurve;
    value = (value * 4).round().clamp(2, 32) / 4;
    setState(() {
      _curve = value;
      _saving = true;
      _error = null;
    });
    try {
      await widget.onCurveChanged(value);
      _appliedCurve = value;
    } catch (_) {
      if (mounted) {
        setState(() {
          _curve = previous;
          _error = 'Could not save the acceleration curve. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    await _applySensitivity(1);
    if (mounted) await _applyCurve(SeekSensitivityDialog.defaultCurve);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Seek drag sensitivity'),
    content: SizedBox(
      width: 340,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_sensitivity.toStringAsFixed(2)}x',
              style: const TextStyle(fontSize: 26),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lower: finer control.\nHigher: seek farther.',
              textAlign: TextAlign.center,
            ),
            Slider(
              value: _sensitivity,
              min: 0.25,
              max: 4,
              divisions: 75,
              label: '${_sensitivity.toStringAsFixed(2)}x',
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _sensitivity = value),
              onChangeEnd: _saving ? null : _applySensitivity,
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: _saving
                        ? null
                        : () => _applySensitivity(_sensitivity - 0.05),
                    child: const Text('-0.05x'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: _saving ? null : _reset,
                    child: const Text('Reset'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: _saving
                        ? null
                        : () => _applySensitivity(_sensitivity + 0.05),
                    child: const Text('+0.05x'),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            Text(
              'Acceleration curve · ${_curve.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tunes the avalanche effect.\n'
              'Lower: even pace.\n'
              'Higher: gentle start, then a sharp jump.',
              textAlign: TextAlign.center,
            ),
            Slider(
              value: _curve,
              min: 0.5,
              max: 8,
              divisions: 30,
              label: _curve.toStringAsFixed(2),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _curve = value),
              onChangeEnd: _saving ? null : _applyCurve,
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: _saving
                        ? null
                        : () => _applyCurve(_curve - 0.25),
                    child: const Text('-0.25'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: _saving
                        ? null
                        : () => _applyCurve(_curve + 0.25),
                    child: const Text('+0.25'),
                  ),
                ),
              ],
            ),
            const Text('Saved for all videos.', style: TextStyle(fontSize: 12)),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );
}

class AudioSyncDialog extends StatefulWidget {
  const AudioSyncDialog({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });
  final double initialValue;
  final Future<void> Function(double) onChanged;
  @override
  State<AudioSyncDialog> createState() => _AudioSyncDialogState();
}

class _AudioSyncDialogState extends State<AudioSyncDialog> {
  late double _value = widget.initialValue;
  late double _applied = widget.initialValue;
  bool _saving = false;
  String? _error;

  Future<void> _apply(double value) async {
    final previous = _applied;
    value = (value * 20).round().clamp(-60, 60) / 20;
    setState(() {
      _value = value;
      _saving = true;
      _error = null;
    });
    try {
      await widget.onChanged(value);
      _applied = value;
    } catch (_) {
      if (mounted) {
        setState(() {
          _value = previous;
          _error = 'Could not adjust audio sync. Try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Audio sync'),
    content: SizedBox(
      width: 340,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_value > 0 ? '+' : ''}${_value.toStringAsFixed(2)} s',
              style: const TextStyle(fontSize: 26),
            ),
            const SizedBox(height: 8),
            const Text(
              'Negative: play sound earlier.\nPositive: play sound later.',
              textAlign: TextAlign.center,
            ),
            Slider(
              value: _value,
              min: -3,
              max: 3,
              divisions: 120,
              label: '${_value.toStringAsFixed(2)} s',
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _value = value),
              onChangeEnd: _saving ? null : _apply,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => _apply(_value - 0.05),
                  child: const Text('-0.05 s'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => _apply(0),
                  child: const Text('Reset'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => _apply(_value + 0.05),
                  child: const Text('+0.05 s'),
                ),
              ],
            ),
            const Text('Saved for this video.', style: TextStyle(fontSize: 12)),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );
}
