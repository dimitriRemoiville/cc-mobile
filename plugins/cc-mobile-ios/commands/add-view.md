---
description: Add a single SwiftUI view with its @Observable view model, ViewState, and #Preview — no backend plumbing.
argument-hint: <ViewName> [feature-folder]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
---

Add a new SwiftUI view named **$ARGUMENTS**. This command is for presentation-layer-only work — no new repository, use case, or API.

Steps:

1. Read `${CLAUDE_PLUGIN_ROOT}/skills/swiftui-views/SKILL.md` and the nearest existing view in the project for structural reference.
2. Figure out where the view belongs. If the user named a feature folder, put it there; otherwise ask.
3. Create these files:

   ```
   <Feature>/Presentation/<View>/
   ├── <View>ViewState.swift     # enum or struct describing states
   ├── <View>ViewModel.swift     # @Observable @MainActor final class
   ├── <View>View.swift          # Root (container) + stateless view + #Preview(s)
   ```

4. Register a factory method on `DIContainer` (`makeXxxViewModel()`). Update or create with a reasonable default stub if no use cases are needed yet — leave a `TODO` if you do.
5. Wire the route into `AppRoute` and the nav graph.
6. At least one `#Preview` for the stateless view — use sample data. If there are multiple distinct states, add a `#Preview` per state.
7. Verify: `xcodebuild build -scheme App -destination 'platform=iOS Simulator,name=iPhone 15'`.
8. Report the files you created, the route you added, and any next steps.

Consider delegating the UI work to the `ios-ui-engineer` subagent via the Task tool, especially for non-trivial views.
