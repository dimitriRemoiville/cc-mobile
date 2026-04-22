---
name: flutter-app-skeleton
description: Canonical blueprint for scaffolding a brand-new Flutter app in this project's style — full pubspec, folder layout, base classes (Failure, DioFactory, GetIt container, AppDatabase), analysis_options, flavor setup, and test helpers. Load when initializing a new Flutter app or when you need the authoritative starting files. The `/init-flutter-app` command drives this skill end to end.
---

# Flutter app skeleton

This skill is the source of truth for what a new Flutter app looks like on day 0. Every file below is meant to be written as-is (with the placeholders swapped). Nothing in here is stack-agnostic — it's opinionated for this project's conventions (`flutter_bloc` + `get_it` + `dio` + `drift` + `fpdart` + `freezed` + typed `go_router`).

Use via `/init-flutter-app`. The command handles the user interaction; this skill holds the templates.

## Companion files (load conditionally)

The core templates (pubspec, folder layout, `core/`, `routing/`, `shared/`, tests) live in this file. Flag-conditional extensions live in sibling files — load only the ones matching the user's flags to keep context focused:

- `INCLUDE_DRIFT` → [_drift.md](./_drift.md)
- `INCLUDE_FIREBASE` → [_firebase.md](./_firebase.md)
- `INCLUDE_NOTIFICATIONS` → [_notifications.md](./_notifications.md)
- `INCLUDE_WORKMANAGER` → [_workmanager.md](./_workmanager.md)

## Placeholders

Throughout the templates, replace:

- `{{APP_NAME}}` — the Dart package name, `snake_case` (e.g., `my_app`).
- `{{APP_CLASS}}` — `UpperCamelCase` version used in class names (e.g., `MyApp`).
- `{{ORG_DOMAIN}}` — reverse-domain organization identifier (e.g., `com.example.app`).
- `{{APP_DISPLAY_NAME}}` — human-readable app name (e.g., `My App`).
- Feature flags (`INCLUDE_DRIFT`, `INCLUDE_FIREBASE`, `INCLUDE_NOTIFICATIONS`, `INCLUDE_WORKMANAGER`) — include/exclude the corresponding blocks.

## Execution order

Do these in order. Skip the optional steps the user opted out of.

1. **Run `flutter create`** to get platform folders.
2. **Seed `pubspec.yaml`** with the non-dependency shell, then use `dart pub add` for every dependency. Do not hardcode versions from this skill — `pub add` picks the current compatible version at runtime. Verify against the floor-constraint table after.
3. **Overwrite `analysis_options.yaml`**.
4. **Write `build.yaml`** for codegen config.
5. **Delete `lib/main.dart`** and the default `test/widget_test.dart`.
6. **Write the `lib/` tree** (templates follow).
7. **Write `test/helpers/`**.
8. **Run `flutter pub get`**.
9. **Run `dart run build_runner build --delete-conflicting-outputs`**.
10. **Run `dart analyze --fatal-infos --fatal-warnings`** and fix anything the skeleton tripped.
11. **Report the manual Android / iOS flavor steps** — those require Xcode + Gradle edits the CLI shouldn't do automatically.

## Step 1 — `flutter create`

```bash
flutter create --org {{ORG_DOMAIN}} --project-name {{APP_NAME}} --platforms=android,ios .
```

(If the directory already has files, run in an empty subfolder or accept the overwrite warnings.)

## Step 2 — `pubspec.yaml`

**Do not hardcode versions in this skill.** Versions drift; a skill pinned to "latest as of today" is a ticking clock. Instead:

1. Write the non-dependency scaffold of `pubspec.yaml` (name, description, environment, flutter assets block — shown below).
2. Add dependencies with `dart pub add` — the resolver picks the current compatible version, and pub writes a real caret constraint into the final `pubspec.yaml`. That pin lives in the generated project, not in this skill.
3. Verify the resolved versions respect the **floor constraints** listed below. If any resolves lower than the floor (e.g. the user has an older Flutter pinning them back), stop and surface it to the user.

### 2a — Seed `pubspec.yaml`

Overwrite the `flutter create` output with this shell (no dependencies yet):

