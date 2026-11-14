import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../models/accident_record.dart';
import '../models/emergency_contact.dart';
import '../models/vehicle.dart';
import '../services/api_service.dart';
import '../services/crash_alert_notification_service.dart';
import '../services/crash_detection_service.dart';
import '../services/incident_submission_service.dart';
import '../services/monitoring_service.dart';
import '../services/permission_service.dart';

class AppProvider extends ChangeNotifier {
    AppProvider({ApiService? api, CrashDetectionService? crashDetection, IncidentSubmissionService? incidents})
      : _api = api ?? ApiService(),
      crashDetection = crashDetection ?? CrashDetectionService(),
      incidents = incidents ?? IncidentSubmissionService();

  final ApiService _api;
  final CrashDetectionService crashDetection;
    final IncidentSubmissionService incidents;
  bool isAuthenticated = false;
  bool isInitializing = true;
  bool isDemo = false;
  bool isDarkMode = false;
  bool monitoringActive = true;
  bool isLoading = false;
  String? errorMessage;
  String profileName = 'Driver';
  Position? currentPosition;
  DateTime? locationUpdatedAt;
  String locationStatus = 'Checking location';
  String sensitivity = 'Med';
  int countdownSeconds = 15;
  String? activeIncidentId;
  DateTime? activeIncidentStartedAt;
  bool policeEnabled = false;
  bool ambulanceEnabled = false;
  String policePhone = '';
  String ambulancePhone = '';

  final List<EmergencyContact> contacts = [];
  final List<Vehicle> vehicles = [];
  final List<AccidentRecord> history = [];

  Future<bool> login(String email, String password) => _authenticate(() => _api.login(email: email, password: password));

  Future<void> restoreSession() async {
    isAuthenticated = await _api.hasStoredToken();
    activeIncidentId = await _api.readActiveIncident();
    activeIncidentStartedAt = await _api.readActiveIncidentStartedAt();
    if (isAuthenticated) {
      await loadRemoteData();
      await refreshLocation();
    }
    isInitializing = false;
    notifyListeners();
  }

  Future<bool> register(String name, String email, String password) =>
      _authenticate(() => _api.register(email: email, password: password, fullName: name));

