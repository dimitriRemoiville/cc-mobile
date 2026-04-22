---
name: ios-accessibility
description: iOS accessibility patterns — accessibility labels/hints/values/traits, Dynamic Type, VoiceOver, Reduce Motion, high contrast, RTL mirroring. Load whenever adding or reviewing a SwiftUI screen.
---

# iOS accessibility

## Baseline

Every interactive element has:
- **Accessibility label** — a short noun-phrase or verb-phrase (not decorative text).
- **Trait** reflecting the actual role (`.isButton`, `.isHeader`, `.isToggle`).
- **Tap area** of at least **44pt x 44pt** (`.contentShape(Rectangle())` + `.frame(minWidth: 44, minHeight: 44)` on tight layouts).

SwiftUI infers a lot of this, but custom controls don't.

## Labels

```swift
Image(systemName: "trash")
    .accessibilityLabel("Delete")
    .accessibilityHint("Removes the selected order")

// Decorative image:
Image("splash-illustration").accessibilityHidden(true)
```

- No "image of" / "button that" in labels. VoiceOver already announces the trait.
- Hints describe the action's consequence, not how to trigger it.

## Grouping

VoiceOver reads each subview separately by default. For cards / rows, collapse:

```swift
HStack {
    AsyncImage(url: episode.artwork)
    VStack { Text(episode.title); Text(episode.duration) }
    Image(systemName: "play.fill").accessibilityHidden(true)
}
.contentShape(Rectangle())
.onTapGesture { play(episode) }
.accessibilityElement(children: .combine)
.accessibilityLabel("Play \(episode.title), \(episode.duration)")
.accessibilityAddTraits(.isButton)
```

- `.accessibilityElement(children: .combine)` merges children, keeping their labels joined.
- `.accessibilityElement(children: .ignore)` takes full control; you supply one label.

## Dynamic Type

- Prefer system text styles (`.body`, `.headline`, `.footnote`) via `Font.body`.
- Layouts must survive `accessibilityExtraExtraExtraLarge`. Test in previews:

```swift
#Preview("Large font") {
    OrderRow(order: .sample)
        .environment(\.dynamicTypeSize, .accessibility3)
}
```

- Custom fonts: `Font.custom("YourFont", size: UIFontMetrics.default.scaledValue(for: 16))` to opt into scaling, or better, use `Font.system(.body, design: .rounded)`.
- No fixed-width containers around scalable text. Use `.frame(maxWidth: .infinity, alignment: .leading)` and let the text wrap.

## Reduce Motion

Honor the user preference for screen transitions:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

.animation(reduceMotion ? nil : .spring(), value: isOpen)
```

For parallax / auto-play / looping animations: pause or disable entirely when `reduceMotion` is on.

## High contrast & color

```swift
@Environment(\.colorSchemeContrast) private var contrast

Text(status.label)
    .foregroundStyle(contrast == .increased ? Color.accessibleAccent : Color.accent)
```

- Always pair color with another channel (icon, label, shape). Color-only status is invisible to many users.
- Validate text contrast at WCAG AA (4.5:1 for body, 3:1 for large). Xcode's preview contrast inspector is your friend.

## VoiceOver testing checklist

1. Swipe right through every screen; every interactive element receives focus in the expected reading order.
2. Double-tap any element; the right action fires.
3. Rotor gestures (headings, landmarks) work on screens with a clear heading hierarchy.
4. Announcements after navigation are the screen's title + first meaningful element.

For UI tests:

```swift
let row = app.cells.element(matching: .init(format: "label CONTAINS[c] %@", "Order #1"))
row.tap()
XCTAssertTrue(app.navigationBars["Order #1"].exists)
```

## RTL mirroring

- Use `.leading` / `.trailing` in alignment & edges, never `.left` / `.right`.
- For images that encode direction (arrows, chevrons), use SF Symbols (auto-mirrored) or specify `.flipsForRightToLeftLayoutDirection(true)`.
- Preview mirrored layouts:

```swift
#Preview { OrderRow(order: .sample).environment(\.layoutDirection, .rightToLeft) }
```

## Announcements

For form-validation or async errors:

```swift
UIAccessibility.post(notification: .announcement, argument: "Card declined. Check your billing details.")
```

Or put the error in a visible `Text` with `.accessibilityAddTraits(.updatesFrequently)` so VoiceOver re-reads.

## Hard nos

- No `.accessibilityHidden(true)` on something with interactive behavior.
- No hard-coded `.font(.system(size: 17))` outside design-system token generation.
- No relying on color alone for status (green/red without icons or labels).
- No `.accessibilityLabel("")` — use `.accessibilityHidden(true)`.
- No skipping Dynamic Type testing at the largest size.
