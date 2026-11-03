# Validation evidence

## Reviewed foundation — 2026-11-03

- PR #1 head: `908a52171b02d904c59b30f7e05a5903bf0201bc`.
- GitHub Actions run: https://github.com/alicelikeeat/aibox-ios-/actions/runs/41601361298
- Job `swift-core` / `125800611124`: success, macOS 15.8.2 arm64,
  Apple Swift 6.1.2, seven XCTest methods executed with `swift test --parallel`.
- The trailing Swift Testing message “0 tests” is a separate runner; seven
  XCTest invocations are present above it. This is not evidence of zero XCTest.
- One warning: immutable `editor` declared `var` in the atomic-batch test;
  changed to `let` in this stage.
- No foundation iOS app build or real-device test existed.

## New app stage

- Local workspace has no Swift compiler or Xcode. Git clone failed because
  the configured terminal proxy was unreachable. Files were retrieved through
  the GitHub connector; a local snapshot is not a clone of remote history.
- Local checks: Python project generator runs; shared scheme XML parses;
  `git diff --check` passes. These do not establish Swift compilation.
- Added six core XCTest methods (collision, persistence, stale preview, GIF)
  and one iOS UI smoke test (preview/cancel/confirm/undo/redo/save/relaunch).
- Cloud compilation and simulator outcomes must be recorded from the new
  workflow run before treating this stage as validated.
- No physical iPhone or signed IPA validation has been performed.

### First app CI attempt

Commit `3fcc9a7`: core run 41602966422 succeeded (13 XCTest methods).
iOS run 41602966495 failed before UI execution: the generated app Debug target
requested both simulator architectures while the local package built only the
active arm64 architecture. Set Debug `ONLY_ACTIVE_ARCH = YES`, matching the
package, and rerun. No device archive was produced in this failed attempt.
Also bounded the file read before JSON decoding, and strengthened the UI test
with isolated storage and object-count assertions across preview, undo and reload.

### Validated app source

Commit `a92f797`: core run 41603273517 succeeded (13 XCTest methods).
iOS run https://github.com/alicelikeeat/aibox-ios-/actions/runs/41603273649
succeeded on Xcode 16.4: simulator app compiled, one editor smoke UI test passed
with zero failures, and the unsigned iOS device archive succeeded. The test
checks committed object counts through preview/cancel/confirm/undo/redo/save and
relaunch. This does not test media playback correctness or physical hardware.

The user subsequently authorized publication from main as an unsigned IPA.
The publication workflow repeats core tests, simulator build/UI test and device
archive, checks the app is unsigned, packages Payload/AiBox.app and publishes a
Chinese-noted GitHub prerelease only after these steps succeed. No installability
or iPhone test claim is made.
