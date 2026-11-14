import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorVector {
  const SensorVector(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

class CrashDetectionResult {
  const CrashDetectionResult({required this.detectedAt, required this.peakGForce, required this.gyroscope});

  final DateTime detectedAt;
  final double peakGForce;
  final SensorVector gyroscope;
}

class _CrashSample {
  const _CrashSample({required this.at, required this.filteredG, required this.gyroscope, required this.speedMps});

  final DateTime at;
  final double filteredG;
  final SensorVector gyroscope;
  final double? speedMps;
}

class CrashDetectionService {
  CrashDetectionService({
    Stream<AccelerometerEvent>? accelerometerEvents,
    Stream<GyroscopeEvent>? gyroscopeEvents,
    Stream<Position>? positionEvents,
    DateTime Function()? clock,
    this.window = const Duration(seconds: 2),
    this.cooldown = const Duration(seconds: 30),
    this.lowPassAlpha = 0.35,
    this.gyroscopeSpikeThreshold = 2.5,
  })  : _accelerometerEvents = accelerometerEvents,
        _gyroscopeEvents = gyroscopeEvents,
        _positionEvents = positionEvents,
        _clock = clock ?? DateTime.now;

  static const gravity = 9.81;
  final Duration window;
  final Duration cooldown;
  final double lowPassAlpha;
  final double gyroscopeSpikeThreshold;
  final Stream<AccelerometerEvent>? _accelerometerEvents;
  final Stream<GyroscopeEvent>? _gyroscopeEvents;
  final Stream<Position>? _positionEvents;
  final DateTime Function() _clock;
  final List<_CrashSample> _samples = [];
  final StreamController<CrashDetectionResult> _crashEvents = StreamController.broadcast();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<Position>? _positionSubscription;
  SensorVector _latestGyroscope = const SensorVector(0, 0, 0);
  double? _latestSpeedMps;
  double? _filteredG;
  DateTime? _lastCrashAt;
  double thresholdG = 4.0;
  bool _running = false;

  Stream<CrashDetectionResult> get crashEvents => _crashEvents.stream;
  bool get isRunning => _running;
  int get bufferedSampleCount => _samples.length;

  void setSensitivity(String sensitivity) {
    thresholdG = switch (sensitivity.toLowerCase()) {
      'low' => 5.0,
      'high' => 3.0,
      _ => 4.0,
    };
  }

  Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      final accelerometerStream = _accelerometerEvents ?? accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 20));
      final gyroscopeStream = _gyroscopeEvents ?? gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 20));
      final positionStream = _positionEvents ?? Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0),
      );
      _gyroscopeSubscription = gyroscopeStream.listen(
        (event) => _latestGyroscope = SensorVector(event.x, event.y, event.z),
        onError: (Object _) {},
      );
      _positionSubscription = positionStream.listen(
        (position) => _latestSpeedMps = position.speed.isFinite && position.speed >= 0 ? position.speed : null,
        onError: (Object _) {},
      );
      _accelerometerSubscription = accelerometerStream.listen(
        (event) => addSensorSample(
          acceleration: SensorVector(event.x, event.y, event.z),
          gyroscope: _latestGyroscope,
          speedMps: _latestSpeedMps,
          sampledAt: _clock(),
        ),
        onError: (Object _) {},
      );
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _running = false;
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    await _positionSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _positionSubscription = null;
  }

  CrashDetectionResult? addSensorSample({
    required SensorVector acceleration,
    required SensorVector gyroscope,
    double? speedMps,
    DateTime? sampledAt,
  }) {
    final now = sampledAt ?? _clock();
    final totalG = acceleration.magnitude / gravity;
    final dynamicG = (totalG - 1).abs();
    _filteredG = _filteredG == null ? dynamicG : lowPassAlpha * dynamicG + (1 - lowPassAlpha) * _filteredG!;
    _samples.add(_CrashSample(at: now, filteredG: _filteredG!, gyroscope: gyroscope, speedMps: speedMps));
    _samples.removeWhere((sample) => now.difference(sample.at) > window);

    final lastCrash = _lastCrashAt;
    if (lastCrash != null && now.difference(lastCrash) < cooldown) return null;

    final gyroSpike = gyroscope.magnitude >= gyroscopeSpikeThreshold;
    final abruptSpeedDrop = _hasAbruptSpeedDrop(now, speedMps);
    if (_filteredG! < thresholdG || (!gyroSpike && !abruptSpeedDrop)) return null;

    final peakG = _samples.fold<double>(0, (peak, sample) => math.max(peak, sample.filteredG).toDouble());
    final result = CrashDetectionResult(detectedAt: now, peakGForce: peakG, gyroscope: gyroscope);
    _lastCrashAt = now;
    _crashEvents.add(result);
    return result;
  }

  bool _hasAbruptSpeedDrop(DateTime now, double? currentSpeedMps) {
    if (currentSpeedMps == null) return false;
    final previous = _samples.where((sample) =>
      sample.speedMps != null && sample.at.isBefore(now) && now.difference(sample.at) <= const Duration(seconds: 1));
    if (previous.isEmpty) return false;
    final priorSpeed = previous.first.speedMps!;
    return priorSpeed >= 5 && priorSpeed - currentSpeedMps >= math.max(8, priorSpeed * 0.6);
  }

  void reset() {
    _samples.clear();
    _filteredG = null;
    _lastCrashAt = null;
    _latestSpeedMps = null;
    _latestGyroscope = const SensorVector(0, 0, 0);
  }

  Future<void> dispose() async {
    await stop();
    await _crashEvents.close();
  }
}