# AiBox development

Open `AiBox.xcodeproj`, choose the shared `AiBox` scheme and an iOS 16+ simulator.
The app uses SwiftUI + non-AR RealityKit, with the local `AiBoxCore` package.
No third-party runtime packages or project generator dependencies are required.
Regenerate the checked-in project after adding Swift files:

```sh
python3 scripts/generate_project.py
swift test
xcodebuild test -project AiBox.xcodeproj -scheme AiBox \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Choose a simulator actually installed on your Mac; CI selects an available iPhone.

## Prototype interactions

- Tap ground to select a grid cell; one-finger drag orbits, two fingers pan,
  pinch zooms. Grid markers cover a window around the camera in a 256×256 world.
- Choose block, erase, image, GIF, video, text, number or SF Symbol icon.
- Import local files (up to 32 MiB); files are copied into Application Support.
- Preview changes the displayed candidate only. Confirm commits one transaction;
  cancel discards it. Undo/redo operate on committed snapshots, up to 50 entries.
- Save writes only the confirmed world atomically. Startup loads that save.
  An unreadable save blocks editing/saving so it cannot be silently overwritten.
- Play mode exposes a joystick with camera-relative movement and swept basic
  circle/cube collisions. No gravity, jumping, slopes or dynamic rigid bodies yet.
- Content is on the upper face of a 3D cube. GIFs use source timing and decode
  thumbnails up to 512 pixels. At most two animated cells run at once, selected
  cell first. Video players are independently owned and muted, with looping.
  Cells outside the animation budget show a still GIF or video placeholder.

## Current limits

- This is a prototype; no real-device, battery, accessibility or performance
  approval is implied by a successful simulator build.
- Animation budget is rebuilt on edit/selection. It does not yet suspend on
  camera movement, low-power mode or Reduce Motion, or implement full visibility
  hysteresis. Large maps still instantiate all objects; chunk streaming remains.
- GIFs are limited to 300 frames; invalid media shows a placeholder. Video lacks
  full asynchronous playback-error reporting. No remote URLs or external library.
- Media is stored beside the JSON and not embedded. No export/share package,
  garbage collection for cancelled imports or deletion of unused assets yet.
- No terrain painting, multi-cell selection, Moonlight-save import, playback
  property panel, move-object UI or advanced physics in this first app slice.
- Manual save only; player/camera positions and undo history are session-only.

## Cloud builds and IPA

`core-tests.yml` runs core XCTest on macOS. `ios-build.yml` builds and runs an
editor smoke UI test in an iPhone simulator, then creates an **unsigned device
archive** and uploads build logs, xcresult, archive and unsigned IPA artifacts.

An unsigned archive is not an installable IPA. Signed distribution still needs
an Apple developer team, matching bundle identifier, signing certificate and
provisioning profile (or configured Xcode Cloud signing). These are not present
in this workspace. No credentials are committed, no release is published and
main publication is now authorized by the user. A successful main push builds and publishes a prerelease with an unsigned IPA and Chinese release notes. The simulator smoke test does not replace iPhone testing.