  Future<bool> _authenticate(Future<void> Function() operation) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await operation();
      isAuthenticated = true;
      isDemo = false;
      await loadRemoteData();
      await refreshLocation();
      return true;
    } on DioException catch (error) {
      errorMessage = error.response?.data is Map<String, dynamic>
          ? (error.response!.data as Map<String, dynamic>)['error'] as String? ?? 'Unable to connect to RESQDRIVE.'
          : 'Unable to connect to RESQDRIVE. Check your network and API URL.';
      return false;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRemoteData() async {
    try {
      final loadedContacts = await _api.getContacts();
      contacts..clear()..addAll(loadedContacts);
      final loadedVehicles = await _api.getVehicles();
      vehicles..clear()..addAll(loadedVehicles);
      if (vehicles.isNotEmpty) vehicles[0] = vehicles[0].copyWith(selected: true);
      final profile = await _api.getProfile();
      profileName = profile['full_name'] as String? ?? profile['fullName'] as String? ?? 'Driver';
      final incidents = await _api.getAccidentHistory();
      history..clear()..addAll(incidents.map(AccidentRecord.fromJson));
      final settings = await _api.getEmergencySettings();
      policeEnabled = settings['police_enabled'] as bool? ?? false;
      ambulanceEnabled = settings['ambulance_enabled'] as bool? ?? false;
      policePhone = settings['police_phone'] as String? ?? '';
      ambulancePhone = settings['ambulance_phone'] as String? ?? '';
      notifyListeners();
    } catch (_) { /* The dashboard remains usable while offline. */ }
  }
  Future<void> refreshLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        locationStatus = 'Location services are disabled';
        notifyListeners();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        locationStatus = permission == LocationPermission.deniedForever ? 'Location permission permanently denied' : 'Location permission denied';
        notifyListeners();
        return;
      }
      currentPosition = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
      locationUpdatedAt = DateTime.now();
      locationStatus = 'Location ready';
    } catch (_) {
      currentPosition ??= await Geolocator.getLastKnownPosition();
      locationStatus = currentPosition == null ? 'Location unavailable' : 'Last known location';
    }
    notifyListeners();
  }
  Future<void> saveEmergencySettings() async {
    await _api.updateEmergencySettings({'policeEnabled': policeEnabled, 'policePhone': policePhone, 'ambulanceEnabled': ambulanceEnabled, 'ambulancePhone': ambulancePhone});
    notifyListeners();
  }

  void continueDemo() {
    isAuthenticated = true;
    isDemo = true;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.logout();
    await _api.clearActiveIncident();
    await incidents.dispose();
    activeIncidentId = null;
    await MonitoringService.stop();
    isAuthenticated = false;
    isDemo = false;
    notifyListeners();
  }

  void setDarkMode(bool value) { isDarkMode = value; notifyListeners(); }
  void setProfileName(String value) { profileName = value; notifyListeners(); }
  void setMonitoring(bool value) {
    monitoringActive = value;
    if (value) {
      startCrashDetection();
    } else {
      MonitoringService.stop();
    }
    notifyListeners();
  }
  Future<void> startCrashDetection() async {
    try {
      await incidents.initialize();
      final permissionGranted = await PermissionService.requestMonitoringPermissions();
      if (!permissionGranted) {
        errorMessage = 'Location permission is required for emergency response.';
        notifyListeners();
        return;
      }
      await CrashAlertNotificationService.requestAndroidPermissions();
      await FlutterForegroundTask.saveData(key: 'crash_sensitivity', value: sensitivity);
      await MonitoringService.start();
    } catch (error) {
      errorMessage = 'Sensor monitoring could not start: $error';
      notifyListeners();
    }
  }
  void setSensitivity(String value) {
    sensitivity = value;
    crashDetection.setSensitivity(value);
    FlutterForegroundTask.sendDataToTask({'type': 'sensitivity', 'value': value});
    FlutterForegroundTask.saveData(key: 'crash_sensitivity', value: value);
    notifyListeners();
  }
  String get selectedVehicleId => vehicles.where((vehicle) => vehicle.selected).firstOrNull?.id ?? '';
  Future<String?> createIncidentDraft({required double peakG, required Map<String, double> gyroData, required DateTime timestamp}) async {
    await incidents.initialize();
    final id = await incidents.createDraft(vehicleId: selectedVehicleId, peakG: peakG, gyroData: gyroData, timestamp: timestamp);
    if (id != null) {
      activeIncidentId = id;
      activeIncidentStartedAt = timestamp;
      await _api.storeActiveIncident(id, timestamp);
    }
    return id;
  }
  Future<void> cancelIncidentDraft(String id) async {
    await incidents.cancelDraft(id);
    activeIncidentId = null;
    activeIncidentStartedAt = null;
    await _api.clearActiveIncident();
  }
  Future<bool> escalateIncidentDraft(String id) async {
    final queued = !await incidents.escalateDraft(id);
    if (!queued) {
      activeIncidentId = null;
      activeIncidentStartedAt = null;
      await _api.clearActiveIncident();
    }
    return queued;
  }
  Future<bool> submitIncident({required double peakG, required Map<String, double> gyroData, required DateTime timestamp}) async {
    await incidents.initialize();
    final incident = await incidents.submit(vehicleId: selectedVehicleId, peakG: peakG, gyroData: gyroData, timestamp: timestamp);
    return incident == null;
  }
  void setCountdown(int value) { countdownSeconds = value.clamp(10, 15).toInt(); notifyListeners(); }

  Future<void> addContact(EmergencyContact contact) async {
    contact = contact.copyWith(priority: contacts.length + 1);
    if (!isDemo) contact = await _api.createContact(contact);
    contacts.add(contact);
    notifyListeners();
  }
  Future<void> updateContact(String id, EmergencyContact updated) async {
    if (!isDemo) updated = await _api.updateContact(id, updated);
    final index = contacts.indexWhere((item) => item.id == id);
    if (index >= 0) contacts[index] = updated;
    notifyListeners();
  }
  Future<void> removeContact(String id) async { if (!isDemo) await _api.deleteContact(id); contacts.removeWhere((item) => item.id == id); notifyListeners(); }

  Future<void> addVehicle(Vehicle vehicle) async {
    if (!isDemo) vehicle = await _api.createVehicle(vehicle);
    vehicles.add(vehicle.copyWith(selected: vehicles.isEmpty));
    notifyListeners();
  }
  Future<void> updateVehicle(String id, Vehicle vehicle) async {
    if (!isDemo) vehicle = await _api.updateVehicle(id, vehicle);
    final index = vehicles.indexWhere((item) => item.id == id);
    if (index >= 0) vehicles[index] = vehicle.copyWith(id: id, selected: vehicles[index].selected);
    notifyListeners();
  }
  void selectVehicle(String id) {
    for (var index = 0; index < vehicles.length; index++) {
      vehicles[index] = vehicles[index].copyWith(selected: vehicles[index].id == id);
    }
    notifyListeners();
  }
  Future<void> removeVehicle(String id) async { if (!isDemo) await _api.deleteVehicle(id); vehicles.removeWhere((item) => item.id == id); notifyListeners(); }

  void addHistory(AccidentRecord record) { history.insert(0, record); notifyListeners(); }
}
