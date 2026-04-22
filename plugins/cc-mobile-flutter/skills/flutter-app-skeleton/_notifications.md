# Flutter app skeleton — local notifications companion

Load this when `INCLUDE_NOTIFICATIONS` is set.

## pubspec adds

```bash
dart pub add flutter_local_notifications timezone
```

## Init in `app_initializer.dart`

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Future<void> initNotifications() async {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
}
```

## Permissions

Do not request notification permissions on app start. Ask in-context, after the user enables a feature that uses notifications. Store the decision in DataStore-equivalent (or secure storage).

On iOS 13+, request via `DarwinFlutterLocalNotificationsPlugin`'s `requestPermissions()`.
On Android 13+, request `POST_NOTIFICATIONS` via `Permission.notification.request()` (add `permission_handler` if not already present).

## Channels (Android)

Create channels up-front for each logical category (not per-message):

```dart
const reminders = AndroidNotificationChannel(
  'reminders',
  'Reminders',
  description: 'Scheduled reminders for pending actions',
  importance: Importance.high,
);
```

Register all channels in `initNotifications` before scheduling any notification.

## Interface

Wrap the plugin behind a domain interface:

```dart
abstract class INotificationScheduler {
  Future<void> scheduleReminder({required int id, required DateTime when, required String title, required String body});
  Future<void> cancel(int id);
}
```

## Hard nos

- No permission prompts on cold start.
- No plugin imports outside `lib/data/notifications/`.
- No ephemeral / per-message channels.
- No calling the plugin in background isolates without first re-initializing the timezone database.
