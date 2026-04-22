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

In `main_dev.dart` / `main_prod.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await App.run(flavor: Flavor.dev);
}
```

## Interfaces

Crashlytics / Analytics / Remote Config **must not leak into domain or presentation**. Wrap each in a thin interface under `lib/domain/services/`:

```dart
abstract class ICrashReporter {
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false});
  void setUserId(String? id);
}

abstract class IAnalytics {
  Future<void> logEvent(String name, Map<String, Object?> params);
}

abstract class IRemoteConfig {
  bool boolean(String key, {bool fallback = false});
  String string(String key, {String fallback = ''});
}
```

Implement under `lib/data/firebase/`. Register in `get_it` behind the interfaces.

## App Check

Register App Check after `Firebase.initializeApp` — in dev use the debug provider, in prod use Play Integrity on Android and DeviceCheck/AppAttest on iOS. Without App Check, Crashlytics and RTDB are trivially spoofable.

## Hard nos

- No Firebase imports in `lib/domain/` or `lib/presentation/`.
- No `flutterfire configure` inside the scaffold run.
- No shipped build without App Check enabled.
- No committing `google-services.json` / `GoogleService-Info.plist` to public repos (root `.gitignore` covers this).
