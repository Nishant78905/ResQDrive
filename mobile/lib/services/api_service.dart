import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/emergency_contact.dart';
import '../models/vehicle.dart';

class ApiService {
  ApiService({Dio? dio, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 12))) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  static const _tokenKey = 'resqdrive_jwt';
  static const _activeIncidentKey = 'resqdrive_active_incident';
  static const _activeIncidentStartedAtKey = 'resqdrive_active_incident_started_at';
  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<void> register({required String email, required String password, required String fullName, String? phone}) async {
    await _dio.post('/auth/register', data: {'email': email, 'password': password, 'fullName': fullName, 'phone': phone});
    await login(email: email, password: password);
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>('/auth/login', data: {'email': email, 'password': password});
    final token = response.data?['token'] as String?;
    if (token == null || token.isEmpty) throw const FormatException('The API did not return an access token.');
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> logout() async {
    try { await _dio.post('/auth/logout'); } catch (_) { /* local logout still completes offline */ }
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> hasStoredToken() async => (await _storage.read(key: _tokenKey)) != null;
  Future<void> storeActiveIncident(String id, DateTime startedAt) async {
    await _storage.write(key: _activeIncidentKey, value: id);
    await _storage.write(key: _activeIncidentStartedAtKey, value: startedAt.toUtc().toIso8601String());
  }
  Future<String?> readActiveIncident() => _storage.read(key: _activeIncidentKey);
  Future<DateTime?> readActiveIncidentStartedAt() async {
    final value = await _storage.read(key: _activeIncidentStartedAtKey);
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }
  Future<void> clearActiveIncident() async {
    await _storage.delete(key: _activeIncidentKey);
    await _storage.delete(key: _activeIncidentStartedAtKey);
  }

  Future<List<EmergencyContact>> getContacts() async {
    final response = await _dio.get<Map<String, dynamic>>('/contacts');
    return (response.data?['contacts'] as List<dynamic>? ?? [])
        .map((item) => EmergencyContact.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<EmergencyContact> createContact(EmergencyContact contact) async {
    final response = await _dio.post<Map<String, dynamic>>('/contacts', data: contact.toJson());
    return EmergencyContact.fromJson(response.data!['contact'] as Map<String, dynamic>);
  }
  Future<EmergencyContact> updateContact(String id, EmergencyContact contact) async {
    final response = await _dio.patch<Map<String, dynamic>>('/contacts/$id', data: contact.toJson());
    return EmergencyContact.fromJson(response.data!['contact'] as Map<String, dynamic>);
  }
  Future<void> deleteContact(String id) => _dio.delete('/contacts/$id');
  Future<Map<String, dynamic>> getProfile() async => (await _dio.get<Map<String, dynamic>>('/profile')).data?['profile'] as Map<String, dynamic>? ?? {};
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async => (await _dio.patch<Map<String, dynamic>>('/profile', data: data)).data?['profile'] as Map<String, dynamic>? ?? {};
  Future<Map<String, dynamic>> getEmergencySettings() async => (await _dio.get<Map<String, dynamic>>('/emergency-settings')).data?['settings'] as Map<String, dynamic>? ?? {};
  Future<Map<String, dynamic>> updateEmergencySettings(Map<String, dynamic> data) async => (await _dio.put<Map<String, dynamic>>('/emergency-settings', data: data)).data?['settings'] as Map<String, dynamic>? ?? {};
  Future<List<Map<String, dynamic>>> notificationHistory() async => ((await _dio.get<Map<String, dynamic>>('/notifications/history')).data?['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

  Future<List<Vehicle>> getVehicles() async {
    final response = await _dio.get<Map<String, dynamic>>('/vehicles');
    return (response.data?['vehicles'] as List<dynamic>? ?? [])
        .map((item) => Vehicle.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    final response = await _dio.post<Map<String, dynamic>>('/vehicles', data: vehicle.toJson());
    return Vehicle.fromJson(response.data!['vehicle'] as Map<String, dynamic>);
  }

  Future<Vehicle> updateVehicle(String id, Vehicle vehicle) async {
    final response = await _dio.patch<Map<String, dynamic>>('/vehicles/$id', data: vehicle.toJson());
    return Vehicle.fromJson(response.data!['vehicle'] as Map<String, dynamic>);
  }

  Future<void> deleteVehicle(String id) => _dio.delete('/vehicles/$id');

  Future<List<Map<String, dynamic>>> getAccidentHistory() async {
    final response = await _dio.get<Map<String, dynamic>>('/accidents/history');
    return (response.data?['accidents'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> reportAccident({
    required String vehicleId,
    required double latitude,
    required double longitude,
    required double peakG,
    required Map<String, double> gyroData,
    required DateTime timestamp,
    bool deferSos = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>('/accidents', data: {
      'vehicleId': int.tryParse(vehicleId),
      'lat': latitude,
      'lng': longitude,
      'peakG': peakG,
      'gyroData': gyroData,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'deferSos': deferSos,
    });
    return response.data?['accident'] as Map<String, dynamic>? ?? {};
  }

  Future<void> cancelAccident(String id) async {
    await _dio.patch<void>('/accidents/$id/cancel');
  }

  Future<Map<String, dynamic>> escalateAccident(String id, {required double latitude, required double longitude}) async {
    final response = await _dio.post<Map<String, dynamic>>('/accidents/$id/escalate', data: {'lat': latitude, 'lng': longitude});
    return response.data?['accident'] as Map<String, dynamic>? ?? {};
  }
}
