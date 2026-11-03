# AiBox migration from Moonlight v1.55

Source (read-only): `alicelikeeat/moonIight-ios`, tag `v1.55`, commit
`2df6613a3ac191c85a28f66f551146640fa5b092`.

Destination: `alicelikeeat/aibox-ios-`, independent Swift/iOS app.

## Inspected source files

- `Features/RPG/Domain/World/WorldState.swift`: 256 x 256 world,
  32 x 32 chunks, top-down and side-view data mixed together.
- `Features/RPG/Domain/World/RPGMapEditor.swift`: camera and visible
  chunk calculation; SpriteKit-specific coordinates require adaptation.
- `Features/RPG/Media/RPGMediaPolicy.swift`: selection and visibility
  priorities; schedule currently caps output at two unique media IDs.
- `Features/RPG/Persistence/RPGWorldCodec.swift`: schema-aware JSON
  persistence with 16 MiB cap.

## Migration boundaries

1. Keep Moonlight untouched; never copy unrelated feed/social screens.
2. AiBox core models must not import SpriteKit, SwiftUI, or RealityKit.
3. Support top-down / oblique 3D only; do not port side-view physics.
4. Preserve original Moonlight saves: import via an explicit adapter later,
   never reinterpret them as AiBox schema v1.
5. Separate asset identity, object identity, and independent playback state.
6. Verify third-party licenses and binary assets before copying.
7. The initial Swift package is a foundation, **not yet an iOS app**.

## Next work

- Audit the complete dependency graph for Moonlight sandbox.
- Build a versioned Moonlight v1.55 import adapter with fixtures.
- Add terrain, elevation, footprint, collision, and chunk streaming.
- Create a standalone SwiftUI app target and 3D renderer proof of concept.
- Test on macOS CI and on actual iPhone hardware.

No runtime, rendering, or iPhone performance claims are made at this stage.

## 2026-11-03 dependency audit and app slice

Read-only inspection of the v1.55 tag included the above files plus:
`WorldState.swift`, `RPGEditDraft.swift`, `RPGGIFTiming.swift`,
`RPGMediaCoordinator.swift`, `RPGMediaCatalog.swift`, `RPGWorldDiskStore.swift`,
`Moonlight-iOS.xcodeproj/project.pbxproj`, root inventory and migration checklist.
The root checklist also covers feed/social features; those are outside AiBox.

| Source area | Dependencies / coupling | AiBox decision |
| --- | --- | --- |
| WorldState, schema 8 | Foundation; combat, story, behaviors, generator identity, top-down + side-view state | Keep independent schema 1; no silent reinterpretation/import |
| Map editor camera | CoreGraphics; L10n, world geometry; SpriteKit camera units | Adapt bounds to grid units and RealityKit orbit/pan/zoom |
| Draft confirmation | World editing, generator, protected terrain, combat, inventory, clipboard | Use existing pure preview/confirm transaction; replace one cell atomically |
| Media bindings | WorldState, generator, projection rules, edit history, story references | Store per-object references, give each runtime player independent ownership |
| Media scheduling | Foundation/CoreGraphics, role/visibility/selection/distance | Adapt selected-first two-decoder budget; role and hysteresis migration pending |
| GIF timing | Foundation only | Adapt `RPGGIFTiming` to public `GIFTiming`; boundary tests added |
| Media catalog/runtime | MediaStore / MediaEntry and app media library; Apple playback/UI APIs | Replace library resolver with sandbox-local imports; no feed/social dependency |
| World codec | Foundation; schema defaults reference combat/story/behavior models | Keep bounded, validated AiBox JSON; do not copy schema migrations |
| Disk store | Foundation; world IDs, revision ordering, backup and active index | Keep single-world atomic store for MVP; backup/recovery migration remains |

The inspected Xcode project declares no remote Swift package references or
package products, and the root inventory contains no Podfile, Cartfile or
LICENSE file. This is evidence about declared project dependencies, not a full
license certification of every bundled asset or repository file. No Moonlight
binary assets, fonts or third-party source have been copied. GIF timing is
adapted from the user-designated Moonlight source; redistribution licensing
still needs an explicit project license/ownership record before public release.

This is a scoped sandbox-path audit, not a claim that every original app file
has been audited. Missing work includes generated terrain/import fixtures,
backup recovery, full media runtime policy, asset packaging and large-world
chunk streaming. AiBox app and CI use only Apple frameworks, the local package
and Python's standard library project generator.
