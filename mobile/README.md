# RESQDRIVE Mobile

Flutter driver app source for Android and iOS. It uses Provider for app state, Dio for REST calls, and `flutter_secure_storage` for JWTs. Demo mode uses local sample data; account login and registration use `API_BASE_URL`.

## Toolchain

The foreground-service and notification package versions in `pubspec.yaml` require Flutter 3.44 / Dart 3.12 or newer. Install the Flutter SDK and Android Studio, then generate any missing Flutter platform build files with `flutter create --platforms=android,ios .` from this directory. Keep the crash-related permissions and service declarations in `android/app/src/main/AndroidManifest.xml` when generating or updating platform scaffolding.

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Use an HTTPS API URL for a physical Android device. The cleartext exception in the Android network security config is limited to `10.0.2.2` and `localhost` for local emulator development. The API must be reachable from the device.

## Crash Monitoring

Android starts a foreground service with a persistent notification, wake-lock support, boot restart, motion sensors, and location speed sampling. Runtime permission prompts cover foreground/background location, activity recognition, notifications, and battery-optimization exemption. Full-screen crash notifications require Android's full-screen-intent permission and may be restricted by device policy.

The countdown cancellation path creates a deferred `DETECTED` accident, then calls `PATCH /api/accidents/:id/cancel` if the driver is safe. Expiry obtains the best current location (falling back to last-known location) and calls the API escalation endpoint. Failed reports, cancellation, and escalation requests are queued in SQLite and retried when connectivity returns.

Crash thresholds are demo defaults (Low 5G, Med 4G, High 3G after gravity subtraction); validate them on-device before any real-world use. Notifications use the device's default alarm/notification sound and vibration pattern.