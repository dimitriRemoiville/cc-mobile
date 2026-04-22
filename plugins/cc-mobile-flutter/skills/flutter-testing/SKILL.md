---
name: flutter-testing
description: Testing patterns for this Flutter project — unit, bloc (`bloc_test`), widget, and golden tests using `mocktail`, no `mockito`. Covers fakes, stubs, pumping a view stand-alone, GetIt scopes, and `fakeAsync`.
---

# Flutter testing

## Stack

- `flutter_test` — built-in harness.
- `bloc_test` — state-sequence assertions.
- `mocktail` — typed mocks. **No `mockito`** in new code.
- `alchemist` or `golden_toolkit` — goldens (pick one per project).

## Layout

```
test/
├── helpers/
│   ├── pump_app.dart       # wraps a widget with Theme + Localizations + GoRouter
│   ├── fakes.dart          # FakeBlocBase, FakeAuthRepository, NoopLogger, ...
│   ├── fixtures/           # .json fixture files
│   └── builders/           # userBuilder(), activityBuilder()
├── core/
├── feature/
│   └── <feature>/
│       ├── bloc/<name>_bloc_test.dart
│       ├── data/<name>_repository_impl_test.dart
│       └── presentation/<name>_view_test.dart
└── goldens/
    └── <component>/<variant>.png
```

## pump_app helper

```dart
// test/helpers/pump_app.dart
extension PumpAppExt on WidgetTester {
  Future<void> pumpApp({
    required Widget child,
    ThemeData? theme,
    Locale locale = const Locale('en'),
    NavigatorObserver? navigatorObserver,
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: theme ?? ThemeData.light(useMaterial3: true),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [if (navigatorObserver != null) navigatorObserver],
        home: child,
      ),
    );
  }
}
```

## Unit tests

Plain Dart tests — use `test` + assertions on values. No Flutter binding.

```dart
test('OrderId.parse accepts digits', () {
  expect(OrderId.parse('42').raw, '42');
  expect(() => OrderId.parse('abc'), throwsFormatException);
});
```

## Bloc tests

```dart
class _FakeSearchRepository implements SearchRepository {
  Either<Failure, List<Result>> nextResult = const Right(<Result>[]);
  final calls = <String>[];

  @override
  Future<Either<Failure, List<Result>>> search(String query) async {
    calls.add(query);
    return nextResult;
  }
}

void main() {
  late _FakeSearchRepository repo;
  setUp(() => repo = _FakeSearchRepository());

  blocTest<SearchBloc, SearchState>(
    'emits loading then success for a valid query',
    build: () => SearchBloc(repo: repo..nextResult = const Right([Result('coffee')])),
    act: (b) => b.add(const SearchEvent.queryChanged('cof')),
    expect: () => const [
      SearchState.loading(),
      SearchState.success([Result('coffee')]),
    ],
  );

  blocTest<SearchBloc, SearchState>(
    'maps failure to error state',
    build: () => SearchBloc(repo: repo..nextResult = Left(const NetworkFailure())),
    act: (b) => b.add(const SearchEvent.queryChanged('cof')),
    expect: () => const [
      SearchState.loading(),
      SearchState.error(NetworkFailure()),
    ],
  );

  blocTest<SearchBloc, SearchState>(
    'droppable ignores a second submit while in flight',
    build: () => SubmitBloc(repo: repo),
    act: (b) => b
      ..add(const Submit())
      ..add(const Submit()),
    wait: const Duration(milliseconds: 10),
    expect: () => const [SubmitState.submitting(), SubmitState.success()],  // only one cycle
  );
}
```

Rules:
- Prefer **hand-rolled fakes** to mocks. They're more readable; they record calls cleanly.
- `expect:` with concrete values. `anything` / `isA` only when the test is about structure, not content.
- Assert **what the user would see**, not internal state.

## Repository tests

