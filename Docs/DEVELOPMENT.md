# AiBox development

The repository currently contains a renderer-independent Swift Package named
`AiBoxCore`. It is not yet an Xcode iOS app project or an installable IPA.

## Run core tests

```sh
swift test
```

GitHub Actions runs the package tests on a macOS runner. The CI workflow does
not build an iOS app or validate RealityKit / Metal.

## Editor contract

- Every edit first produces a preview without modifying the live world.
- A commit requires the expected preview and rechecks it.
- A failed batch leaves the live world unchanged.
- Undo/redo operate on complete snapshots (prototype only; large-world
  history will require delta-based storage before production).
- No physics or multi-cell footprint validation is implemented yet.

## Migration provenance

The implementation is a fresh, independent core inspired by the documented
Moonlight v1.55 world and editor behavior. The original source has not yet been
copied into this repository. The Moonlight repository remains unchanged.
