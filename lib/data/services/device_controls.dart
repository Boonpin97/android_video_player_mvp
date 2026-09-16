import 'package:flutter/services.dart';

class DeviceControls {
  static const _channel = MethodChannel('player/device');
  Future<double> brightness() async =>
      (await _channel.invokeMethod<num>('getBrightness'))?.toDouble() ?? 0.5;
  Future<double> volume() async =>
      (await _channel.invokeMethod<num>('getVolume'))?.toDouble() ?? 0.5;
  Future<void> setBrightness(double value) => _channel.invokeMethod<void>(
    'setBrightness',
    {'value': value.clamp(0.02, 1.0)},
  );
  Future<void> resetBrightness() =>
      _channel.invokeMethod<void>('setBrightness', {'value': -1.0});
  Future<void> setVolume(double value) => _channel.invokeMethod<void>(
    'setVolume',
    {'value': value.clamp(0.0, 1.0)},
  );
}
