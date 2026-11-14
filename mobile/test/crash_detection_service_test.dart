import 'package:flutter_test/flutter_test.dart';
import 'package:resqdrive/services/crash_detection_service.dart';

void main() {
  group('CrashDetectionService', () {
    final start = DateTime.utc(2026, 10, 15);

    test('requires an impact and a gyro spike or abrupt speed drop', () {
      final service = CrashDetectionService();
      CrashDetectionResult? result;
      for (var index = 0; index < 20; index++) {
        result = service.addSensorSample(
          acceleration: const SensorVector(0, 9.81, 0),
          gyroscope: const SensorVector(0, 0, 0),
          sampledAt: start.add(Duration(milliseconds: index * 20)),
        );
      }
      expect(result, isNull);

      for (var index = 20; index < 35; index++) {
        result = service.addSensorSample(
          acceleration: const SensorVector(0, 58.86, 0),
          gyroscope: const SensorVector(3, 0, 0),
          sampledAt: start.add(Duration(milliseconds: index * 20)),
        );
        if (result != null) break;
      }
      expect(result, isNotNull);
      expect(result!.peakGForce, greaterThanOrEqualTo(4));
    });

    test('detects a sharp GPS speed drop when the impact threshold is crossed', () {
      final service = CrashDetectionService();
      for (var index = 0; index < 20; index++) {
        service.addSensorSample(
          acceleration: const SensorVector(0, 9.81, 0),
          gyroscope: const SensorVector(0, 0, 0),
          speedMps: 18,
          sampledAt: start.add(Duration(milliseconds: index * 20)),
        );
      }
      CrashDetectionResult? result;
      for (var index = 20; index < 35; index++) {
        result = service.addSensorSample(
          acceleration: const SensorVector(0, 58.86, 0),
          gyroscope: const SensorVector(0, 0, 0),
          speedMps: 0,
          sampledAt: start.add(Duration(milliseconds: index * 20)),
        );
        if (result != null) break;
      }
      expect(result, isNotNull);
    });

    test('applies sensitivity thresholds and ignores repeat events during cooldown', () {
      final service = CrashDetectionService();
      service.setSensitivity('Low');
      expect(service.thresholdG, 5);
      service.setSensitivity('High');
      expect(service.thresholdG, 3);

      CrashDetectionResult? first;
      for (var index = 0; index < 20; index++) {
        first = service.addSensorSample(
          acceleration: const SensorVector(0, 58.86, 0),
          gyroscope: const SensorVector(3, 0, 0),
          sampledAt: start.add(Duration(milliseconds: index * 20)),
        );
        if (first != null) break;
      }
      expect(first, isNotNull);
      final repeated = service.addSensorSample(
        acceleration: const SensorVector(0, 58.86, 0),
        gyroscope: const SensorVector(3, 0, 0),
        sampledAt: start.add(const Duration(seconds: 2)),
      );
      expect(repeated, isNull);
    });

    test('keeps only samples inside the rolling time window', () {
      final service = CrashDetectionService();
      for (var index = 0; index < 150; index++) {
        service.addSensorSample(
          acceleration: const SensorVector(0, 9.81, 0),
          gyroscope: const SensorVector(0, 0, 0),
          sampledAt: start.add(Duration(milliseconds: index * 20)),
        );
      }
      expect(service.bufferedSampleCount, lessThanOrEqualTo(101));
      expect(service.bufferedSampleCount, greaterThan(0));
    });
  });
}