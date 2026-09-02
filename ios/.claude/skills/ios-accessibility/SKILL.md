---
name: ios-accessibility
description: Accessibility conventions for this iOS project — the per-screen baseline, the grouping rule for custom rows, Dynamic Type at accessibility sizes, Reduce Motion, and the VoiceOver review pass. Load when auditing a screen for accessibility, adding semantic annotations, or reviewing a SwiftUI view for VoiceOver and tap-target correctness.
---

# iOS accessibility (project delta)

For the API surface — every `accessibility*` modifier, trait, rotor, and custom action — read [Apple's SwiftUI accessibility documentation](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals) and the [Accessibility section of the HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility). This file documents what this project requires and what its reviews actually flag.

## When this applies

SwiftUI accessibility (`accessibilityLabel`, traits, `accessibilityElement`). On an existing app:

- **UIKit** → the principles transfer exactly (labels, traits, 44pt targets, Dynamic Type) but the API is `isAccessibilityElement`, `accessibilityLabel`, `accessibilityTraits`, `UIFontMetrics`. Don't push SwiftUI modifiers.
- **Mixed UIKit + SwiftUI** → apply this skill to the SwiftUI surfaces only.

## The baseline

Before a screen is considered done:

1. **Every interactive element has a label** that says what it does, not what it looks like.
2. **Traits match the actual role** — `.isButton`, `.isHeader`, `.isToggle`. SwiftUI infers these for its own controls; a `VStack` with `.onTapGesture` gets nothing and must be told.
3. **Tap targets are ≥ 44×44pt.** `.frame(minWidth: 44, minHeight: 44)` plus `.contentShape(Rectangle())` on tight layouts — without `contentShape`, the padding isn't tappable.
4. **Text uses semantic styles** (`.body`, `.headline`, `.footnote`), never a fixed `.system(size:)`.

## Labels

```swift
Image(systemName: "trash")
    .accessibilityLabel("Delete")
    .accessibilityHint("Removes the selected order")

Image("splash-illustration").accessibilityHidden(true)   // decorative
```

- **No "image of" or "button that"** in a label — VoiceOver announces the trait already.
- **Hints describe the consequence**, not the gesture. "Removes the selected order", not "Double-tap to delete".
- **`.accessibilityLabel("")` is never the answer** for a decorative element; `.accessibilityHidden(true)` is.

## Grouping custom rows

The single most common finding in this codebase. VoiceOver reads each subview separately, so a card built from an image, two labels, and an icon becomes four stops with no indication it's one tappable thing:

```swift
HStack { /* artwork, title, duration, play icon */ }
    .contentShape(Rectangle())
    .onTapGesture { play(episode) }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Play \(episode.title), \(episode.duration)")
    .accessibilityAddTraits(.isButton)
```

`.combine` merges children and keeps their labels joined; `.ignore` takes full control and requires you to supply the whole label. Custom-drawn controls need `.ignore` plus an explicit trait.

## Dynamic Type

**Layouts must survive `.accessibility3` and above** — that's where fixed-height rows clip and side-by-side layouts collide. Preview it rather than guessing:

```swift
#Preview("AX3") {
    OrderRow(order: .sample).environment(\.dynamicTypeSize, .accessibility3)
}
```

- No fixed-width or fixed-height container around scalable text. `.frame(maxWidth: .infinity, alignment: .leading)` and let it wrap.
- Custom fonts opt into scaling via `UIFontMetrics` or `Font.custom(_:size:relativeTo:)` — plain `Font.custom(_:size:)` does not scale.
- Consider `@Environment(\.dynamicTypeSize)` to switch an `HStack` to a `VStack` past `.accessibility1`, rather than letting it squeeze.

## Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// ...
.animation(reduceMotion ? nil : .spring(), value: isOpen)
```

Parallax, auto-play, and looping animations are **disabled**, not shortened, when Reduce Motion is on.

## Colour

Never encode status in colour alone — pair it with an icon, a label, or a shape. Body text meets 4.5:1 contrast, large text 3:1. `@Environment(\.colorSchemeContrast)` for the increased-contrast palette.

## The VoiceOver pass

Run this on every new screen; it takes about a minute:

1. Swipe right through the screen — every interactive element gets focus, in reading order, with no orphaned fragments.
2. Double-tap each one — the intended action fires.
3. Rotor by heading — the screen's structure is navigable.
4. After a navigation, the announcement is the new screen's title, not a stale fragment.
5. Errors and async results are announced — a visible `Text` the user never hears about is not an error message.

## Hard nos

- **No `.accessibilityHidden(true)` on anything interactive.**
- **No fixed `.font(.system(size:))`** outside design-token generation.
- **No colour-only status.**
- **No untested largest Dynamic Type size** on a new screen.
- **No custom control without an explicit trait** — a tappable `VStack` that VoiceOver calls out as plain text is unusable.
