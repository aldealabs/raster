# MetalPetal 1.26.0

This is an Aldea-maintained compatibility continuation of upstream MetalPetal 1.25.2, not a release from the upstream maintainers.

SwiftPM dependency URL: `https://github.com/aldealabs/raster.git`. This tag exports the existing `MetalPetal` product and module; Raster development begins at version 2.0.0.

## Changes

- Added opt-in `headroom` support to blending, multilayer compositing, and CLAHE.
- Exposed filter graph connections so downstream packages can build custom chaining helpers, based on work from the [Preternatural fork](https://github.com/preternatural-fork/MetalPetal) ([MetalPetal/MetalPetal#270](https://github.com/MetalPetal/MetalPetal/issues/270)).
- Fixed Core Image rendering so explicit output regions and extents are handled correctly ([MetalPetal/MetalPetal#132](https://github.com/MetalPetal/MetalPetal/issues/132), [MetalPetal/MetalPetal#314](https://github.com/MetalPetal/MetalPetal/pull/314), [MetalPetal/MetalPetal#384](https://github.com/MetalPetal/MetalPetal/issues/384)).
- Made `MTIImage(contentsOf:)` unambiguous while preserving its compatibility overload.
- Fixed the CI-image-backed `UIImage` fallback so it preserves scale and orientation.
- Added namespaced SwiftPM Metal headers plus clean downstream Swift, Objective-C, and Metal-header consumers ([MetalPetal/MetalPetal#366](https://github.com/MetalPetal/MetalPetal/issues/366)).
- Removed historical CocoaPods packaging and support; SwiftPM is the sole supported package manager.

## Compatibility

`headroom == 1` preserves the default SDR behavior, and legacy two-argument custom blend formulas remain supported.

New feature development continues in Raster 2.x.