```dart
class _MockActivitiesApi extends Mock implements ActivitiesApi {}

void main() {
  late _MockActivitiesApi api;
  late ActivityRepositoryImpl repo;

  setUp(() {
    api = _MockActivitiesApi();
    repo = ActivityRepositoryImpl(api: api, dao: InMemoryActivityDao(), logger: NoopLogger());
    registerFallbackValue(ActivityGetRequestOptions());  // mocktail requirement for custom types
  });

  test('maps 404 to NotFoundFailure', () async {
    when(() => api.getActivity(id: any(named: 'id')))
        .thenThrow(DioException(
          requestOptions: RequestOptions(),
          response: Response(requestOptions: RequestOptions(), statusCode: 404, data: {'message': 'nope'}),
          type: DioExceptionType.badResponse,
        ));

    final result = await repo.getActivity('missing');

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<NotFoundFailure>()),
      (_) => fail('expected failure'),
    );
  });
}
```

- Mock the **generated API class**, not `Dio`. (Tests of the DioFactory itself are the exception.)
- Cover: 2xx happy path, 401 → `AuthFailure`, 404 → `NotFoundFailure`, 5xx → `ServerFailure`, `DioExceptionType.cancel` → `CancelledFailure`, timeout → `NetworkFailure`.

## Widget tests

```dart
testWidgets('tapping sign in dispatches SubmitPressed', (tester) async {
  final fakeBloc = FakeAuthBloc(seed: const AuthState.unauthenticated());

  await tester.pumpApp(
    child: BlocProvider<AuthBloc>.value(value: fakeBloc, child: const SignInView()),
  );
  await tester.enterText(find.byKey(const Key('email_field')), 'a@b.co');
  await tester.enterText(find.byKey(const Key('password_field')), 'hunter2');
  await tester.tap(find.byKey(const Key('submit_button')));
  await tester.pump();

  expect(fakeBloc.events, contains(isA<SubmitPressed>()));
});
```

- **Fake the bloc, don't mock it.** A `FakeAuthBloc` class that extends your bloc's interface (or `implements StateStreamable<AuthState>`) is easier to reason about.
- Drive via gestures + text entry. Don't reach into bloc state to drive the UI.
- `pumpAndSettle` only when you know exactly what's animating. Otherwise `pump()` with explicit durations.

## Golden tests

- One golden per meaningful variant (default, pressed, disabled, error, dark).
- Force a stable theme + `TextScaler.linear(1.0)`. Host MediaQuery must not leak in.
- Run goldens on Linux CI only. Locally: `flutter test --update-goldens` when design intentionally changes.
- Skip goldens for animation-heavy widgets — they'll flap.

Example with `alchemist`:

```dart
goldenTest('SignInButton variants', fileName: 'sign_in_button',
  builder: () => GoldenTestGroup(children: [
    GoldenTestScenario(name: 'enabled',  child: const SignInButton()),
    GoldenTestScenario(name: 'disabled', child: const SignInButton(enabled: false)),
  ]),
);
```

## GetIt in tests

Default: don't touch GetIt. Construct the class under test with fakes. When you must:

```dart
setUp(() {
  GetIt.I.pushNewScope(scopeName: 'test');
  GetIt.I.registerLazySingleton<ILogger>(() => NoopLogger());
});
tearDown(() => GetIt.I.popScope());
```

**Never `allowReassignment = true`.**

## Time

Tests that depend on time:
- Inject a `Clock` (from `package:clock`) instead of `DateTime.now()`.
- Use `fakeAsync { ... }` from `package:fake_async` to advance virtual time without blocking.
- For rrule / scheduling code, write one test per boundary (start, end, exclusion) rather than trying to cover the whole rule set.

## Don'ts

- `Future.delayed` to "wait for the bloc". Use `wait:` in `blocTest` or `pump` with an explicit duration.
- Real network / real filesystem / real Firebase. Mock at the seam.
- Single test that asserts six things. Split.
- `when(...).thenAnswer(...).thenAnswer(...)` queues with no explanation. Name the behavior with a comment.
- Mocking `Bloc` directly. Fake it.
