import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import 'api_service.dart';
import 'offline_incident_queue.dart';

class IncidentSubmissionService {
  IncidentSubmissionService({ApiService? api, OfflineIncidentQueue? queue, Connectivity? connectivity})
      : _api = api ?? ApiService(),
        _queue = queue ?? OfflineIncidentQueue(),
        _connectivity = connectivity ?? Connectivity();

  final ApiService _api;
  final OfflineIncidentQueue _queue;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;
  final Map<String, Position> _draftPositions = {};

  Future<void> initialize() async {
    await _queue.database;
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) retryPending();
    });
    _retryTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => retryPending());
  }

  Future<Map<String, dynamic>?> submit({
    required String vehicleId,
    required double peakG,
    required Map<String, double> gyroData,
    required DateTime timestamp,
  }) async {
    final position = await _bestAvailablePosition();
    final payload = <String, dynamic>{
      'vehicleId': int.tryParse(vehicleId),
      'lat': position?.latitude,
      'lng': position?.longitude,
      'peakG': peakG,
      'gyroData': gyroData,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
    if (position == null) {
      await _queue.enqueue(payload);
      return null;
    }
    try {
      return await _api.reportAccident(
        vehicleId: vehicleId,
        latitude: position.latitude,
        longitude: position.longitude,
        peakG: peakG,
        gyroData: gyroData,
        timestamp: timestamp,
      );
    } catch (_) {
      await _queue.enqueue(payload);
      return null;
    }
  }

  Future<String?> createDraft({
    required String vehicleId,
    required double peakG,
    required Map<String, double> gyroData,
    required DateTime timestamp,
  }) async {
    final position = await _bestAvailablePosition(timeout: const Duration(seconds: 2));
    if (position == null) return null;
    try {
      final incident = await _api.reportAccident(
        vehicleId: vehicleId,
        latitude: position.latitude,
        longitude: position.longitude,
        peakG: peakG,
        gyroData: gyroData,
        timestamp: timestamp,
        deferSos: true,
      );
      final id = incident['id']?.toString();
      if (id != null) _draftPositions[id] = position;
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<void> cancelDraft(String id) async {
    try {
      await _api.cancelAccident(id);
      _draftPositions.remove(id);
    } catch (_) {
      await _queue.enqueue({'mode': 'cancel', 'incidentId': id});
    }
  }

  Future<bool> escalateDraft(String id) async {
    final position = await _bestAvailablePosition() ?? _draftPositions[id];
    if (position == null) {
      await _queue.enqueue({'mode': 'escalate', 'incidentId': id, 'lat': null, 'lng': null});
      return false;
    }
    try {
      await _api.escalateAccident(id, latitude: position.latitude, longitude: position.longitude);
      _draftPositions.remove(id);
      return true;
    } catch (_) {
      await _queue.enqueue({'mode': 'escalate', 'incidentId': id, 'lat': position.latitude, 'lng': position.longitude});
      return false;
    }
  }

  Future<void> retryPending() async {
    for (final item in await _queue.pending()) {
      final id = item['id'] as int;
      final payload = item['payload'] as Map<String, dynamic>;
      final mode = payload['mode'] as String? ?? 'report';
      if (mode == 'cancel') {
        try {
          await _api.cancelAccident(payload['incidentId'] as String);
          await _queue.remove(id);
        } on DioException catch (error) {
          if (error.response?.statusCode == 404) {
            await _queue.remove(id);
            continue;
          }
          break;
        } catch (_) {
          break;
        }
        continue;
      }

      var latitude = (payload['lat'] as num?)?.toDouble();
      var longitude = (payload['lng'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        final position = await _bestAvailablePosition();
        if (position == null) continue;
        latitude = position.latitude;
        longitude = position.longitude;
      }
      try {
        if (mode == 'escalate') {
          await _api.escalateAccident(payload['incidentId'] as String, latitude: latitude, longitude: longitude);
        } else {
          await _api.reportAccident(
            vehicleId: '${payload['vehicleId'] ?? ''}',
            latitude: latitude,
            longitude: longitude,
            peakG: (payload['peakG'] as num).toDouble(),
            gyroData: (payload['gyroData'] as Map).map((key, value) => MapEntry('$key', (value as num).toDouble())),
            timestamp: DateTime.parse(payload['timestamp'] as String),
          );
        }
        await _queue.remove(id);
      } catch (_) {
        break;
      }
    }
  }

  Future<Position?> _bestAvailablePosition({Duration timeout = const Duration(seconds: 12)}) async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          return await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(accuracy: LocationAccuracy.bestForNavigation, timeLimit: timeout),
          );
        }
      }
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
    return Geolocator.getLastKnownPosition();
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    await _queue.close();
  }
}
