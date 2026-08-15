# Changelog

## 2.0.0

MetalPetal continues as Raster. This release changes the Swift package, library product, Swift module, Objective-C umbrella, and Metal header namespace to `Raster`; the established `MTI*` public API remains intact.

- Renamed the framework, examples, tests, and package structure from MetalPetal to Raster.
- Added compatibility aliases for public support types whose names included MetalPetal, with deprecation guidance toward their Raster names.
- Preserved the HDR headroom, public filter-graph chaining, Core Image extent handling, image-loading fixes, and SwiftPM integration work from MetalPetal 1.26.0.
- Added dedicated user and maintainer documentation, including the complete [migration guide](https://raster.aldealabs.com/docs/start/migrating-from-metalpetal/).
- Published the documentation as a static Cloudflare Pages site with a repeatable `bun run deploy` workflow.

Applications moving from MetalPetal should update the selected package product and replace `import MetalPetal` with `import Raster`. Objective-C and Metal includes move from the `MetalPetal` namespace to `Raster`; the `MTI*` symbols themselves do not change.

## 1.26.0

This is an Aldea-maintained compatibility continuation of upstream MetalPetal 1.25.2, not a release from the upstream maintainers.

- Added opt-in `headroom` support to blending, multilayer compositing, and CLAHE.
- Exposed filter graph connections so downstream packages can build custom chaining helpers, based on work from the [Preternatural fork](https://github.com/preternatural-fork/MetalPetal) ([MetalPetal/MetalPetal#270](https://github.com/MetalPetal/MetalPetal/issues/270)).
- Fixed Core Image rendering so explicit output regions and extents are handled correctly ([MetalPetal/MetalPetal#132](https://github.com/MetalPetal/MetalPetal/issues/132), [MetalPetal/MetalPetal#314](https://github.com/MetalPetal/MetalPetal/pull/314), [MetalPetal/MetalPetal#384](https://github.com/MetalPetal/MetalPetal/issues/384)).
- Made `MTIImage(contentsOf:)` unambiguous while preserving its compatibility overload.
- Fixed the CI-image-backed `UIImage` fallback so it preserves scale and orientation.
- Added namespaced SwiftPM Metal headers plus clean downstream Swift, Objective-C, and Metal-header consumers ([MetalPetal/MetalPetal#366](https://github.com/MetalPetal/MetalPetal/issues/366)).
- Removed historical CocoaPods packaging and support; SwiftPM is the sole supported package manager.

`headroom == 1` preserves the default SDR behavior, and legacy two-argument custom blend formulas remain supported.

New feature development continues in Raster 2.x.
