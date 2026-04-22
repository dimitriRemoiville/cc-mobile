# Flutter app skeleton — workmanager companion

Load this when `INCLUDE_WORKMANAGER` is set. Background work on Flutter is fiddly — this companion sticks to the bare minimum that reliably runs on both platforms.

## pubspec adds

```bash
dart pub add workmanager
```

## Top-level callback

Workmanager requires a top-level (not-in-a-class) callback dispatcher. Put it in `lib/core/background/background_tasks.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    switch (task) {
      case 'sync-pending':
        // Resolve dependencies via a small composition root tailored to the
        // background isolate (get_it's main container is not available here).
        return true;
      default:
        return false;
    }
  });
}
```

## Init in `main_<flavor>.dart`

```dart
import 'package:workmanager/workmanager.dart';
import 'core/background/background_tasks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await App.run(flavor: Flavor.dev);
}
```

## Scheduling

```dart
await Workmanager().registerPeriodicTask(
  'sync-pending',
  'sync-pending',
  frequency: const Duration(hours: 1),
  constraints: Constraints(networkType: NetworkType.connected),
);
```

## iOS caveats

- Background fetch on iOS is opportunistic — **never** rely on it for correctness.
- Add "Background fetch" capability to the iOS target.
- Background tasks on iOS run for < 30 seconds. If your work exceeds that, redesign.

## Android caveats

- Android 13+ requires `POST_NOTIFICATIONS` if the task surfaces notifications.
- Doze mode can defer periodic tasks by up to a few hours — don't guarantee frequency to users.

## Background isolate + dependencies

The background isolate has its own `get_it` container. Either:

1. Re-register a minimal container in `callbackDispatcher` (do this — it's explicit), or
2. Use a pure function with all dependencies passed as parameters (does not work once you need a DB).

## Hard nos

- No UI calls (`Navigator.of`, `MediaQuery`) in `callbackDispatcher`.
- No relying on `get_it.instance` from the main isolate inside the callback.
- No business-critical periodic tasks on iOS — they will not run when you think they will.
- No writing to the same drift instance from two isolates without `drift/isolate.dart`.