```yaml
name: {{APP_NAME}}
description: "{{APP_DISPLAY_NAME}}"
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ">=3.8.0 <4.0.0"
  flutter: ">=3.35.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/images/
    - assets/icons/
```

### 2b — Add dependencies

Run these `dart pub add` commands from the project root. Group them as shown so the final `pubspec.yaml` groups read well; pub preserves insertion order.

```bash
# Core Flutter extras
dart pub add cupertino_icons intl

# State management
dart pub add flutter_bloc bloc_concurrency formz

# DI
dart pub add get_it

# Routing (typed)
dart pub add go_router

# Functional / error model
dart pub add fpdart

# Immutability & codegen annotations
dart pub add freezed_annotation json_annotation

# Networking
dart pub add dio connectivity_plus

# Storage (secure + simple)
dart pub add flutter_secure_storage shared_preferences path_provider path

# Utilities
dart pub add logging package_info_plus device_info_plus uuid crypto url_launcher clock
```

Optional blocks — run only if the flag is on:

```bash
# INCLUDE_DRIFT — note: sqlcipher_flutter_libs provides BOTH SQLite + encryption.
#                 Do NOT also add sqlite3_flutter_libs; it will conflict.
dart pub add drift sqlite3 sqlcipher_flutter_libs

# INCLUDE_FIREBASE
dart pub add firebase_core firebase_analytics firebase_crashlytics firebase_remote_config

# INCLUDE_NOTIFICATIONS
dart pub add flutter_local_notifications timezone flutter_timezone app_settings

# INCLUDE_WORKMANAGER
dart pub add workmanager
```

Dev dependencies:

```bash
# Testing
dart pub add --dev bloc_test mocktail fake_async

# Goldens — pick one at init time
dart pub add --dev alchemist          # default
# or:
dart pub add --dev golden_toolkit

# Codegen
dart pub add --dev build_runner freezed json_serializable go_router_builder

# INCLUDE_DRIFT
dart pub add --dev drift_dev

# Lints
dart pub add --dev flutter_lints
```

### 2c — Floor constraints (verify after `pub get`)

These are engineering requirements, not snapshots. If `flutter pub deps` reports anything below a floor, stop and ask. Bump a floor only when the reasoning that drove it changes.

| Package | Floor | Why |
|---|---|---|
| `go_router` | `>=14.0.0` | Typed routes (`@TypedGoRoute`) landed in 14.x. Earlier versions only have string routes. |
| `freezed` / `freezed_annotation` | `>=3.0.0` | Dart 3 sealed-class unions + exhaustive `switch`. |
| `fpdart` | `>=1.0.0` | API stabilized at 1.0; pre-1.0 has breaking renames. |
| `flutter_bloc` | `>=9.0.0` | Current major; aligns with `bloc_concurrency` and modern `BlocSelector`. |
| `get_it` | `>=8.0.0` | Scope API used by test helpers. |
| `drift` / `drift_dev` | `>=2.20.0` | Pair: major match between drift and drift_dev is required. |
| `mocktail` | `>=1.0.0` | Null-safe API. |
| `intl` | pin to whatever Flutter resolves | Never `any`. Flutter bundles an `intl` constraint; use what resolves. |
| `sqlcipher_flutter_libs` | `>=0.6.0` | Ships combined SQLite + encryption. If the user already has `sqlite3_flutter_libs`, hard fail — they conflict. |

If `dart pub add` refuses a package because of SDK constraints, do not work around it by lowering the floor. Surface the resolver output and stop.

### 2d — Rule of thumb

**Do not edit `pubspec.yaml` by hand inside this skill.** `dart pub add` is the source of truth for versions. If you must hand-edit (e.g. to change a group comment), do it after `pub add` has written the entries.

Do remind the user: never use `intl: any`. If they later add `intl` themselves, use a caret constraint.

## Step 3 — `analysis_options.yaml`

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/l10n/**"
    - "**/*.gr.dart"
  errors:
    # Promote a few patterns to errors — catch at CI time.
    unused_import: error
    dead_code: error
    missing_required_param: error
    missing_return: error

