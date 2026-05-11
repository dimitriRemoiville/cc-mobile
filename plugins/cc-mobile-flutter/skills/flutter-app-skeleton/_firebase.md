# Flutter app skeleton — Firebase companion

Load this when `INCLUDE_FIREBASE` is set. See also the more detailed [firebase-services](../firebase-services/SKILL.md) skill for runtime patterns; this companion is about the *initial scaffold*.

## pubspec adds

```bash
dart pub add firebase_core firebase_crashlytics firebase_analytics firebase_remote_config firebase_app_check
dart pub add --dev firebase_core_platform_interface
```

## Manual prerequisite

Before any code will build, the user has to run once (per Firebase project):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<project_id>
```

This emits `lib/firebase_options.dart` and drops the platform config files. The scaffold command **does not** run `flutterfire configure` — it requires interactive auth and a real Firebase project.

## Flavor config

Per flavor, drop:
- `android/app/src/dev/google-services.json`
- `android/app/src/prod/google-services.json`
- `ios/config/dev/GoogleService-Info.plist`
- `ios/config/prod/GoogleService-Info.plist`

Pick the iOS plist per scheme via a build phase:

```sh
cp "${SRCROOT}/config/${CONFIGURATION}/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
```

On Android, the `com.google.gms.google-services` plugin picks the flavor automatically when the `google-services.json` lives under `app/src/<flavor>/`.

## Init wiring

In `main_dev.dart` / `main_prod.dart`, initialize Firebase **before** `AppInitializer.initialize` so the runtime Crashlytics handlers are in place by the time the rest of the app boots:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await AppInitializer.initialize(flavor: Flavor.dev);
  runApp(const {{APP_CLASS}}App());
}
```

## Analytics tracker — `lib/core/analytics/firebase_analytics_tracker.dart`

The Firebase implementation of the `IAnalyticsTracker` interface defined in the core skill. **It must be defensive against an uninitialized FirebaseApp**: the user may run the app before `flutterfire configure` produces `firebase_options.dart`, or before they drop `google-services.json` / `GoogleService-Info.plist` per flavor. Without the guard, the first call to `FirebaseAnalytics.instance` throws and the app crashes at startup.

The pattern: gate every public method on `Firebase.apps.isNotEmpty`, no-op silently otherwise. Once Firebase is wired up, the same impl starts emitting events without a code change.

```dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:{{APP_NAME}}/core/analytics/analytics_event.dart';
import 'package:{{APP_NAME}}/core/analytics/i_analytics_tracker.dart';

class FirebaseAnalyticsTracker implements IAnalyticsTracker {
  const FirebaseAnalyticsTracker();

  /// False until Firebase.initializeApp has succeeded. The app may launch
  /// before flutterfire configure has produced firebase_options.dart.
  bool get _isAvailable => Firebase.apps.isNotEmpty;

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;
  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  @override
  Future<void> track(AnalyticsEvent event) async {
    if (!_isAvailable) return;
    await _analytics.logEvent(name: event.name, parameters: _sanitize(event.params));
  }

  @override
  Future<void> setUserProperty(String key, String? value) async {
    if (!_isAvailable) return;
    await _analytics.setUserProperty(name: key, value: value);
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    if (!_isAvailable) return;
    await _analytics.setAnalyticsCollectionEnabled(enabled);
    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }

  /// Firebase only accepts num / String params (Bool is coerced to int).
  /// Anything exotic gets toString()'d; null entries are dropped.
  Map<String, Object> _sanitize(Map<String, Object?> params) {
    final out = <String, Object>{};
    for (final entry in params.entries) {
      final v = entry.value;
      if (v == null) continue;
      out[entry.key] = switch (v) {
        num n => n,
        String s => s,
        bool b => b ? 1 : 0,
        _ => v.toString(),
      };
    }
    return out;
  }
}
```

## DI swap (`lib/core/di/container.dart`)

Replace the default `NoopAnalyticsTracker` registration with the Firebase impl when `INCLUDE_FIREBASE` is on:

```dart
// Default (INCLUDE_FIREBASE=false):
sl.registerLazySingleton<IAnalyticsTracker>(NoopAnalyticsTracker.new);

// INCLUDE_FIREBASE=true — replace the line above with:
sl.registerLazySingleton<IAnalyticsTracker>(FirebaseAnalyticsTracker.new);
```

The interface contract is identical, so `AppInitializer` and every Cubit/Bloc that injects `IAnalyticsTracker` work without changes.

## Crash reporter / remote config interfaces (optional second iteration)

If you also want typed interfaces over Crashlytics + Remote Config (recommended once you have real flows that depend on them — see [firebase-services](../firebase-services/SKILL.md)), follow the same shape: `lib/core/crashlytics/i_crash_reporter.dart` + `lib/core/remote_config/i_remote_config.dart` with Firebase impls and Noop impls swapped via `container.dart` under the same flag. Don't import `firebase_*` anywhere outside `lib/core/<thing>/firebase_*_impl.dart`.

## App Check

Register App Check after `Firebase.initializeApp` — in dev use the debug provider, in prod use Play Integrity on Android and DeviceCheck/AppAttest on iOS. Without App Check, Crashlytics and RTDB are trivially spoofable.

## Hard nos

- No Firebase imports in `lib/domain/` or `lib/presentation/`.
- No `flutterfire configure` inside the scaffold run.
- No shipped build without App Check enabled.
- No committing `google-services.json` / `GoogleService-Info.plist` to public repos (root `.gitignore` covers this).
