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
