---
name: flutter-accessibility
description: Flutter accessibility patterns — `Semantics`, screen reader labels/hints, tap target sizing, text scaling with `MediaQuery.textScaler`, `ExcludeSemantics`, `MergeSemantics`, `Focus`, RTL mirroring. Load whenever adding or reviewing a screen / widget.
---

# Flutter accessibility

## Baseline

Every interactive widget has:
- A meaningful accessible name (for screen readers: TalkBack / VoiceOver).
- A correct role/trait so the reader announces "button" / "checkbox", not just the text.
- A tap target of at least **48dp x 48dp**.
- A layout that survives `MediaQuery.of(context).textScaler.scale(1)` up to `2.0`.

## Built-in widgets

Material widgets (`ElevatedButton`, `Checkbox`, `Switch`, `ListTile`) already expose the right semantics. Custom widgets require a `Semantics` wrapper or modifications.

## Semantics

```dart
Semantics(
  label: 'Delete order',
  hint: 'Removes this order from your list',
  button: true,
  excludeSemantics: true, // replace the underlying children's semantics
  child: IconButton(icon: const Icon(Icons.delete), onPressed: _onDelete),
)
```

Typical traits:
- `button: true`, `header: true`, `link: true`, `checked: true/false`, `selected`, `enabled`.
- `liveRegion: true` for live-updating status text (assistive tech re-reads on change).

## Merge / exclude

A card with image + title + subtitle + chevron should be **one** accessible node, not four:

```dart
Semantics(
  label: 'Order #${order.number}, \$${(order.cents/100).toStringAsFixed(2)}, status ${order.status.label}',
  button: true,
  child: MergeSemantics(
    child: InkWell(
      onTap: () => _openDetail(order),
      child: Row(children: [
        OrderThumbnail(url: order.thumbnailUrl),
        Expanded(child: Column(...)),
        const Icon(Icons.chevron_right),
      ]),
    ),
  ),
)
```

- `MergeSemantics` collapses descendants into one node, preserving their labels.
- `ExcludeSemantics` hides a subtree from the reader — useful for purely decorative icons that a parent already describes.

## Tap targets

`Material` + `InkWell` have a default splash area that might be smaller than your visual. Enforce minimums:

```dart
ConstrainedBox(
  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  child: InkWell(onTap: _onTap, child: const Icon(Icons.info_outline)),
)
```

`IconButton` already enforces 48dp. Don't shrink with `padding: EdgeInsets.zero` unless you also add a larger splash container.

## Text scaling

Use the `textScaler` API introduced in Flutter 3.16+:

```dart
final scaler = MediaQuery.of(context).textScaler;
Text('Title', style: Theme.of(context).textTheme.titleLarge);  // scales automatically
```

Or override in a preview/test:

```dart
MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
  child: child,
)
```

- Never hard-code font sizes outside the theme.
- Containers holding text should use `IntrinsicHeight` or `min`/`max` constraints — not fixed heights.
- Truncation > hiding. If a label gets cut, offer an expand or navigate-to-detail.

## RTL

- Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end` in flex.
- Icons that encode direction (arrows, chevrons) mirror via `Transform.flip` or ask the design system for a mirrored asset. Material's `Icons.arrow_back` does the right thing when wrapped in `BackButton`.
- Test mirrored: `Directionality(textDirection: TextDirection.rtl, child: ...)`.

## Focus and keyboard

Tab order, focus handling, Enter-to-submit:

```dart
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: Column(children: [
    FocusTraversalOrder(order: const NumericFocusOrder(1), child: _nameField),
    FocusTraversalOrder(order: const NumericFocusOrder(2), child: _emailField),
    FocusTraversalOrder(order: const NumericFocusOrder(3), child: _submitButton),
  ]),
)
```

Web/desktop support requires this; mobile still benefits for external keyboards.

## Live announcements

```dart
SemanticsService.announce('Card declined. Check your billing details.', TextDirection.ltr);
```

Or put the error in a visible `Text` with `Semantics(liveRegion: true, child: ...)`.

## Automated checks in tests

```dart
testWidgets('order row has accessible label', (tester) async {
  await tester.pumpWidget(wrap(OrderRow(order: sampleOrder)));
  expect(
    find.bySemanticsLabel(RegExp('Order #')),
    findsOneWidget,
  );
});
```

`flutter_test` has `meetsGuideline(androidTapTargetGuideline)`, `iOSTapTargetGuideline`, `textContrastGuideline`, `labeledTapTargetGuideline`. Put at least one per new screen test.

## Manual TalkBack / VoiceOver pass

1. Swipe right through every element on a screen; focus order matches reading order.
2. Double-tap each interactive element; the right action fires.
3. Rotate through headings (TalkBack: "headings" rotor; VoiceOver: "heading" rotor). Every screen should have at least one heading.
4. Test at the largest text scale (2.0) — nothing clips, nothing overflows without scroll.

## Hard nos

- No `Text('')` to silence a label. Use `Semantics(container: true, label: ..., child: ...)`.
- No icon-only buttons without `tooltip:` or a `Semantics(label: ...)` wrapper.
- No gesture-only interactions without an accessible alternative.
- No colours for status without a second channel (icon, label, shape).
- No skipping RTL preview for screens that take user content.
