---
name: android-accessibility
description: A11y patterns for this Android project — semantics modifiers, content descriptions, tap target sizing, TalkBack verification, dynamic type, RTL. Load whenever adding or reviewing a Compose screen.
---

# Android accessibility

## The baseline

Every interactive element has:
- A stable tap target of at least **48dp x 48dp** (`Modifier.minimumInteractiveComponentSize()` on anything that isn't already a Material widget).
- A meaningful accessible name. `Text` content is already announced. Icons and custom controls need `contentDescription` or `Modifier.semantics`.
- A correct role so TalkBack reads "button" / "switch" / "checked" instead of announcing the visual only.

## Content descriptions

- Decorative icons: `contentDescription = null`.
- Functional icons: a **short, action-verb** description — "Delete", not "A trash can icon".
- Images with informational value: description of meaning, not of pixels.

```kotlin
Icon(
    imageVector = Icons.Default.Delete,
    contentDescription = stringResource(R.string.cd_delete_order),
)
```

## Semantics composition

Group visually-separate composables into one accessible node when they represent one concept:

```kotlin
Row(
    modifier = Modifier
        .clickable(onClick = onPlayClick)
        .semantics(mergeDescendants = true) {
            contentDescription = "Play episode: ${episode.title}"
            role = Role.Button
        },
) {
    AsyncImage(...)
    Column { Text(episode.title); Text(episode.duration) }
    Icon(Icons.Default.PlayArrow, contentDescription = null) // merged above
}
```

- `mergeDescendants = true` collapses children into a single accessible node.
- `clearAndSetSemantics { ... }` replaces everything underneath — use sparingly.

## Custom semantics

Custom gestures / non-standard widgets must expose state and actions:

```kotlin
Modifier.semantics {
    role = Role.Checkbox
    stateDescription = if (checked) "selected" else "not selected"
    toggleableState = if (checked) ToggleableState.On else ToggleableState.Off
    onClick(label = "Toggle") { onToggle(); true }
}
```

Drag handles, sliders, and carousels benefit from `CustomAccessibilityAction` so TalkBack users can trigger the same affordance without the gesture.

## Text sizing

- Always use `sp` for text — system font scaling respects it.
- Layouts must survive `fontScale = 2.0`. Test it in previews:

```kotlin
@Preview(fontScale = 2.0f, showBackground = true)
@Composable fun OrderRow_LargeFont() = AppTheme { OrderRow(previewOrder) }
```

- No fixed-height text containers. Use `wrapContentHeight()` or intrinsic sizing.
- Truncation is fine; hiding content is not. Either show the full text after scaling or provide an expand affordance.

## RTL

- Use `start`/`end` modifiers, never `left`/`right`. Compose Modifier API is RTL-aware by default for `padding(start = ...)`, `PaddingValues`, `Arrangement`, `Alignment`.
- For custom drawing, check `LocalLayoutDirection.current` and mirror.
- Preview with `LocalLayoutDirection` forced to RTL:

```kotlin
@Preview @Composable fun OrderRow_Rtl() =
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        AppTheme { OrderRow(previewOrder) }
    }
```

## Focus and traversal order

Reading order matches declaration order. If visuals diverge from semantic order, set `semantics { traversalIndex = 1f }` on the out-of-order node.

## Live announcements

For non-visual feedback (error banner, form validation), announce:

```kotlin
LaunchedEffect(errorMessage) {
    errorMessage?.let { view.announceForAccessibility(it) }
}
```

Or use `Modifier.semantics { liveRegion = LiveRegionMode.Polite }` on the visible error text.

## TalkBack testing checklist

1. **Navigate** — swipe right through every screen; every interactive element gets focus in a sensible order.
2. **Activate** — double-tap any element; the right action fires.
3. **Custom actions** — three-finger down-then-right to open menu on custom widgets.
4. **Focus after navigation** — landing on a new screen should announce the title and focus the first meaningful element.

Automated checks complement (don't replace) this. Use Espresso `AccessibilityChecks.enable()` on UI tests.

## Hard nos

- No `contentDescription = ""` to suppress. Use `null` for decorative images.
- No `Modifier.clickable` on a `Text` without a role — TalkBack will call it "double-tap to activate" instead of "button".
- No hard-coded `dp` text.
- No `Modifier.size(32.dp)` around a touch target — wrap in `minimumInteractiveComponentSize()` or size at 48dp minimum.
- No testing only on the default font scale.