linter:
  rules:
    always_use_package_imports: true
    avoid_print: true
    cancel_subscriptions: true
    close_sinks: true
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    prefer_final_locals: true
    omit_local_variable_types: true
    unawaited_futures: true
    use_build_context_synchronously: true
    require_trailing_commas: true
    sort_pub_dependencies: false   # we group by purpose, not alphabetically
```

## Step 4 — `build.yaml`

```yaml
targets:
  $default:
    builders:
      freezed:
        options:
          copy_with: true
          equal: true
      json_serializable:
        options:
          explicit_to_json: true
          create_factory: true
          create_to_json: true
      go_router_builder:
        generate_for:
          - lib/routing/**.dart
```

## Step 5 — `lib/` tree

Create the folder skeleton first (empty folders get a `.gitkeep`), then write the seed files below.

```
lib/
├── main_dev.dart
├── main_prod.dart
├── app_initializer.dart
├── {{APP_NAME}}_app.dart
├── core/
│   ├── auth/
│   │   └── auth_token_provider.dart
│   ├── config/
│   │   ├── app_config.dart
│   │   └── flavor.dart
│   ├── database/                          # only if INCLUDE_DRIFT
│   │   ├── app_database.dart
│   │   └── executor.dart
│   ├── di/
│   │   └── container.dart
│   ├── errors/
│   │   └── failures.dart
│   ├── logging/
│   │   ├── i_logger.dart
│   │   └── app_logger.dart
│   ├── network/
│   │   ├── api_call_error_handling.dart
│   │   └── dio_factory.dart
│   └── notifications/                     # only if INCLUDE_NOTIFICATIONS
│       └── .gitkeep
├── feature/
│   └── .gitkeep
├── l10n/
│   └── app_en.arb
├── routing/
│   └── app_router.dart
└── shared/
    ├── theme/
    │   ├── app_theme.dart
    │   └── app_spacing.dart
    └── widgets/
        └── .gitkeep
```

### `lib/main_dev.dart`

```dart
import 'package:flutter/material.dart';
import 'package:{{APP_NAME}}/app_initializer.dart';
import 'package:{{APP_NAME}}/core/config/flavor.dart';
import 'package:{{APP_NAME}}/{{APP_NAME}}_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitializer.initialize(flavor: Flavor.dev);
  runApp(const {{APP_CLASS}}App());
}
```

### `lib/main_prod.dart`

```dart
import 'package:flutter/material.dart';
import 'package:{{APP_NAME}}/app_initializer.dart';
import 'package:{{APP_NAME}}/core/config/flavor.dart';
import 'package:{{APP_NAME}}/{{APP_NAME}}_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitializer.initialize(flavor: Flavor.prod);
  runApp(const {{APP_CLASS}}App());
}
```

### `lib/app_initializer.dart`

```dart
import 'package:{{APP_NAME}}/core/config/app_config.dart';
import 'package:{{APP_NAME}}/core/config/flavor.dart';
import 'package:{{APP_NAME}}/core/di/container.dart';

abstract final class AppInitializer {
  static Future<void> initialize({required Flavor flavor}) async {
    AppConfig.init(flavor: flavor);
    // INCLUDE_FIREBASE:
    //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    //   FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    await initializeDependencies(flavor: flavor);
  }
}
```

### `lib/{{APP_NAME}}_app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:{{APP_NAME}}/core/di/container.dart';
import 'package:{{APP_NAME}}/routing/app_router.dart';
import 'package:{{APP_NAME}}/shared/theme/app_theme.dart';

class {{APP_CLASS}}App extends StatelessWidget {
  const {{APP_CLASS}}App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: '{{APP_DISPLAY_NAME}}',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: sl<AppRouter>().config,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
      );
}
```

### `lib/core/config/flavor.dart`

```dart
enum Flavor { dev, prod }

extension FlavorX on Flavor {
  bool get isDev => this == Flavor.dev;
  bool get isProd => this == Flavor.prod;
}
```

### `lib/core/config/app_config.dart`

```dart
import 'package:{{APP_NAME}}/core/config/flavor.dart';

class AppConfig {
  AppConfig._({required this.flavor, required this.apiBaseUrl, required this.isDebug});

  final Flavor flavor;
  final String apiBaseUrl;
  final bool isDebug;

  static AppConfig? _instance;
  static AppConfig get current {
    final value = _instance;
    if (value == null) throw StateError('AppConfig not initialized. Call AppConfig.init() first.');
    return value;
  }

  static void init({required Flavor flavor}) {
    _instance = AppConfig._(
      flavor: flavor,
      apiBaseUrl: switch (flavor) {
        Flavor.dev => const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://dev.api.example.com'),
        Flavor.prod => const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.example.com'),
      },
      isDebug: flavor.isDev,
    );
  }
}
```

### `lib/core/errors/failures.dart`

```dart
sealed class Failure {
  const Failure({required this.message, this.code, this.rootCause, this.stackTrace});
  final String message;
  final String? code;
  final Object? rootCause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType($message${code == null ? '' : ', code: $code'})';
}

final class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Network error', super.rootCause, super.stackTrace});
}

final class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code, super.rootCause, super.stackTrace});
}

final class AuthFailure extends Failure {
  const AuthFailure({super.message = 'Unauthorized', super.code, super.rootCause, super.stackTrace});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({required super.message, super.code});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, this.fields = const {}})
      : super(code: 'validation');
  final Map<String, String> fields;
}

final class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.rootCause, super.stackTrace});
}

final class CancelledFailure extends Failure {
  const CancelledFailure() : super(message: 'Cancelled');
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure({required this.retryAfter}) : super(message: 'Rate limited');
  final Duration retryAfter;
}

final class UnknownFailure extends Failure {
  const UnknownFailure({required super.message, super.rootCause, super.stackTrace});
}
```

### `lib/core/auth/auth_token_provider.dart`

```dart
abstract interface class AuthTokenProvider {
  Future<String?> currentToken();
  Future<String?> refresh();
  Future<void> clear();
  Stream<AuthFailureReason> get failureStream;
}

enum AuthFailureReason { refreshFailed, revokedToken, unknown }
```

### `lib/core/logging/i_logger.dart`

```dart
abstract interface class ILogger {
  void debug(String message, {Object? error, StackTrace? stackTrace});
  void info(String message, {Object? error, StackTrace? stackTrace});
  void warn(String message, {Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace});
}
```

### `lib/core/logging/app_logger.dart`

```dart
import 'package:logging/logging.dart';
import 'package:{{APP_NAME}}/core/logging/i_logger.dart';

class AppLogger implements ILogger {
  AppLogger({String name = '{{APP_NAME}}'}) : _log = Logger(name) {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print('${record.time.toIso8601String()} ${record.level.name} ${record.loggerName}: ${record.message}');
    });
  }

  final Logger _log;

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      _log.fine(message, error, stackTrace);

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) =>
      _log.info(message, error, stackTrace);

  @override
  void warn(String message, {Object? error, StackTrace? stackTrace}) =>
      _log.warning(message, error, stackTrace);

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log.severe(message, error, stackTrace);
}
```

### `lib/core/network/api_call_error_handling.dart`

```dart
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:{{APP_NAME}}/core/errors/failures.dart';

mixin ApiCallErrorHandling {
  Future<Either<Failure, T>> handleApiCall<R, T>(
    Future<R> Function() call, {
    required T Function(R dto) map,
  }) async {
    try {
      final response = await call();
      return Right(map(response));
    } on DioException catch (e, s) {
      return Left(_mapDioException(e, s));
    } catch (e, s) {
      return Left(UnknownFailure(message: e.toString(), rootCause: e, stackTrace: s));
    }
  }

  Failure _mapDioException(DioException e, StackTrace s) => switch (e.type) {
        DioExceptionType.cancel => const CancelledFailure(),
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.connectionError =>
          NetworkFailure(rootCause: e, stackTrace: s),
        DioExceptionType.badCertificate =>
          NetworkFailure(message: 'SSL error', rootCause: e, stackTrace: s),
        DioExceptionType.badResponse => _mapStatus(e, s),
        DioExceptionType.unknown =>
          UnknownFailure(message: e.message ?? 'unknown', rootCause: e, stackTrace: s),
      };

  Failure _mapStatus(DioException e, StackTrace s) {
    final status = e.response?.statusCode ?? 0;
    final body = e.response?.data;
    return switch (status) {
      400 => ValidationFailure(message: _message(body) ?? 'Bad request'),
      401 || 403 => AuthFailure(code: '$status', rootCause: e, stackTrace: s),
      404 => NotFoundFailure(message: _message(body) ?? 'Not found', code: '404'),
      409 => ServerFailure(message: _message(body) ?? 'Conflict', code: '409', rootCause: e, stackTrace: s),
      429 => RateLimitFailure(retryAfter: _retryAfter(e.response?.headers)),
      _ when status >= 500 =>
        ServerFailure(message: _message(body) ?? 'Server error', code: '$status', rootCause: e, stackTrace: s),
      _ => UnknownFailure(message: _message(body) ?? 'Unknown error', rootCause: e, stackTrace: s),
    };
  }

  String? _message(Object? body) {
    if (body is Map<String, Object?>) {
      final msg = body['message'] ?? body['error'];
      return msg is String ? msg : null;
    }
    return null;
  }

  Duration _retryAfter(Headers? headers) {
    final raw = headers?.value('retry-after');
    final seconds = int.tryParse(raw ?? '');
    return Duration(seconds: seconds ?? 60);
  }
}
```

### `lib/core/network/dio_factory.dart`

```dart
import 'package:dio/dio.dart';
import 'package:{{APP_NAME}}/core/auth/auth_token_provider.dart';
import 'package:{{APP_NAME}}/core/config/app_config.dart';
import 'package:{{APP_NAME}}/core/logging/i_logger.dart';

class DioFactory {
  const DioFactory({
    required this.config,
    required this.authTokenProvider,
    required this.logger,
  });

  final AppConfig config;
  final AuthTokenProvider authTokenProvider;
  final ILogger logger;

  Dio create() {
    final dio = Dio(BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await authTokenProvider.currentToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401) {
          final refreshed = await authTokenProvider.refresh();
          if (refreshed != null) {
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $refreshed';
            try {
              final retry = await dio.fetch<Object?>(opts);
              return handler.resolve(retry);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
        }
        handler.next(err);
      },
    ));

    if (config.isDebug) {
      dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    }
    return dio;
  }
}
```

### `lib/core/di/container.dart`

```dart
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:{{APP_NAME}}/core/config/app_config.dart';
import 'package:{{APP_NAME}}/core/config/flavor.dart';
import 'package:{{APP_NAME}}/core/logging/app_logger.dart';
import 'package:{{APP_NAME}}/core/logging/i_logger.dart';
import 'package:{{APP_NAME}}/core/network/dio_factory.dart';
import 'package:{{APP_NAME}}/routing/app_router.dart';

final GetIt sl = GetIt.instance;

Future<void> initializeDependencies({required Flavor flavor}) async {
  // Core
  sl.registerLazySingleton<ILogger>(AppLogger.new);
  sl.registerLazySingleton<AppConfig>(() => AppConfig.current);
  // sl.registerLazySingleton<AuthTokenProvider>(() => SecureStorageAuthTokenProvider(...));
  // sl.registerLazySingleton<Dio>(() => DioFactory(config: sl(), authTokenProvider: sl(), logger: sl()).create());

  // Routing
  sl.registerLazySingleton<AppRouter>(AppRouter.new);

  // Features — add each feature's register<Feature>Module(sl) here.
}
```

### `lib/core/database/app_database.dart`  *(INCLUDE_DRIFT)*

```dart
import 'package:drift/drift.dart';
import 'package:{{APP_NAME}}/core/database/executor.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );
}
```

### `lib/core/database/executor.dart`  *(INCLUDE_DRIFT)*

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection({required String passphrase}) => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, '{{APP_NAME}}.db'));
      return NativeDatabase.createInBackground(
        file,
        setup: (raw) => raw.execute("PRAGMA key = '$passphrase';"),
      );
    });
```

### `lib/routing/app_router.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

part 'app_router.g.dart';

class AppRouter {
  GoRouter get config => _router;

  final _router = GoRouter(
    initialLocation: const SplashRoute().location,
    routes: $appRoutes,
    debugLogDiagnostics: true,
  );
}

@TypedGoRoute<SplashRoute>(path: '/')
class SplashRoute extends GoRouteData {
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const _SplashScreen();
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
```

### `lib/shared/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      );
}
```

### `lib/shared/theme/app_spacing.dart`

```dart
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
```

### `lib/l10n/app_en.arb`

```json
{
  "@@locale": "en",
  "appTitle": "{{APP_DISPLAY_NAME}}"
}
```

Add `l10n.yaml` at the project root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

## Step 6 — `test/` scaffold

Delete `test/widget_test.dart` from `flutter create`.

### `test/helpers/pump_app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

extension PumpAppExt on WidgetTester {
  Future<void> pumpApp({
    required Widget child,
    ThemeData? theme,
    Locale locale = const Locale('en'),
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: theme ?? ThemeData.light(useMaterial3: true),
        locale: locale,
        home: child,
      ),
    );
  }
}
```

### `test/helpers/fakes.dart`

```dart
import 'package:{{APP_NAME}}/core/logging/i_logger.dart';

class NoopLogger implements ILogger {
  @override void debug(String message, {Object? error, StackTrace? stackTrace}) {}
  @override void info(String message, {Object? error, StackTrace? stackTrace}) {}
  @override void warn(String message, {Object? error, StackTrace? stackTrace}) {}
  @override void error(String message, {Object? error, StackTrace? stackTrace}) {}
}
```

### `test/smoke_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke', () {
    expect(1 + 1, 2);
  });
}
```

(Real tests go under `test/core/`, `test/feature/<feature>/`, `test/shared/`.)

## Step 7 — Flavors (Android + iOS)

**These require editing project files the CLI shouldn't touch automatically.** Report the needed steps to the user — don't try to perform them.

### Android (`android/app/build.gradle.kts`)

```kotlin
android {
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "{{APP_DISPLAY_NAME}} Dev")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "{{APP_DISPLAY_NAME}}")
        }
    }
}
```

Move `google-services.json` (if Firebase) to `android/app/src/dev/` and `android/app/src/prod/`.

### iOS

1. In Xcode (`ios/Runner.xcworkspace`), duplicate the `Runner` scheme → `Runner-dev` and `Runner-prod`.
2. Under Build Settings, create `DEV` and `PROD` configurations (duplicate `Debug`/`Release`).
3. Set `PRODUCT_BUNDLE_IDENTIFIER` per config (`.dev` suffix on dev).
4. Drop `GoogleService-Info.plist` files per flavor into `ios/Flutter/dev/` and `ios/Flutter/prod/`, then select in the build phase.

Run with:

```bash
flutter run --flavor dev  --target lib/main_dev.dart
flutter run --flavor prod --target lib/main_prod.dart
```

## Step 8 — Codegen

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos --fatal-warnings
flutter test
```

## Post-init checklist (show the user)

- [ ] `flutter pub get` succeeded.
- [ ] `dart run build_runner build --delete-conflicting-outputs` generated `app_router.g.dart` (and `app_database.g.dart` if INCLUDE_DRIFT).
- [ ] `dart analyze` is clean.
- [ ] `flutter run --flavor dev --target lib/main_dev.dart` boots to the splash.
- [ ] Android flavors set up in `android/app/build.gradle.kts`.
- [ ] iOS schemes + configurations set up in Xcode.
- [ ] (If INCLUDE_FIREBASE) `flutterfire configure` run for both flavors.
- [ ] Git initialized: `git init && git add . && git commit -m 'initial scaffold'`.

## Hard rules for this skill

- **Never** include `sqlite3_flutter_libs` alongside `sqlcipher_flutter_libs`. They conflict.
- **Never** include `mockito`. `mocktail` only.
- **Never** include `dartz`. `fpdart` only.
- **Never** include `Equatable`. Use `freezed` for value types / unions.
- **Never** use string-based `go_router` route constants when `go_router_builder` + typed routes are available.
- **Never** set `GetIt.I.allowReassignment = true` in templates. Use scopes in tests.
- **Never** leave `intl: any` — pin a version.
