---
description: Add a new screen to an existing feature — typed go_router route, BlocProvider-wired page, stateless view, and a widget test.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

# /add-screen $ARGUMENTS

Add a new screen. `$ARGUMENTS` is `<feature>/<ScreenName>` (e.g. `order/OrderDetail`).

## Before writing any code

Read `.claude/skills/widgets-and-screens/SKILL.md`. Check the feature's existing screens to match local conventions.

## Files to create

```
lib/feature/<feature>/presentation/pages/<screen>_page.dart     # BlocProvider + listeners
lib/feature/<feature>/presentation/widgets/<screen>_view.dart   # stateless
lib/routing/routes/<screen>_route.dart                          # @TypedGoRoute
test/feature/<feature>/presentation/<screen>_view_test.dart
```

## Page wrapper pattern

```dart
class <Screen>Page extends StatelessWidget {
  const <Screen>Page({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => BlocProvider<<Screen>Bloc>(
        create: (_) => sl<<Screen>Bloc>()..add(<Screen>Event.load(id)),
        child: BlocListener<<Screen>Bloc, <Screen>State>(
          listenWhen: (p, c) => p.effect != c.effect && c.effect != null,
          listener: (context, state) { /* toast, nav */ },
          child: const <Screen>View(),
        ),
      );
}
```

## View pattern

- Stateless.
- Takes the state slice it needs as props OR uses `BlocBuilder`/`BlocSelector` locally.
- Callbacks go out; events come back in from the page.

## Routing

Add the typed route; update the parent route's `routes:` list if it's nested.

```dart
@TypedGoRoute<<Screen>Route>(path: '/order/:id')
class <Screen>Route extends GoRouteData {
  const <Screen>Route({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, GoRouterState state) => <Screen>Page(id: id);
}
```

## Test

Widget test pumps the `<Screen>View` with a fake bloc. Cover at least: loading renders spinner, success renders content, error renders the error UI.

## Checklist

- [ ] Route is typed (`GoRouteData` subclass + `@TypedGoRoute`).
- [ ] No `sl<...>()` inside `build`.
- [ ] `const` constructors wherever possible.
- [ ] Widget test covers loading / success / error.
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` if you added a new typed route.
