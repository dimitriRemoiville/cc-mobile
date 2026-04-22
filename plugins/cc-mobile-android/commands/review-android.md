---
description: Run an Android-focused review of recent changes using the android-reviewer subagent.
argument-hint: [--since=<ref>]
allowed-tools: Read, Grep, Glob, Bash, Task
---

Run a review on the current branch's changes.

1. Determine what changed. Default: `git diff --name-only main...HEAD`. If `--since=<ref>` is provided, use that as the base.
2. Delegate to the `android-reviewer` subagent via the Task tool. Hand it the list of changed files and ask for the standard review format (Summary / Must fix / Should fix / Nits / Tests).
3. If the reviewer flags layer-boundary or architectural issues, follow up with the `android-architect` subagent for a second opinion.
4. If the reviewer flags missing tests, offer to invoke the `android-tester` subagent to write them.
5. Surface the review to the user as the final output. Do not rewrite code yourself in this command — that's the user's call once they see the review.
