//
//  File.swift
//  
//
//  Created by YuAo on 2021/2/2.
//

import XCTest
import MetalPetal
import MetalPetalTestHelpers
import MetalPetalObjectiveC.Extension
import VideoToolbox

final class RenderTests: XCTestCase {

    func testHDRBlendModeNames() {
        XCTAssertEqual(canonicalBlendModes().map(\.rawValue), [
            "Add", "Color", "ColorBurn", "ColorDodge", "Darken", "DarkerColor",
            "Difference", "Divide", "Exclusion", "HardLight", "HardMix", "Hue",
            "Lighten", "LighterColor", "LinearBurn", "LinearLight", "Luminosity",
            "Multiply", "Normal", "Overlay", "PinLight", "Saturation", "Screen",
            "SoftLight", "Subtract", "VividLight",
        ])
    }

    func testHDRHeadroomPublicDefaultsAndAssignment() {
        let blend = MTIBlendFilter(blendMode: .normal)
        XCTAssertEqual(blend.headroom, 1)
        blend.headroom = 4
        XCTAssertEqual(blend.headroom, 4)

        let objectiveCMultilayer = MTIMultilayerCompositingFilter()
        XCTAssertEqual(objectiveCMultilayer.headroom, 1)
        objectiveCMultilayer.headroom = 4
        XCTAssertEqual(objectiveCMultilayer.headroom, 4)

        let swiftMultilayer = MultilayerCompositingFilter()
        XCTAssertEqual(swiftMultilayer.headroom, 1)
        swiftMultilayer.headroom = 4
        XCTAssertEqual(swiftMultilayer.headroom, 4)

        let clahe = MTICLAHEFilter()
        XCTAssertEqual(clahe.headroom, 1)
        clahe.headroom = 4
        XCTAssertEqual(clahe.headroom, 4)
    }

    func testHDRBlendModesPreserveLegacyHeadroomOneGoldens() throws {
        let context = try makeContext()
        let backdrop = floatImage([SIMD4<Float>(2, 1.5, 0.25, 1)], width: 1, height: 1)
        let source = floatImage([SIMD4<Float>(0.5, 0.25, 0.75, 1)], width: 1, height: 1)
        let goldens = legacyBlendGoldens()
        XCTAssertEqual(goldens.count, 26)

        for mode in canonicalBlendModes() {
            let expected = try XCTUnwrap(goldens[mode.rawValue])
            for headroom in [Float?.none, Float?(1)] {
                for path in Task6BlendPath.allCases {
                    let actual = try renderBlendPixel(
                        mode: mode,
                        backdrop: backdrop,
                        source: source,
                        headroom: headroom,
                        path: path,
                        context: context
                    )
                    assertPixel(
                        actual,
                        equals: expected,
                        accuracy: 0.003,
                        "\(mode.rawValue) \(path.rawValue), headroom \(headroom.map { String($0) } ?? "implicit")"
                    )
                }
            }
        }
    }

    func testHDRBlendModesRemainFiniteAndMatchMultilayerAtFour() throws {
        let context = try makeContext()
        let backdrop = floatImage([SIMD4<Float>(2, 1.5, 0.25, 1)], width: 1, height: 1)
        let source = floatImage([SIMD4<Float>(0.5, 0.25, 0.75, 1)], width: 1, height: 1)

        for mode in canonicalBlendModes() {
            let individual = try renderBlendPixel(
                mode: mode,
                backdrop: backdrop,
                source: source,
                headroom: 4,
                path: .individual,
                context: context
            )
            let multilayer = try renderBlendPixel(
                mode: mode,
                backdrop: backdrop,
                source: source,
                headroom: 4,
                path: .multilayer,
                context: context
            )
            for (path, pixel) in [("individual", individual), ("multilayer", multilayer)] {
                for (component, value) in zip(["r", "g", "b"], [pixel.x, pixel.y, pixel.z]) {
                    XCTAssertTrue(value.isFinite, "\(mode.rawValue) \(path) \(component) is not finite")
                    XCTAssertTrue((-0.003...4.003).contains(value), "\(mode.rawValue) \(path) \(component) is \(value)")
                }
                XCTAssertTrue(pixel.w.isFinite, "\(mode.rawValue) \(path) alpha is not finite")
                XCTAssertTrue((-0.003...1.003).contains(pixel.w), "\(mode.rawValue) \(path) alpha is \(pixel.w)")
            }
            assertPixel(individual, equals: multilayer, accuracy: 0.003, "\(mode.rawValue) path parity")
        }
    }

    func testHDRIndependentBlendFormulaReferences() throws {
        let context = try makeContext()
        let backdrop = floatImage([SIMD4<Float>(2, 1.5, 0.25, 1)], width: 1, height: 1)
        let references: [(mode: MTIBlendMode, source: SIMD4<Float>, expected: SIMD4<Float>)] = [
            (.add, SIMD4<Float>(0.5, 0.25, 0.75, 1), SIMD4<Float>(2.5, 1.75, 1, 1)),
            (.multiply, SIMD4<Float>(1, 1, 1, 1), SIMD4<Float>(2, 1.5, 0.25, 1)),
            (.screen, SIMD4<Float>(0.5, 0.75, 0.75, 1), SIMD4<Float>(1.5, 1.125, 0.8125, 1)),
            (.colorDodge, SIMD4<Float>(0.5, 0.25, 0.75, 1), SIMD4<Float>(4, 2, 1, 1)),
            (.divide, SIMD4<Float>(0.5, 0.25, 0.75, 1), SIMD4<Float>(4, 4, 1.0 / 3.0, 1)),
            (.overlay, SIMD4<Float>(0.5, 0.25, 0.75, 1), SIMD4<Float>(2, 1.75, 0.375, 1)),
            (.lighten, SIMD4<Float>(0.5, 0.25, 0.75, 1), SIMD4<Float>(2, 1.5, 0.75, 1)),
            (.difference, SIMD4<Float>(0.5, 0.25, 0.75, 1), SIMD4<Float>(1.5, 1.25, 0.5, 1)),
            (.color, SIMD4<Float>(0.5, 0.25, 0.75, 1), SIMD4<Float>(1.62525, 1.37525, 1.87525, 1)),
        ]

        for reference in references {
            let source = floatImage([reference.source], width: 1, height: 1)
            for path in Task6BlendPath.allCases {
                let actual = try renderBlendPixel(
                    mode: reference.mode,
                    backdrop: backdrop,
                    source: source,
                    headroom: 4,
                    path: path,
                    context: context
                )
                assertPixel(actual, equals: reference.expected, accuracy: 0.003, "\(reference.mode.rawValue) \(path.rawValue)")
            }
        }
    }

    func testHDRTranslucentAddPreservesSourceOverAlphaAtFour() throws {
        let context = try makeContext()
        let backdrop = floatImage(
            [SIMD4<Float>(2, 0, 0, 0.25)],
            width: 1,
            height: 1,
            alphaType: .nonPremultiplied
        )
        let source = floatImage(
            [SIMD4<Float>(0.5, 0, 0, 0.5)],
            width: 1,
            height: 1,
            alphaType: .nonPremultiplied
        )
        let expected = SIMD4<Float>(1.2, 0, 0, 0.625)

        for path in Task6BlendPath.allCases {
            let actual = try renderBlendPixel(
                mode: .add,
                backdrop: backdrop,
                source: source,
                headroom: 4,
                path: path,
                outputAlphaType: .nonPremultiplied,
                destinationAlphaType: .nonPremultiplied,
                context: context
            )
            assertPixel(actual, equals: expected, accuracy: 0.003, "translucent Add \(path.rawValue)")
        }
    }

    func testHDROptimizerPreservesHeadroomBoundary() throws {
        let background = floatImage([SIMD4<Float>(0.8, 0.8, 0.8, 1)], width: 1, height: 1)
        let source = floatImage([SIMD4<Float>(0.5, 0.5, 0.5, 1)], width: 1, height: 1)

        let first = MultilayerCompositingFilter()
        first.inputBackgroundImage = background
        first.layers = [.init(content: source).blendMode(.add)]
        first.headroom = 1
        first.outputPixelFormat = .rgba16Float

        let second = MultilayerCompositingFilter()
        second.inputBackgroundImage = try XCTUnwrap(first.outputImage)
        second.layers = [.init(content: source).blendMode(.add)]
        second.headroom = 4
        second.outputPixelFormat = .rgba16Float
        let output = try XCTUnwrap(second.outputImage)

        let unoptimizedOptions = MTIContextOptions()
        unoptimizedOptions.enablesRenderGraphOptimization = false
        let optimizedOptions = MTIContextOptions()
        optimizedOptions.enablesRenderGraphOptimization = true
        let unoptimized = try XCTUnwrap(renderFloatPixels(
            output,
            width: 1,
            height: 1,
            context: makeContext(options: unoptimizedOptions)
        ).first)
        let optimized = try XCTUnwrap(renderFloatPixels(
            output,
            width: 1,
            height: 1,
            context: makeContext(options: optimizedOptions)
        ).first)
        let expected = SIMD4<Float>(1.5, 1.5, 1.5, 1)
        assertPixel(unoptimized, equals: expected, accuracy: 0.003, "unoptimized headroom boundary")
        assertPixel(optimized, equals: expected, accuracy: 0.003, "optimized headroom boundary")
    }

    func testHDROptimizerPreservesHeadroomDuringLegalFusion() throws {
        let background = floatImage([SIMD4<Float>(0.8, 0.8, 0.8, 1)], width: 1, height: 1)
        let source = floatImage([SIMD4<Float>(0.5, 0.5, 0.5, 1)], width: 1, height: 1)

        let first = MultilayerCompositingFilter()
        first.inputBackgroundImage = background
        first.layers = [.init(content: source).blendMode(.add)]
        first.headroom = 4
        first.outputPixelFormat = .rgba16Float

        let second = MultilayerCompositingFilter()
        second.inputBackgroundImage = try XCTUnwrap(first.outputImage)
        second.layers = [.init(content: source).blendMode(.add)]
        second.headroom = 4
        second.outputPixelFormat = .rgba16Float
        let output = try XCTUnwrap(second.outputImage)

        let unoptimizedOptions = MTIContextOptions()
        unoptimizedOptions.enablesRenderGraphOptimization = false
        let optimizedOptions = MTIContextOptions()
        optimizedOptions.enablesRenderGraphOptimization = true
        let unoptimized = try XCTUnwrap(renderFloatPixels(
            output,
            width: 1,
            height: 1,
            context: makeContext(options: unoptimizedOptions)
        ).first)
        let optimized = try XCTUnwrap(renderFloatPixels(
            output,
            width: 1,
            height: 1,
            context: makeContext(options: optimizedOptions)
        ).first)
        let expected = SIMD4<Float>(1.8, 1.8, 1.8, 1)
        assertPixel(unoptimized, equals: expected, accuracy: 0.003, "unoptimized legal fusion")
        assertPixel(optimized, equals: expected, accuracy: 0.003, "optimized legal fusion")
    }

    func testRenderGraphOptimizerCompletesSixtyFourNodeChain() throws {
        let options = MTIContextOptions()
        options.enablesRenderGraphOptimization = true
        let context = try makeContext(options: options)

        var image = floatImage(
            [SIMD4<Float>(0.25, 0.5, 0.75, 1)],
            width: 1,
            height: 1
        )
        for _ in 0..<64 {
            let filter = MTIColorMatrixFilter()
            filter.inputImage = image
            filter.colorMatrix = .identity
            filter.outputPixelFormat = .rgba32Float
            image = try XCTUnwrap(filter.outputImage).withCachePolicy(.transient)
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget]
        let texture = try XCTUnwrap(context.device.makeTexture(descriptor: descriptor))
        let task = try context.startTask(
            toRender: image,
            to: texture,
            destinationAlphaType: .alphaIsOne,
            completion: nil
        )
        task.waitUntilCompleted()
        XCTAssertNil(task.error)

        var pixel = [Float](repeating: .nan, count: 4)
        pixel.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: MemoryLayout<Float>.stride * 4,
                from: MTLRegionMake2D(0, 0, 1, 1),
                mipmapLevel: 0
            )
        }
        XCTAssertTrue(pixel.allSatisfy { $0.isFinite })
        for (actual, expected) in zip(pixel, [Float(0.25), 0.5, 0.75, 1]) {
            XCTAssertEqual(actual, expected, accuracy: 0.000001)
        }
    }

    func testHDRCustomTwoArgumentBlendFormulaCompatibility() throws {
        let blendMode = MTIBlendMode(rawValue: "task6LegacyTwoArgumentBlend")
        MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float4 blend(float4 backdrop, float4 source) {
            return float4(backdrop.rgb + source.rgb, 1.0);
        }
        """))
        defer {
            MTIBlendModes.unregisterBlendMode(blendMode)
        }

        let context = try makeContext()
        let backdrop = floatImage([SIMD4<Float>(2, 1.5, 0.25, 1)], width: 1, height: 1)
        let source = floatImage([SIMD4<Float>(0.5, 0.25, 0.75, 1)], width: 1, height: 1)
        let expected = SIMD4<Float>(2.5, 1.75, 1, 1)
        for path in Task6BlendPath.allCases {
            let actual = try renderBlendPixel(
                mode: blendMode,
                backdrop: backdrop,
                source: source,
                headroom: 4,
                path: path,
                context: context
            )
            assertPixel(actual, equals: expected, accuracy: 0.003, "legacy custom \(path.rawValue)")
        }
    }

    func testCLAHEHeadroomPreservesSDRAndUsesFloatForHDR() throws {
        let context = try makeContext()

        let sdrFilter = MTICLAHEFilter()
        sdrFilter.inputImage = claheFixture(headroom: 1)
        sdrFilter.tileGridSize = MTICLAHESize(width: 2, height: 2)
        sdrFilter.headroom = 1
        XCTAssertEqual(sdrFilter.outputPixelFormat, .unspecified)
        let sdrOutput = try XCTUnwrap(sdrFilter.outputImage?.withCachePolicy(.persistent))
        let sdrResolution = try resolvedBufferAndTexture(for: sdrOutput, context: context)
        XCTAssertEqual(sdrResolution.texture.pixelFormat, .bgra8Unorm)
        let sdrBytes = try readBGRA8Pixels(from: sdrResolution.texture, context: context)
        let sdrGolden: [[UInt8]] = [
            [16, 32, 41, 39, 33, 35, 46, 62],
            [78, 94, 104, 102, 96, 97, 108, 124],
            [122, 135, 144, 144, 138, 138, 148, 162],
            [125, 135, 142, 142, 138, 138, 145, 154],
            [106, 116, 122, 121, 117, 118, 126, 136],
            [102, 116, 125, 123, 118, 119, 130, 144],
            [143, 159, 169, 167, 161, 163, 175, 191],
            [207, 223, 233, 231, 225, 227, 239, 255],
        ]
        for row in 0..<8 {
            for column in 0..<8 {
                let offset = (row * 8 + column) * 4
                let expected = sdrGolden[row][column]
                XCTAssertEqual(Array(sdrBytes[offset..<(offset + 4)]), [expected, expected, expected, 255], "SDR CLAHE pixel (\(column), \(row))")
            }
        }

        let hdrFilter = MTICLAHEFilter()
        hdrFilter.inputImage = claheFixture(headroom: 4)
        hdrFilter.tileGridSize = MTICLAHESize(width: 2, height: 2)
        hdrFilter.headroom = 4
        XCTAssertEqual(hdrFilter.outputPixelFormat, .unspecified)
        let hdrOutput = try XCTUnwrap(hdrFilter.outputImage?.withCachePolicy(.persistent))
        let hdrResolution = try resolvedBufferAndTexture(for: hdrOutput, context: context)
        XCTAssertEqual(hdrResolution.texture.pixelFormat, .rgba16Float)
        let hdrPixels = try renderFloatPixels(hdrResolution.buffer, width: 8, height: 8, context: context)
        var containsHighlight = false
        for pixel in hdrPixels {
            for value in [pixel.x, pixel.y, pixel.z] {
                XCTAssertTrue(value.isFinite)
                XCTAssertTrue((0...4).contains(value), "HDR CLAHE component is \(value)")
                containsHighlight = containsHighlight || value > 1.01
            }
            XCTAssertTrue(pixel.w.isFinite)
            XCTAssertTrue((0...1).contains(pixel.w), "HDR CLAHE alpha is \(pixel.w)")
        }
        XCTAssertTrue(containsHighlight)

        let normalizedFilter = MTICLAHEFilter()
        normalizedFilter.inputImage = claheFixture(headroom: 1)
        normalizedFilter.tileGridSize = MTICLAHESize(width: 2, height: 2)
        normalizedFilter.headroom = 1
        normalizedFilter.outputPixelFormat = .rgba16Float
        let normalizedOutput = try XCTUnwrap(normalizedFilter.outputImage)
        let normalizedPixels = try renderFloatPixels(normalizedOutput, width: 8, height: 8, context: context)
        XCTAssertEqual(normalizedPixels.count, hdrPixels.count)
        for (index, pair) in zip(normalizedPixels, hdrPixels).enumerated() {
            assertPixel(
                pair.1 / SIMD4<Float>(4, 4, 4, 1),
                equals: pair.0,
                accuracy: 0.003,
                "normalized HDR CLAHE pixel \(index)"
            )
        }

        let explicitFormats: [(headroom: Float, pixelFormat: MTLPixelFormat)] = [
            (1, .rgba16Float),
            (4, .bgra8Unorm),
        ]
        for setting in explicitFormats {
            let filter = MTICLAHEFilter()
            filter.inputImage = claheFixture(headroom: setting.headroom)
            filter.tileGridSize = MTICLAHESize(width: 2, height: 2)
            filter.headroom = setting.headroom
            filter.outputPixelFormat = setting.pixelFormat
            let output = try XCTUnwrap(filter.outputImage?.withCachePolicy(.persistent))
            let resolution = try resolvedBufferAndTexture(for: output, context: context)
            XCTAssertEqual(resolution.texture.pixelFormat, setting.pixelFormat)
        }
    }

    func testCLAHEHeadroomNormalizesChromaticInput() throws {
        let context = try makeContext()

        func render(headroom: Float) throws -> [SIMD4<Float>] {
            let filter = MTICLAHEFilter()
            filter.inputImage = claheChromaticFixture(headroom: headroom)
            filter.tileGridSize = MTICLAHESize(width: 2, height: 2)
            filter.headroom = headroom
            filter.outputPixelFormat = .rgba16Float
            return try renderFloatPixels(
                XCTUnwrap(filter.outputImage),
                width: 8,
                height: 8,
                context: context
            )
        }

        let sdrPixels = try render(headroom: 1)
        let hdrPixels = try render(headroom: 4)
        XCTAssertEqual(sdrPixels.count, hdrPixels.count)
        for (index, pair) in zip(sdrPixels, hdrPixels).enumerated() {
            assertPixel(
                pair.1 / SIMD4<Float>(4, 4, 4, 1),
                equals: pair.0,
                accuracy: 0.003,
                "normalized chromatic CLAHE pixel \(index)"
            )
        }
    }
    
    func testSolidColorImageRendering() throws {
        let image = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 2, height: 2))
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            XCTAssert(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
        }
    }
    
    func testColorInvertFilter() throws {
        let image = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 2, height: 2))
        let filter = MTIColorInvertFilter()
        filter.inputImage = image
        let output = filter.outputImage
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: output!)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            XCTAssert(pixel.r == 0 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
        }
    }
    
    func testBlendWithMaskFilter() throws {
        let image = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 2, height: 2))
        let backgroundImage = MTIImage(color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 2, height: 2))
        let filter = MTIBlendWithMaskFilter()
        filter.inputBackgroundImage = backgroundImage
        filter.inputImage = image
        filter.inputMask = MTIMask(content: MTIImage(cgImage: try ImageGenerator.makeCheckboardImage(), isOpaque: true), component: .red, mode: .normal)
        let output = filter.outputImage
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: output!)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testSaturationFilter() throws {
        let image = MTIImage(color: MTIColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1), sRGB: false, size: CGSize(width: 2, height: 2))
        let filter = MTISaturationFilter()
        filter.inputImage = image
        filter.saturation = 0
        let output = filter.outputImage
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: output!)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            XCTAssert(pixel.r == pixel.g && pixel.g == pixel.b && pixel.a == 255)
        }
    }
    
    func testIntermediateTextureGeneration() throws {
        let image = MTIImage.black
        let saturationFilter = MTISaturationFilter()
        saturationFilter.saturation = 2
        let blendFilter = MTIBlendFilter(blendMode: .multiply)
        let invertFilter = MTIColorInvertFilter()
        let pixellateFilter = MTIPixellateFilter()
        pixellateFilter.scale = CGSize(width: 2, height: 2)
        let outputImage = FilterGraph.makeImage { output in
            image => saturationFilter => pixellateFilter => blendFilter.inputPorts.inputBackgroundImage
            image => invertFilter => blendFilter.inputPorts.inputImage
            blendFilter => saturationFilter => output
        }
        let context = try makeContext()
        XCTAssert(context.idleResourceCount == 0)
        let _ = try context.makeCGImage(from: outputImage!)
        XCTAssert(context.idleResourceCount == 3)
        
        context.reclaimResources()
        
        XCTAssert(context.idleResourceCount == 0)
        let outputImage2 = FilterGraph.makeImage { output in
            image => saturationFilter => pixellateFilter => invertFilter => saturationFilter => output
        }
        let _ = try context.makeCGImage(from: outputImage2!)
        XCTAssert(context.idleResourceCount == 2)
    }
    
    func testTextureRenderResultPersistence() throws {
        let image = MTIImage.black
        let filter = MTIColorInvertFilter()
        filter.inputImage = image
        let output = filter.outputImage!
        
        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: output)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coordinates) in
            XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
        }
        
        XCTAssert(context.idleResourceCount == 1)
        context.reclaimResources()
        XCTAssert(context.idleResourceCount == 0)
        
        try autoreleasepool {
            let output2 = filter.outputImage!.withCachePolicy(.persistent)
            let outputCGImage2 = try context.makeCGImage(from: output2)
            XCTAssert(context.idleResourceCount == 0)
            
            PixelEnumerator.enumeratePixels(in: outputCGImage2) { (pixel, coordinates) in
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            
            XCTAssertNotNil(context.renderedBuffer(for: output2))
            
            XCTAssert(context.idleResourceCount == 0)
        }
        
        XCTAssert(context.idleResourceCount == 1)
        context.reclaimResources()
        XCTAssert(context.idleResourceCount == 0)
    }
    
    func testCoreImageFilter() throws {
        let image = MTIImage.black
        let filter = MTICoreImageUnaryFilter()
        filter.filter = CIFilter(name: "CIColorInvert")
        filter.inputImage = image
        let output = filter.outputImage!
        
        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: output)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coordinates) in
            XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
        }
    }
    
    func testCoreImageFilter_lanczosScaleTransform() throws {
        let ciFilter = CIFilter(name: "CILanczosScaleTransform")
        ciFilter?.setValue(2, forKey: "inputScale")
        
        let inputImage = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 1],
            [1, 0]
        ]), isOpaque: true)
        
        let filter = MTICoreImageUnaryFilter()
        filter.filter = ciFilter
        filter.inputImage = inputImage
        let output = filter.outputImage!
        
        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: output)
        XCTAssert(outputCGImage.width == Int(inputImage.size.width) * 2)
        XCTAssert(outputCGImage.height == Int(inputImage.size.height) * 2)
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
            [0, 0, 1, 1],
            [0, 0, 1, 1],
            [1, 1, 0, 0],
            [1, 1, 0, 0],
        ]))
    }

    func testCoreImageUnaryFilter_normalizesFiniteTranslatedExtent() throws {
        let inputImage = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 255],
            [128, 64],
        ]), isOpaque: true)
        let ciFilter = try XCTUnwrap(CIFilter(name: "CIAffineTransform"))
        ciFilter.setValue(CGAffineTransform(translationX: 64, y: 64), forKey: kCIInputTransformKey)

        let filter = MTICoreImageUnaryFilter()
        filter.filter = ciFilter
        filter.inputImage = inputImage
        let outputImage = try XCTUnwrap(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        XCTAssertEqual(outputCGImage.width, 2)
        XCTAssertEqual(outputCGImage.height, 2)
        let expected: [[UInt8]] = [
            [0, 255],
            [128, 64],
        ]
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coordinates in
            let value = expected[coordinates.y][coordinates.x]
            XCTAssertEqual(pixel, PixelEnumerator.Pixel(b: value, g: value, r: value, a: 255), "Unexpected pixel at (\(coordinates.x), \(coordinates.y))")
        }
    }

    func testCoreImageUnaryFilterRendersExpandedNegativeExtent() throws {
        let inputImage = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [255],
        ]), isOpaque: true)
        let ciFilter = try XCTUnwrap(CIFilter(name: "CIGaussianBlur"))
        ciFilter.setValue(1, forKey: kCIInputRadiusKey)

        let filter = MTICoreImageUnaryFilter()
        filter.filter = ciFilter
        filter.inputImage = inputImage
        let outputImage = try XCTUnwrap(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        XCTAssertEqual(outputCGImage.width, 7)
        XCTAssertEqual(outputCGImage.height, 7)
        var pixels: [PixelEnumerator.Coordinates: PixelEnumerator.Pixel] = [:]
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coordinates in
            pixels[coordinates] = pixel
        }
        let center = try XCTUnwrap(pixels[PixelEnumerator.Coordinates(x: 3, y: 3)])
        let corner = try XCTUnwrap(pixels[PixelEnumerator.Coordinates(x: 0, y: 0)])
        XCTAssertGreaterThan(center.r, 0)
        XCTAssertGreaterThan(center.a, 0)
        XCTAssertGreaterThan(center.r, corner.r)
        XCTAssertGreaterThan(center.a, corner.a)
        for x in 0..<7 {
            for y in 0..<7 {
                let pixel = try XCTUnwrap(pixels[PixelEnumerator.Coordinates(x: x, y: y)])
                XCTAssertEqual(pixel, pixels[PixelEnumerator.Coordinates(x: 6 - x, y: y)], "Horizontal asymmetry at (\(x), \(y))")
                XCTAssertEqual(pixel, pixels[PixelEnumerator.Coordinates(x: x, y: 6 - y)], "Vertical asymmetry at (\(x), \(y))")
            }
        }
    }

    func testCoreImageUnaryFilterRespectsExplicitOutputImageSize() throws {
        let inputImage = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [255],
        ]), isOpaque: true)
        let ciFilter = try XCTUnwrap(CIFilter(name: "CIGaussianBlur"))
        ciFilter.setValue(1, forKey: kCIInputRadiusKey)

        let filter = MTICoreImageUnaryFilter()
        filter.filter = ciFilter
        filter.inputImage = inputImage
        filter.outputImageSize = CGSize(width: 3, height: 3)
        let outputImage = try XCTUnwrap(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        XCTAssertEqual(outputCGImage.width, 3)
        XCTAssertEqual(outputCGImage.height, 3)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coordinates in
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssertGreaterThan(pixel.r, 0)
                XCTAssertGreaterThan(pixel.g, 0)
                XCTAssertGreaterThan(pixel.b, 0)
                XCTAssertGreaterThan(pixel.a, 0)
            }
        }
    }

    func testCoreImageUnaryFilterBoundsInfiniteExtent() throws {
        let inputImage = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 255],
            [128, 64],
        ]), isOpaque: true)
        let ciFilter = try XCTUnwrap(CIFilter(name: "CIAffineClamp"))
        ciFilter.setValue(CGAffineTransform.identity, forKey: kCIInputTransformKey)

        let filter = MTICoreImageUnaryFilter()
        filter.filter = ciFilter
        filter.inputImage = inputImage
        let outputImage = try XCTUnwrap(filter.outputImage)

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        XCTAssertEqual(outputCGImage.width, 2)
        XCTAssertEqual(outputCGImage.height, 2)
        let expected: [[UInt8]] = [
            [0, 255],
            [128, 64],
        ]
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coordinates in
            let value = expected[coordinates.y][coordinates.x]
            XCTAssertEqual(pixel, PixelEnumerator.Pixel(b: value, g: value, r: value, a: 255), "Unexpected pixel at (\(coordinates.x), \(coordinates.y))")
        }
    }

    func testCoreImageKernelRendersNegativeOrigin() throws {
        let inputImage = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 64, 128],
            [0, 64, 128],
            [0, 64, 128],
        ]), isOpaque: true)
        let outputImage = MTICoreImageKernel.image(byProcessing: [inputImage], using: { images in
            images[0].transformed(by: CGAffineTransform(translationX: -1, y: -1))
        }, outputDimensions: MTITextureDimensions(cgSize: CGSize(width: 2, height: 2)))

        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        XCTAssertEqual(outputCGImage.width, 2)
        XCTAssertEqual(outputCGImage.height, 2)
        let expected: [[UInt8]] = [
            [64, 128],
            [64, 128],
        ]
        PixelEnumerator.enumeratePixels(in: outputCGImage) { pixel, coordinates in
            let value = expected[coordinates.y][coordinates.x]
            XCTAssertEqual(pixel, PixelEnumerator.Pixel(b: value, g: value, r: value, a: 255), "Unexpected pixel at (\(coordinates.x), \(coordinates.y))")
        }
    }
    
    func testMPSFilter_lanczosScale() throws {
        let kernel = MTIMPSKernel { device in
            return MPSImageLanczosScale(device: device)
        }
        let inputImage = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 1],
            [1, 0]
        ]), isOpaque: true)
        let scaledDimensions = MTITextureDimensions(cgSize: CGSize(width: inputImage.size.width * 2, height: inputImage.size.height * 2))
        let outputImage = kernel.apply(toInputImages: [inputImage], parameters: [:], outputTextureDimensions: scaledDimensions, outputPixelFormat: .unspecified)
        let context = try makeContext()
        if MTIContext.defaultMetalDeviceSupportsMPS {
            let outputCGImage = try context.makeCGImage(from: outputImage)
            XCTAssert(outputCGImage.width == Int(inputImage.size.width) * 2)
            XCTAssert(outputCGImage.height == Int(inputImage.size.height) * 2)
            XCTAssert(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
                [0, 0, 1, 1],
                [0, 0, 1, 1],
                [1, 1, 0, 0],
                [1, 1, 0, 0],
            ]))
        }
    }
    
    func testCoreImageGenerator() throws {
        let filter: CIFilter = CIFilter(name: "CICheckerboardGenerator")!
        filter.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        filter.setValue(CIColor.white, forKey: "inputColor0")
        filter.setValue(CIColor.black, forKey: "inputColor1")
        filter.setValue(1, forKey: "inputWidth")
        let ciImage = filter.outputImage!
        let mtiImage = MTICoreImageKernel.image(byProcessing: [], using: {_ in
            return ciImage
        }, outputDimensions: MTITextureDimensions(cgSize: CGSize(width: 2, height: 2)))
        
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: mtiImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
        
        let mtiImageFromCIImage = MTIImage(ciImage: ciImage.cropped(to: CGRect(x: 0, y: 0, width: 2, height: 2)), isOpaque: false)
        let cgImage2 = try context.makeCGImage(from: mtiImageFromCIImage)
        PixelEnumerator.enumeratePixels(in: cgImage2) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 0 && coordinates.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coordinates.x == 1 && coordinates.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testCoreImageTransform() throws {
        let inputImage = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 255, 128],
        ]), isOpaque: true)
        let mtiImage = MTICoreImageKernel.image(byProcessing: [inputImage], using: { image in
            return image[0].transformed(by: CGAffineTransform(translationX: -1, y: 0))
        }, outputDimensions: MTITextureDimensions(cgSize: CGSize(width: 2, height: 1)))
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: mtiImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                XCTAssertEqual(pixel, PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255))
            }
            if coordinates.x == 1 && coordinates.y == 0 {
                XCTAssertEqual(pixel, PixelEnumerator.Pixel(b: 128, g: 128, r: 128, a: 255))
            }
        }
    }
    
    func testImageOrientations() throws {
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0, 0],
            [0, 0, 255],
            [0, 255, 255],
            [0, 255, 255],
        ]), isOpaque: true)
        
        let context = try makeContext()
        let renderResult = try context.makeCGImage(from: image)
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: renderResult, target: [
            [0, 0, 0],
            [0, 0, 255],
            [0, 255, 255],
            [0, 255, 255],
        ]))
        
        // * * *
        // * *
        // *
        // *
        let up = try context.makeCGImage(from: image.oriented(.up))
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: up, target: [
            [0, 0, 0],
            [0, 0, 255],
            [0, 255, 255],
            [0, 255, 255],
        ]))
        
        // * * *
        //   * *
        //     *
        //     *
        let upMirrored = try context.makeCGImage(from: image.oriented(.upMirrored))
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: upMirrored, target: [
            [0,     0,   0],
            [255,   0,   0],
            [255, 255,   0],
            [255, 255,   0],
        ]))
        
        //     *
        //     *
        //   * *
        // * * *
        let down = try context.makeCGImage(from: image.oriented(.down))
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: down, target: [
            [255, 255,   0],
            [255, 255,   0],
            [255,   0,   0],
            [  0,   0,   0],
        ]))
        
        // *
        // *
        // * *
        // * * *
        let downMirrored = try context.makeCGImage(from: image.oriented(.downMirrored))
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: downMirrored, target: [
            [  0, 255, 255],
            [  0, 255, 255],
            [  0,   0, 255],
            [  0,   0,   0],
        ]))
        
        // * * * *
        // * *
        // *
        let leftMirrored = try context.makeCGImage(from: image.oriented(.leftMirrored))
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: leftMirrored, target: [
            [  0,   0,   0,   0],
            [  0,   0, 255, 255],
            [  0, 255, 255, 255]
        ]))
        
        // * * * *
        //     * *
        //       *
        let right = try context.makeCGImage(from: image.oriented(.right))
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: right, target: [
            [  0,   0,   0,   0],
            [255, 255,   0,   0],
            [255, 255, 255,   0],
        ]))
        
        //       *
        //     * *
        // * * * *
        let rightMirrored = try context.makeCGImage(from: image.oriented(.rightMirrored))
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: rightMirrored, target: [
            [255, 255, 255,   0],
            [255, 255,   0,   0],
            [  0,   0,   0,   0],
        ]))
        
        // *
        // * *
        // * * * *
        let left = try context.makeCGImage(from: image.oriented(.left))
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: left, target: [
            [  0, 255, 255, 255],
            [  0,   0, 255, 255],
            [  0,   0,   0,   0],
        ]))
    }
    
    func testImageOrientations_fixture() throws {
        let context = try makeContext()
        for orientation in 1...8 {
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: #file)
                                                        .deletingLastPathComponent().deletingLastPathComponent()
                                                        .appendingPathComponent("Fixture")
                                                        .appendingPathComponent("f\(orientation).png") as CFURL, nil)
            guard let imageSource = source,
                  CGImageSourceGetCount(imageSource) > 0,
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                XCTFail()
                return
            }
            guard let o = CGImagePropertyOrientation(rawValue: UInt32(orientation)) else {
                XCTFail()
                return
            }
            let image = MTIImage(cgImage: cgImage, isOpaque: true)
            let outputCGImage = try context.makeCGImage(from: image.oriented(o))
            XCTAssert(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
                [0, 0, 0],
                [0, 0, 255],
                [0, 255, 255],
                [0, 255, 255],
            ]))
        }
    }
    
    func testMultilayerCompositing() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
                            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(1)]
        let outputImage = try XCTUnwrap(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testMultilayerCompositing_alpha() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
                            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(0.5)]
        let outputImage = try XCTUnwrap(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 128 && pixel.g == 128 && pixel.b == 128 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testMultilayerCompositing_alphaMSAA() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 4
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
                            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(0.5)]
        let outputImage = try XCTUnwrap(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 128 && pixel.g == 128 && pixel.b == 128 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testMultilayerCompositing_tint() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
                            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(1)
                            .tintColor(MTIColor(red: 1, green: 1, blue: 0, alpha: 1))]
        let outputImage = try XCTUnwrap(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testColorLookupFilter() throws {
        let clut = try XCTUnwrap(IdentityCLUTImageGenerator.generateIdentityCLUTImage(with: CLUTImageDescriptor(dimension: 16, layout: CLUTImageLayout(horizontalTileCount: 1, verticalTileCount: 16))))
        let invertFilter = MTIColorInvertFilter()
        invertFilter.inputImage = MTIImage(cgImage: clut, isOpaque: true)
        let clutImage = try XCTUnwrap(invertFilter.outputImage)
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [64, 128],
        ]), isOpaque: true)
        
        let lookupFilter = MTIColorLookupFilter()
        lookupFilter.inputImage = image
        lookupFilter.inputColorLookupTable = clutImage
        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: XCTUnwrap(lookupFilter.outputImage))
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 191 && pixel.g == 191 && pixel.b == 191 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 127 && pixel.g == 127 && pixel.b == 127 && pixel.a == 255)
            }
        }
    }
    
    func testMultilayerCompositing_clut512x512() throws {
        let clut = try XCTUnwrap(IdentityCLUTImageGenerator.generateIdentityCLUTImage(with: CLUTImageDescriptor(dimension: 64, layout: CLUTImageLayout(horizontalTileCount: 8, verticalTileCount: 8))))
        let invertFilter = MTIColorInvertFilter()
        invertFilter.inputImage = MTIImage(cgImage: clut, isOpaque: true)
        let clutImage = try XCTUnwrap(invertFilter.outputImage)
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [64, 64],
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: clutImage)
                            .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(1)
                            .blendMode(.colorLookup512x512)]
        let outputImage = try XCTUnwrap(filter.outputImage)
        
        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 191 && pixel.g == 191 && pixel.b == 191 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 64 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
            }
        }
    }
    
    func testMultilayerCompositing_mask() throws {
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [128, 128],
            [128, 128],
        ]), isOpaque: true)
        
        let mask = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [255, 0]
        ]), isOpaque: true)
        
        let layerContent = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0]
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: layerContent)
                            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
                            .opacity(1)
                            .blendMode(.normal)
                            .mask(MTIMask(content: mask))]
        let outputImage = try XCTUnwrap(filter.outputImage)
        
        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
            [0, 128],
            [128, 128]
        ]))
    }
    
    func testMultilayerCompositing_compositingMask() throws {
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [128, 128],
            [128, 128],
        ]), isOpaque: true)
        
        let compositingMask = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 255],
            [0, 0]
        ]), isOpaque: true)
        
        let layerContent = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0]
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: layerContent)
                            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
                            .opacity(1)
                            .blendMode(.normal)
                            .compositingMask(MTIMask(content: compositingMask))]
        let outputImage = try XCTUnwrap(filter.outputImage)
        
        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
            [128, 0],
            [128, 128]
        ]))
    }
    
    func testMultilayerCompositing_clut512x512_mask() throws {
        let clut = try XCTUnwrap(IdentityCLUTImageGenerator.generateIdentityCLUTImage(with: CLUTImageDescriptor(dimension: 64, layout: CLUTImageLayout(horizontalTileCount: 8, verticalTileCount: 8))))
        let invertFilter = MTIColorInvertFilter()
        invertFilter.inputImage = MTIImage(cgImage: clut, isOpaque: true)
        let clutImage = try XCTUnwrap(invertFilter.outputImage)
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [64, 64],
            [64, 64],
        ]), isOpaque: true)
        
        let mask = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [255, 0]
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: clutImage)
                            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
                            .opacity(1)
                            .blendMode(.colorLookup512x512)
                            .mask(MTIMask(content: mask))]
        let outputImage = try XCTUnwrap(filter.outputImage)
        
        let context = try makeContext()
        let outputCGImage = try context.makeCGImage(from: outputImage)
        XCTAssert(PixelEnumerator.monochromeImageEqual(image: outputCGImage, target: [
            [191, 64],
            [64, 64]
        ]))
    }
    
    func testMultilayerCompositing_tintWithAlpha() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        
        try autoreleasepool {
            filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
                                .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
                                .opacity(1)
                                .tintColor(MTIColor(red: 1, green: 1, blue: 0, alpha: 0.5))]
            let outputImage = try XCTUnwrap(filter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
                if coord.x == 0 && coord.y == 0 {
                    XCTAssert(pixel.r == 128 && pixel.g == 128 && pixel.b == 0 && pixel.a == 255)
                }
                if coord.x == 1 && coord.y == 0 {
                    XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
                }
            }
        }
        
        try autoreleasepool {
            filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
                                .frame(center: CGPoint(x: 0.5, y: 0.5), size: CGSize(width: 1, height: 1), layoutUnit: .pixel)
                                .opacity(1)
                                .tintColor(MTIColor(red: 1, green: 1, blue: 0, alpha: 0))]
            let outputImage = try XCTUnwrap(filter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
                if coord.x == 0 && coord.y == 0 {
                    XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
                }
                if coord.x == 1 && coord.y == 0 {
                    XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
                }
            }
        }
    }
    
    func testMultilayerCompositing_rotation() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0],
            [0, 0],
        ]), isOpaque: true)
        
        let overlayImage = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 255],
            [0, 0],
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: overlayImage)
                            .frame(CGRect(x: 0, y: 0, width: 2, height: 2), layoutUnit: .pixel)
                            .rotation(.pi/2)
                            .opacity(1)]
        guard let outputImage = filter.outputImage else {
            XCTFail()
            return
        }
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 0 && coord.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testMultilayerCompositing_outputOpaqueImage() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        filter.layers = [MultilayerCompositingFilter.Layer(content:  MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1)))
                            .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(1)]
        filter.outputAlphaType = .alphaIsOne
        let outputImage = try XCTUnwrap(filter.outputImage?.withCachePolicy(.persistent))
        XCTAssert(outputImage.alphaType == .alphaIsOne)
        
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coord) in
            XCTAssert(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
        }
    }
    
    func testMultilayerCompositing_outputNonPremultipliedAlpha() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        filter.layers = [MultilayerCompositingFilter.Layer(content:  MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1)))
                            .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(1)]
        let outputImage = try XCTUnwrap(filter.outputImage?.withCachePolicy(.persistent))
        XCTAssert(outputImage.alphaType == .nonPremultiplied)
        
        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try XCTUnwrap(context.renderedBuffer(for: outputImage))
        let texture = buffer.value(forKeyPath: "promise.resolution.renderTarget.texture") as! MTLTexture
        let pixels = try fetchFirstPixel(from: texture, context: context)
        XCTAssert(pixels == [0,0,255,192])
    }
    
    func testMultilayerCompositing_outputPremultipliedAlpha() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        filter.layers = [MultilayerCompositingFilter.Layer(content:  MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1)))
                            .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(1)]
        filter.outputAlphaType = .premultiplied
        let outputImage = try XCTUnwrap(filter.outputImage?.withCachePolicy(.persistent))
        XCTAssert(outputImage.alphaType == .premultiplied)
        
        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try XCTUnwrap(context.renderedBuffer(for: outputImage))
        let texture = buffer.value(forKeyPath: "promise.resolution.renderTarget.texture") as! MTLTexture
        let pixels = try fetchFirstPixel(from: texture, context: context)
        XCTAssert(pixels == [0,0,192,192])
    }
    
    
    func testBlend_outputOpaqueImage() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        filter.layers = [MultilayerCompositingFilter.Layer(content:  MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1)))
                            .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(1)]
        filter.outputAlphaType = .alphaIsOne
        let outputImage = try XCTUnwrap(filter.outputImage?.withCachePolicy(.persistent))
        XCTAssert(outputImage.alphaType == .alphaIsOne)
        
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coord) in
            XCTAssert(pixel.r == 255 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
        }
    }
    
    func testBlend_outputNonPremultipliedAlpha() throws {
        let filter = MTIBlendFilter(blendMode: .normal)
        filter.inputBackgroundImage = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        filter.inputImage = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        let outputImage = try XCTUnwrap(filter.outputImage?.withCachePolicy(.persistent))
        XCTAssert(outputImage.alphaType == .nonPremultiplied)

        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try XCTUnwrap(context.renderedBuffer(for: outputImage))
        let texture = buffer.value(forKeyPath: "promise.resolution.renderTarget.texture") as! MTLTexture
        let pixels = try fetchFirstPixel(from: texture, context: context)
        XCTAssert(pixels == [0,0,255,192])
    }
    
    func testBlend_outputPremultipliedAlpha() throws {
        let filter = MTIBlendFilter(blendMode: .normal)
        filter.inputBackgroundImage = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        filter.inputImage = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        filter.outputAlphaType = .premultiplied
        let outputImage = try XCTUnwrap(filter.outputImage?.withCachePolicy(.persistent))
        XCTAssert(outputImage.alphaType == .premultiplied)
        
        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try XCTUnwrap(context.renderedBuffer(for: outputImage))
        let texture = buffer.value(forKeyPath: "promise.resolution.renderTarget.texture") as! MTLTexture
        let pixels = try fetchFirstPixel(from: texture, context: context)
        XCTAssert(pixels == [0,0,192,192])
    }
    
    func testMultilayerCompositing_outputPremultipliedAlpha_emptyLayers() throws {
        let kernel = MTIMultilayerCompositeKernel()
        let outputImage = kernel.apply(toBackgroundImage: MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1)),
                     layers: [],
                     rasterSampleCount: 1,
                     outputAlphaType: .premultiplied,
                     outputTextureDimensions: .init(width: 1, height: 1, depth: 1),
                     outputPixelFormat: .unspecified).withCachePolicy(.persistent)
        XCTAssert(outputImage.alphaType == .premultiplied)
        
        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try XCTUnwrap(context.renderedBuffer(for: outputImage))
        let texture = buffer.value(forKeyPath: "promise.resolution.renderTarget.texture") as! MTLTexture
        let pixels = try fetchFirstPixel(from: texture, context: context)
        XCTAssert(pixels == [0,0,128,128])
    }
    
    func testMultilayerCompositing_outputPremultipliedAlpha_msaa() throws {
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        filter.layers = [MultilayerCompositingFilter.Layer(content:  MTIImage(color: MTIColor(red: 1, green: 0, blue: 0, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1)))
                            .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(1)]
        filter.rasterSampleCount = 4
        filter.outputAlphaType = .premultiplied
        let outputImage = try XCTUnwrap(filter.outputImage?.withCachePolicy(.persistent))
        XCTAssert(outputImage.alphaType == .premultiplied)
        
        let context = try makeContext()
        let task = try context.startTask(toRender: outputImage, completion: nil)
        task.waitUntilCompleted()
        let buffer = try XCTUnwrap(context.renderedBuffer(for: outputImage))
        let texture = buffer.value(forKeyPath: "promise.resolution.renderTarget.texture") as! MTLTexture
        let pixels = try fetchFirstPixel(from: texture, context: context)
        XCTAssert(pixels == [0,0,192,192])
    }
    
    func testMSAA_multilayerCompositing() throws {
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 0],
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.rasterSampleCount = 1
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage.white)
                            .frame(CGRect(x: 0, y: 0, width: 1.6, height: 1), layoutUnit: .pixel)
                            .opacity(1)]
        guard let outputImage = filter.outputImage else {
            XCTFail()
            return
        }
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
        
        filter.rasterSampleCount = 4
        guard let outputImageMSAA = filter.outputImage else {
            XCTFail()
            return
        }
        let outputCGImageMSAA = try context.makeCGImage(from: outputImageMSAA)
        PixelEnumerator.enumeratePixels(in: outputCGImageMSAA) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                let positions = context.device.getDefaultSamplePositions(sampleCount: 4)
                var p: Double = 0
                for position in positions {
                    if position.x < 0.6 {
                        p += 1.0/4.0
                    }
                }
                
                //Should we use `round` here? https://developer.apple.com/documentation/metal/mtlrenderpipelinestate/3608177-texturewriteroundingmode
                let value = UInt8(round(p * 255))
                XCTAssert(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }
    
    func testMSAA_renderCommand() throws {
        let context = try makeContext()
        
        let geometry = MTIVertices.squareVertices(for: CGRect(x: -1, y: -1, width: 1.6, height: 2))
        let command = MTIRenderCommand(kernel: .passthrough, geometry: geometry, images: [MTIImage.white], parameters: [:])
        let outputDescriptor = MTIRenderPassOutputDescriptor(dimensions: MTITextureDimensions(width: 2, height: 1, depth: 1), pixelFormat: .bgra8Unorm, clearColor: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1), loadAction: .clear, storeAction: .store)
        let image = MTIRenderCommand.images(byPerforming: [command], rasterSampleCount: 1, outputDescriptors: [outputDescriptor]).first
        guard let outputImage = image else {
            XCTFail()
            return
        }
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
        
        let imageMSAA = MTIRenderCommand.images(byPerforming: [command], rasterSampleCount: 4, outputDescriptors: [outputDescriptor]).first
        guard let outputImageMSAA = imageMSAA else {
            XCTFail()
            return
        }
        let outputCGImageMSAA = try context.makeCGImage(from: outputImageMSAA)
        PixelEnumerator.enumeratePixels(in: outputCGImageMSAA) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                let positions = context.device.getDefaultSamplePositions(sampleCount: 4)
                var p: Double = 0
                for position in positions {
                    if position.x < 0.6 {
                        p += 1.0/4.0
                    }
                }
                
                //Should we use `round` here? https://developer.apple.com/documentation/metal/mtlrenderpipelinestate/3608177-texturewriteroundingmode
                let value = UInt8(round(p * 255))
                XCTAssert(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }
    
    func testRenderedBuffer() throws {
        let context = try makeContext()
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [255, 255],
            [0, 255],
        ]), isOpaque: true)
        
        let filter1 = MTIColorInvertFilter()
        filter1.inputImage = image
        
        let filter2 = MTITransformFilter()
        filter2.transform = CATransform3DMakeRotation(.pi/2, 0, 0, 1)
        filter2.inputImage = filter1.outputImage
        
        var renderedBuffer: MTIImage!
        
        try autoreleasepool {
            let outputImage = try XCTUnwrap(filter2.outputImage?.withCachePolicy(.persistent))
            
            XCTAssert(context.renderedBuffer(for: outputImage) == nil)
            
            try context.startTask(toRender: outputImage, completion: nil)
            
            XCTAssert(context.renderedBuffer(for: outputImage) != nil)
            
            let buffer = try XCTUnwrap(context.renderedBuffer(for: outputImage))
            
            renderedBuffer = buffer
            
            XCTAssert(context.idleResourceCount == 1)
        }
        
        context.reclaimResources()
        
        XCTAssert(context.idleResourceCount == 0)
        
        let outputCGImage = try context.makeCGImage(from: renderedBuffer)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 0 && coord.y == 1 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 1 {
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 255 && pixel.a == 255)
            }
        }
        
        XCTAssert(context.idleResourceCount == 0)
        
        renderedBuffer = nil
        
        XCTAssert(context.idleResourceCount == 1)
        
        context.reclaimResources()
        
        XCTAssert(context.idleResourceCount == 0)
    }
    
    func testCustomComputePipeline() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        kernel void testCompute(
        texture2d<float, access::read> inTexture [[texture(0)]],
        texture2d<float, access::write> outTexture [[texture(1)]],
        constant float4 &color [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
                return;
            }
            outTexture.write(inTexture.read(uint2(0,0)) + color, gid);
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(source: kernelSource, compileOptions: nil)
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(name: "testCompute", libraryURL: libraryURL))
        
        try autoreleasepool {
            let image = MTIImage(color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 32, height: 32))
            let outputImage = computeKernel.apply(toInputImages: [image], parameters: ["color": MTIVector(value: SIMD4<Float>(1, 0, 0, 0))], dispatchOptions: nil, outputTextureDimensions: image.dimensions, outputPixelFormat: .unspecified)
            let context = try makeContext()
            let output = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: output) { (pixel, _) in
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
        
        try autoreleasepool {
            let image = MTIImage(color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 1, height: 1))
            let outputImage = computeKernel.apply(toInputImages: [image], parameters: ["color": MTIVector(value: SIMD4<Float>(1, 0, 0, 0))], dispatchOptions: nil, outputTextureDimensions: image.dimensions, outputPixelFormat: .unspecified)
            let context = try makeContext()
            let output = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: output) { (pixel, _) in
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testCustomComputePipelineWithFunctionConstants() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        constant float4 constColor [[function_constant(0)]];

        kernel void testCompute(
        texture2d<float, access::read> inTexture [[texture(0)]],
        texture2d<float, access::write> outTexture [[texture(1)]],
        uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
                return;
            }
            outTexture.write(inTexture.read(uint2(0,0)) + constColor, gid);
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(source: kernelSource, compileOptions: nil)
        let constantValues = MTLFunctionConstantValues()
        var color = SIMD4<Float>(1, 0, 0, 0)
        constantValues.setConstantValue(&color, type: .float4, withName: "constColor")
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(name: "testCompute", constantValues: constantValues, libraryURL: libraryURL))
        
        try autoreleasepool {
            let image = MTIImage(color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 32, height: 32))
            let outputImage = computeKernel.apply(toInputImages: [image], parameters: [:], dispatchOptions: nil, outputTextureDimensions: image.dimensions, outputPixelFormat: .unspecified)
            let context = try makeContext()
            let output = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: output) { (pixel, _) in
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
        
        try autoreleasepool {
            let image = MTIImage(color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 1, height: 1))
            let outputImage = computeKernel.apply(toInputImages: [image], parameters: [:], dispatchOptions: nil, outputTextureDimensions: image.dimensions, outputPixelFormat: .unspecified)
            let context = try makeContext()
            let output = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: output) { (pixel, _) in
                XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testCustomRenderPipeline() throws {
        var librarySource = ""
        let sourceFileDirectory = URL(fileURLWithPath: String(#file)).deletingLastPathComponent().appendingPathComponent("../../Sources/MetalPetalObjectiveC")
        let headerURL = sourceFileDirectory.appendingPathComponent("include/MTIShaderLib.h")
        librarySource += try String(contentsOf: headerURL)
        librarySource += """
        
        using namespace metalpetal;
        
        fragment float4 testRender(
                                VertexOut vertexIn [[stage_in]],
                                texture2d<float, access::sample> sourceTexture [[texture(0)]],
                                sampler sourceSampler [[sampler(0)]],
                                constant float4 &color [[buffer(0)]]
                                ) {
            float4 textureColor = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
            return textureColor + color;
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(source: librarySource, compileOptions: nil)
        let renderKernel = MTIRenderPipelineKernel(vertexFunctionDescriptor: .passthroughVertex, fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "testRender", libraryURL: libraryURL))
        let image = MTIImage(color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 1, height: 1))
        let outputImage = renderKernel.apply(to: [image], parameters: ["color": MTIVector(value: SIMD4<Float>(1, 0, 0, 0))], outputDimensions: image.dimensions, outputPixelFormat: .unspecified)
        let context = try makeContext()
        let output = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: output) { (pixel, _) in
            XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
        }
    }
    
    func testCustomRenderPipelineWithFunctionConstants() throws {
        var librarySource = ""
        let sourceFileDirectory = URL(fileURLWithPath: String(#file)).deletingLastPathComponent().appendingPathComponent("../../Sources/MetalPetalObjectiveC")
        let headerURL = sourceFileDirectory.appendingPathComponent("include/MTIShaderLib.h")
        librarySource += try String(contentsOf: headerURL)
        librarySource += """
        
        using namespace metalpetal;
        
        constant float4 constColor [[function_constant(0)]];
        
        fragment float4 testRender(
            VertexOut vertexIn [[stage_in]],
            texture2d<float, access::sample> sourceTexture [[texture(0)]],
            sampler sourceSampler [[sampler(0)]]
        ) {
            float4 textureColor = sourceTexture.sample(sourceSampler, vertexIn.textureCoordinate);
            return textureColor + constColor;
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(source: librarySource, compileOptions: nil)
        let constantValues = MTLFunctionConstantValues()
        var color = SIMD4<Float>(1, 0, 0, 0)
        constantValues.setConstantValue(&color, type: .float4, withName: "constColor")
        let renderKernel = MTIRenderPipelineKernel(vertexFunctionDescriptor: .passthroughVertex, fragmentFunctionDescriptor: MTIFunctionDescriptor(name: "testRender", constantValues: constantValues, libraryURL: libraryURL))
        let image = MTIImage(color: MTIColor(red: 0, green: 1, blue: 0, alpha: 1), sRGB: false, size: CGSize(width: 1, height: 1))
        let outputImage = renderKernel.apply(to: [image], parameters: [:], outputDimensions: image.dimensions, outputPixelFormat: .unspecified)
        let context = try makeContext()
        let output = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: output) { (pixel, _) in
            XCTAssert(pixel.r == 255 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
        }
    }
    
    func testMultilayerCompositing_customBlending() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float4 blend(float4 background, float4 foreground) {
            return background + foreground;
        }
        """))
        defer {
            MTIBlendModes.unregisterBlendMode(blendMode)
        }
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [64, 64],
        ]), isOpaque: true)
        
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [MultilayerCompositingFilter.Layer(content: MTIImage(color: MTIColor(red: 64/255.0, green: 0, blue: 0, alpha: 0), sRGB: false, size: CGSize(width: 1, height: 1)))
                            .frame(CGRect(x: 0, y: 0, width: 1, height: 1), layoutUnit: .pixel)
                            .opacity(1)
                            .blendMode(blendMode)]
        let outputImage = try XCTUnwrap(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 128 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 64 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
            }
        }
    }
    
    func testMultilayerCompositing_customBlending_textureCoordinatesModifier() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float2 modify_source_texture_coordinates(float4 backdrop, float2 coordinates, uint2 source_texture_size) {
            return float2(1.5, 0.5) / float2(source_texture_size);
        }
        float4 blend(float4 background, float4 foreground) {
            return background + foreground;
        }
        """))
        defer {
            MTIBlendModes.unregisterBlendMode(blendMode)
        }
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [64, 64],
        ]), isOpaque: true)
        let overlay = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 32],
        ]), isOpaque: true)
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [MultilayerCompositingFilter.Layer(content: overlay)
                            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
                            .opacity(1)
                            .blendMode(blendMode)]
        let outputImage = try XCTUnwrap(filter.outputImage)
        let outputCGImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
            if coord.x == 0 && coord.y == 0 {
                XCTAssert(pixel.r == 64 + 32 && pixel.g == 64 + 32 && pixel.b == 64 + 32 && pixel.a == 255)
            }
            if coord.x == 1 && coord.y == 0 {
                XCTAssert(pixel.r == 64 + 32 && pixel.g == 64 + 32 && pixel.b == 64 + 32 && pixel.a == 255)
            }
        }
    }
    
    func testMultilayerCompositing_blendModeRenderPipelineNotFound() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [64, 64],
        ]), isOpaque: true)
        let overlay = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 32],
        ]), isOpaque: true)
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [MultilayerCompositingFilter.Layer(content: overlay)
                            .frame(CGRect(x: 0, y: 0, width: 2, height: 1), layoutUnit: .pixel)
                            .opacity(1)
                            .blendMode(blendMode)]
        let outputImage = try XCTUnwrap(filter.outputImage)
        XCTAssertThrowsError(try context.makeCGImage(from: outputImage))
    }
    
    func testCustomBlending() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float4 blend(float4 background, float4 foreground) {
            return background + foreground;
        }
        """))
        defer {
            MTIBlendModes.unregisterBlendMode(blendMode)
        }
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [64],
        ]), isOpaque: true)
        let overlay = MTIImage(color: MTIColor(red: 64/255.0, green: 0, blue: 0, alpha: 0), sRGB: false, size: CGSize(width: 1, height: 1))
        let blendFilter = MTIBlendFilter(blendMode: blendMode)
        blendFilter.inputBackgroundImage = image
        blendFilter.inputImage = overlay
        
        do {
            let outputImage = try XCTUnwrap(blendFilter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
                if coord.x == 0 && coord.y == 0 {
                    XCTAssert(pixel.r == 128 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
                }
            }
        }
        
        do {
            blendFilter.intensity = 0.5
            let outputImage = try XCTUnwrap(blendFilter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
                if coord.x == 0 && coord.y == 0 {
                    XCTAssert(pixel.r == 64 + 32 && pixel.g == 64 && pixel.b == 64 && pixel.a == 255)
                }
            }
        }
    }
    
    func testCustomBlending_textureCoordinatesModifier() throws {
        let name = "customBlend" + String(#line)
        let blendMode = MTIBlendMode(rawValue: name)
        MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
        float2 modify_source_texture_coordinates(float4 backdrop, float2 coordinates, uint2 source_texture_size) {
            return float2(1.5, 0.5) / float2(source_texture_size);
        }
        float4 blend(float4 background, float4 foreground) {
            return background + foreground;
        }
        """))
        defer {
            MTIBlendModes.unregisterBlendMode(blendMode)
        }
        let context = try makeContext()
        
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [64],
        ]), isOpaque: true)
        let overlay = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [0, 32],
        ]), isOpaque: true)
        let blendFilter = MTIBlendFilter(blendMode: blendMode)
        blendFilter.inputBackgroundImage = image
        blendFilter.inputImage = overlay
        
        do {
            let outputImage = try XCTUnwrap(blendFilter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
                if coord.x == 0 && coord.y == 0 {
                    XCTAssert(pixel.r == 64 + 32 && pixel.g == 64 + 32 && pixel.b == 64 + 32 && pixel.a == 255)
                }
            }
        }
        
        do {
            blendFilter.intensity = 0.5
            let outputImage = try XCTUnwrap(blendFilter.outputImage)
            let outputCGImage = try context.makeCGImage(from: outputImage)
            PixelEnumerator.enumeratePixels(in: outputCGImage) { (pixel, coord) in
                if coord.x == 0 && coord.y == 0 {
                    XCTAssert(pixel.r == 64 + 16 && pixel.g == 64 + 16 && pixel.b == 64 + 16 && pixel.a == 255)
                }
            }
        }
    }
    
    func testCustomBlending_failure() throws {
        do {
            let name = "customBlend" + String(#line)
            let blendMode = MTIBlendMode(rawValue: name)
            MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
            void blend(float4 background, float4 foreground) {
                return background + foreground;
            }
            """))
            defer {
                MTIBlendModes.unregisterBlendMode(blendMode)
            }
            let context = try makeContext()
            
            let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
                [64],
            ]), isOpaque: true)
            let overlay = MTIImage(color: MTIColor(red: 64/255.0, green: 0, blue: 0, alpha: 0), sRGB: false, size: CGSize(width: 1, height: 1))
            let blendFilter = MTIBlendFilter(blendMode: blendMode)
            blendFilter.inputBackgroundImage = image
            blendFilter.inputImage = overlay
            
            do {
                let outputImage = try XCTUnwrap(blendFilter.outputImage)
                XCTAssertThrowsError(try context.makeCGImage(from: outputImage))
            }
        }
        
        do {
            let name = "customBlend" + String(#line)
            let blendMode = MTIBlendMode(rawValue: name)
            MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
            float4 my_blend(float4 background, float4 foreground) {
                return background + foreground;
            }
            """))
            defer {
                MTIBlendModes.unregisterBlendMode(blendMode)
            }
            let context = try makeContext()
            
            let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
                [64],
            ]), isOpaque: true)
            let overlay = MTIImage(color: MTIColor(red: 64/255.0, green: 0, blue: 0, alpha: 0), sRGB: false, size: CGSize(width: 1, height: 1))
            let blendFilter = MTIBlendFilter(blendMode: blendMode)
            blendFilter.inputBackgroundImage = image
            blendFilter.inputImage = overlay
            
            do {
                let outputImage = try XCTUnwrap(blendFilter.outputImage)
                XCTAssertThrowsError(try context.makeCGImage(from: outputImage))
            }
        }
        
        do {
            let name = "customBlend" + String(#line)
            let blendMode = MTIBlendMode(rawValue: name)
            MTIBlendModes.registerBlendMode(blendMode, with: MTIBlendFunctionDescriptors(blendFormula: """
            int modify_source_texture_coordinates = 0;
            float4 my_blend(float4 background, float4 foreground) {
                return background + foreground;
            }
            """))
            defer {
                MTIBlendModes.unregisterBlendMode(blendMode)
            }
            let context = try makeContext()
            
            let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
                [64],
            ]), isOpaque: true)
            let overlay = MTIImage(color: MTIColor(red: 64/255.0, green: 0, blue: 0, alpha: 0), sRGB: false, size: CGSize(width: 1, height: 1))
            let blendFilter = MTIBlendFilter(blendMode: blendMode)
            blendFilter.inputBackgroundImage = image
            blendFilter.inputImage = overlay
            
            do {
                let outputImage = try XCTUnwrap(blendFilter.outputImage)
                XCTAssertThrowsError(try context.makeCGImage(from: outputImage))
            }
        }
    }
    
    func testCropFilter() throws {
        let image = MTIImage(cgImage: try ImageGenerator.makeMonochromeImage([
            [1,2,3,4],
            [5,6,7,8],
            [9,10,11,12],
            [13,14,15,16],
        ]), isOpaque: true)
        do {
            let croppedImage = image.cropped(to: .pixel(CGRect(x: 0, y: 0, width: 0, height: 0)))
            XCTAssertNil(croppedImage)
        }
        do {
            let croppedImage = image.cropped(to: .fractional(CGRect(x: 0, y: 0, width: 0, height: 0)))
            XCTAssertNil(croppedImage)
        }
        do {
            let croppedImage = try XCTUnwrap(image.cropped(to: .pixel(CGRect(x: 1, y: 1, width: 1, height: 1))))
            let context = try makeContext()
            let output = try context.makeCGImage(from: croppedImage)
            PixelEnumerator.enumeratePixels(in: output) { (pixel, coord) in
                XCTAssert(pixel.r == 6 && pixel.g == 6 && pixel.b == 6 && pixel.a == 255)
            }
        }
        do {
            let croppedImage = try XCTUnwrap(image.cropped(to: .pixel(CGRect(x: 1, y: 1, width: 100, height: 100))))
            XCTAssert(croppedImage.size.width == 100 && croppedImage.size.height == 100)
        }
    }
    
    func testWriteToDataBuffer() throws {
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        kernel void testCompute(device uint *outBuffer [[buffer(0)]], constant uint &count [[buffer(1)]], uint gid [[thread_position_in_grid]]) {
            if (gid < count) {
                outBuffer[gid] = gid;
            }
        }
        """
        let libraryURL = MTILibrarySourceRegistration.shared.registerLibrary(source: kernelSource, compileOptions: nil)
        let computeKernel = MTIComputePipelineKernel(computeFunctionDescriptor: MTIFunctionDescriptor(name: "testCompute", constantValues: nil, libraryURL: libraryURL))
        do {
            let dataCount: Int = 8
            let dataBuffer = try XCTUnwrap(MTIDataBuffer(values: [UInt32](repeating: 0, count: dataCount)))
            let outputImage = computeKernel.apply(toInputImages: [], parameters: ["outBuffer": dataBuffer, "count": MTIVector(values: [UInt32(dataCount)])], dispatchOptions: nil, outputTextureDimensions: MTITextureDimensions(width: dataCount, height: 1), outputPixelFormat: .unspecified)
            let context = try makeContext()
            let task = try context.startTask(toRender: outputImage, completion: { task in
                
            })
            task.waitUntilCompleted()
            dataBuffer.unsafeAccess({ (buffer: UnsafeMutableBufferPointer<UInt32>) -> Void in
                let output = Array(buffer)
                for item in output.enumerated() {
                    XCTAssert(item.element == UInt32(item.offset))
                }
            })
        }
    }
    
    func testSKSceneRender() throws {
        let scene = SKScene(size: CGSize(width: 32, height: 32))
        
        let node1 = SKShapeNode(circleOfRadius: 16)
        node1.fillColor = .red
        node1.lineWidth = 1
        node1.strokeColor = .white
        scene.addChild(node1)
        
        let node2 = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 32, height: 32))
        node2.fillColor = .blue
        node2.lineWidth = 0
        scene.addChild(node2)
        
        let node3 = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 32, height: 16))
        node3.fillColor = .green
        node3.lineWidth = 0
        scene.addChild(node3)
        
        let image = MTIImage(skScene: scene)
        let context = try makeContext()
        let output = try context.makeCGImage(from: image)
        PixelEnumerator.enumeratePixels(in: output) { (pixel, coord) in
            if coord.y < 16 {
                XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 255 && pixel.a == 255)
            } else {
                XCTAssert(pixel.r == 0 && pixel.g == 255 && pixel.b == 0 && pixel.a == 255)
            }
        }
    }
    
    func testSCNSceneRender() throws {
        let scene = SCNScene()
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        
        let cubeNode = SCNNode()
        cubeNode.geometry = SCNBox(width: 20, height: 20, length: 20, chamferRadius: 0)
        cubeNode.geometry?.firstMaterial?.lightingModel = .constant
        var color: [CGFloat] = [0,0,0.5,1]
        cubeNode.geometry?.firstMaterial?.diffuse.contents = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: &color)!
        cubeNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(cubeNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        var whiteColor: [CGFloat] = [1,1,1,1]
        ambientLightNode.light!.color = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: &whiteColor)!
        scene.rootNode.addChildNode(ambientLightNode)
        
        let context = try makeContext()
        let renderer = MTISCNSceneRenderer(device: context.device)
        renderer.scene = scene
        renderer.scnRenderer.pointOfView = cameraNode
        let image = renderer.snapshot(atTime: CFAbsoluteTimeGetCurrent(), viewport: CGRect(x: 0, y: 0, width: 32, height: 32), pixelFormat: .unspecified, isOpaque: true)
        let sRGBImage = MTILinearToSRGBToneCurveFilter.image(byProcessingImage: image)
        let output = try context.makeCGImage(from: sRGBImage)
        PixelEnumerator.enumeratePixels(in: output) { (pixel, coord) in
            XCTAssert(pixel.r == 0 && pixel.g == 0 && pixel.b == 128 && pixel.a == 255)
        }
    }
    
    func testSCNSceneRender_msaa() throws {
        let scene = SCNScene()
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 16)
        
        let cubeNode = SCNNode()
        cubeNode.geometry = SCNBox(width: 8, height: 8, length: 8, chamferRadius: 0)
        cubeNode.geometry?.firstMaterial?.lightingModel = .constant
        var color: [CGFloat] = [1,1,1,1]
        cubeNode.geometry?.firstMaterial?.diffuse.contents = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: &color)!
        cubeNode.position = SCNVector3(x: 0, y: 0, z: 0)
        cubeNode.rotation = SCNVector4(x: 0, y: 0, z: 1, w: .pi/4)
        scene.rootNode.addChildNode(cubeNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        var whiteColor: [CGFloat] = [1,1,1,1]
        ambientLightNode.light!.color = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: &whiteColor)!
        scene.rootNode.addChildNode(ambientLightNode)
        
        let context = try makeContext()
        
        let renderer = MTISCNSceneRenderer(device: context.device)
        renderer.scene = scene
        renderer.scnRenderer.pointOfView = cameraNode
        do {
            // With MSAA
            renderer.antialiasingMode = .multisampling4X
            let image = renderer.snapshot(atTime: 0, viewport: CGRect(x: 0, y: 0, width: 4, height: 4), pixelFormat: .unspecified, isOpaque: false).unpremultiplyingAlpha()
            let sRGBImage = MTILinearToSRGBToneCurveFilter.image(byProcessingImage: image)
            let output = try context.makeCGImage(from: sRGBImage)
            let result: [PixelEnumerator.Coordinates: PixelEnumerator.Pixel] = [
                PixelEnumerator.Coordinates(x: 0, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 2): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 0, y: 2): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 2, y: 2): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                PixelEnumerator.Coordinates(x: 1, y: 2): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                PixelEnumerator.Coordinates(x: 3, y: 1): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 2, y: 1): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                PixelEnumerator.Coordinates(x: 0, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 3): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 3, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 1, y: 3): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 1, y: 1): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                PixelEnumerator.Coordinates(x: 1, y: 0): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 2, y: 0): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 0, y: 1): PixelEnumerator.Pixel(b: 64, g: 64, r: 64, a: 64),
                PixelEnumerator.Coordinates(x: 3, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0)]
            PixelEnumerator.enumeratePixels(in: output) { (pixel, coord) in
                XCTAssert(result[coord] == pixel)
            }
        } catch {
            throw error
        }
        
        do {
            // Without MSAA
            renderer.antialiasingMode = .none
            let image = renderer.snapshot(atTime: 0, viewport: CGRect(x: 0, y: 0, width: 4, height: 4), pixelFormat: .unspecified, isOpaque: false).unpremultiplyingAlpha()
            let sRGBImage = MTILinearToSRGBToneCurveFilter.image(byProcessingImage: image)
            let output = try context.makeCGImage(from: sRGBImage)
            let result: [PixelEnumerator.Coordinates: PixelEnumerator.Pixel] = [
                PixelEnumerator.Coordinates(x: 0, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 2): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 0, y: 2): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 2): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                PixelEnumerator.Coordinates(x: 1, y: 2): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                PixelEnumerator.Coordinates(x: 3, y: 1): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 1): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                PixelEnumerator.Coordinates(x: 0, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 1, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 1, y: 1): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                PixelEnumerator.Coordinates(x: 1, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 2, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 0, y: 1): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                PixelEnumerator.Coordinates(x: 3, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0)]
            PixelEnumerator.enumeratePixels(in: output) { (pixel, coord) in
                XCTAssert(result[coord] == pixel)
            }
        } catch {
            throw error
        }
    }
    
    func testSCNSceneRender_msaa_pixelbuffer() throws {
        let scene = SCNScene()
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 16)
        
        let cubeNode = SCNNode()
        cubeNode.geometry = SCNBox(width: 8, height: 8, length: 8, chamferRadius: 0)
        cubeNode.geometry?.firstMaterial?.lightingModel = .constant
        var color: [CGFloat] = [1,1,1,1]
        cubeNode.geometry?.firstMaterial?.diffuse.contents = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: &color)!
        cubeNode.position = SCNVector3(x: 0, y: 0, z: 0)
        cubeNode.rotation = SCNVector4(x: 0, y: 0, z: 1, w: .pi/4)
        scene.rootNode.addChildNode(cubeNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        var whiteColor: [CGFloat] = [1,1,1,1]
        ambientLightNode.light!.color = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: &whiteColor)!
        scene.rootNode.addChildNode(ambientLightNode)
        
        let context = try makeContext()
        
        let renderer = MTISCNSceneRenderer(device: context.device)
        renderer.scene = scene
        renderer.scnRenderer.pointOfView = cameraNode
        do {
            // With MSAA
            let expection = XCTestExpectation()
            renderer.antialiasingMode = .multisampling4X
            try renderer.render(atTime: 0, viewport: CGRect(x: 0, y: 0, width: 4, height: 4), sRGB: true) { pixelBuffer in
                var cgImage: CGImage!
                VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
                // Quarter-covered white is blended in linear space, then sRGB-encoded to byte 137.
                let result: [PixelEnumerator.Coordinates: PixelEnumerator.Pixel] = [
                    PixelEnumerator.Coordinates(x: 0, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 3, y: 2): PixelEnumerator.Pixel(b: 137, g: 137, r: 137, a: 64),
                    PixelEnumerator.Coordinates(x: 0, y: 2): PixelEnumerator.Pixel(b: 137, g: 137, r: 137, a: 64),
                    PixelEnumerator.Coordinates(x: 2, y: 2): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                    PixelEnumerator.Coordinates(x: 1, y: 2): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                    PixelEnumerator.Coordinates(x: 3, y: 1): PixelEnumerator.Pixel(b: 137, g: 137, r: 137, a: 64),
                    PixelEnumerator.Coordinates(x: 2, y: 1): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                    PixelEnumerator.Coordinates(x: 0, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 2, y: 3): PixelEnumerator.Pixel(b: 137, g: 137, r: 137, a: 64),
                    PixelEnumerator.Coordinates(x: 3, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 1, y: 3): PixelEnumerator.Pixel(b: 137, g: 137, r: 137, a: 64),
                    PixelEnumerator.Coordinates(x: 1, y: 1): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                    PixelEnumerator.Coordinates(x: 1, y: 0): PixelEnumerator.Pixel(b: 137, g: 137, r: 137, a: 64),
                    PixelEnumerator.Coordinates(x: 2, y: 0): PixelEnumerator.Pixel(b: 137, g: 137, r: 137, a: 64),
                    PixelEnumerator.Coordinates(x: 0, y: 1): PixelEnumerator.Pixel(b: 137, g: 137, r: 137, a: 64),
                    PixelEnumerator.Coordinates(x: 3, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0)]
                PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coord) in
                    XCTAssert(result[coord] == pixel)
                }
                expection.fulfill()
            }
            wait(for: [expection], timeout: 1)
        } catch {
            throw error
        }
        
        do {
            let expection = XCTestExpectation()
            renderer.antialiasingMode = .none
            try renderer.render(atTime: 0, viewport: CGRect(x: 0, y: 0, width: 4, height: 4), sRGB: true) { pixelBuffer in
                var cgImage: CGImage!
                VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
                let result: [PixelEnumerator.Coordinates: PixelEnumerator.Pixel] = [
                    PixelEnumerator.Coordinates(x: 0, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 3, y: 2): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 0, y: 2): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 2, y: 2): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                    PixelEnumerator.Coordinates(x: 1, y: 2): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                    PixelEnumerator.Coordinates(x: 3, y: 1): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 2, y: 1): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                    PixelEnumerator.Coordinates(x: 0, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 2, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 3, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 1, y: 3): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 1, y: 1): PixelEnumerator.Pixel(b: 255, g: 255, r: 255, a: 255),
                    PixelEnumerator.Coordinates(x: 1, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 2, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 0, y: 1): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0),
                    PixelEnumerator.Coordinates(x: 3, y: 0): PixelEnumerator.Pixel(b: 0, g: 0, r: 0, a: 0)]
                PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coord) in
                    XCTAssert(result[coord] == pixel)
                }
                expection.fulfill()
            }
            wait(for: [expection], timeout: 1)
        } catch {
            throw error
        }
    }
    
    func testYCbCrTextureSupport() throws {
        let context = try makeContext()
        if context.isYCbCrPixelFormatSupported {
            let blueImage = MTIImage(color: MTIColor(red: 0, green: 0, blue: 1, alpha: 1), sRGB: false, size: CGSize(width: 4, height: 4))
            var pixelBuffer: CVPixelBuffer!
            CVPixelBufferCreate(kCFAllocatorDefault, 4, 4, kCVPixelFormatType_420YpCbCr10BiPlanarFullRange, [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &pixelBuffer)
            CVBufferSetAttachment(pixelBuffer, kCVImageBufferCGColorSpaceKey, CGColorSpace(name: CGColorSpace.sRGB)!, .shouldPropagate)
            try context.render(blueImage, to: pixelBuffer)
            var cgImage: CGImage!
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
            var pixels: [UInt8] = [UInt8](repeating: 0, count: 4 * 4 * 4)
            let cgContext = CGContext(data: &pixels, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 4 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
            cgContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: 4, height: 4))
            for i in 0..<pixels.count {
                if i % 4 == 0 {
                    XCTAssertLessThanOrEqual(abs(Int(pixels[i]) - 255), 1) //b
                    XCTAssert(pixels[i + 1] == 0) //g
                    XCTAssert(pixels[i + 2] == 0) //r
                    XCTAssert(pixels[i + 3] == 255) //a
                }
            }
        }
    }
    
    func testLinearToSRGB() throws {
        let inputValue: Float = 128.0/255.0
        let image = MTIImage(color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 1), sRGB: false, size: CGSize(width: 1, height: 1))
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(image, from: .linearSRGB, to: .sRGB, alphaType: .nonPremultiplied, pixelFormat: .unspecified)
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(round(
                    ((c < 0.0031308) ? (12.92 * c) : (1.055 * pow(c, 1.0/2.4) - 0.055)) * 255.0
                ))
                XCTAssert(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }
    
    func testLinearToSRGB_outputPremultipliedAlpha() throws {
        let inputValue: Float = 128.0/255.0
        let image = MTIImage(color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 0.5), sRGB: false, size: CGSize(width: 1, height: 1))
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(image, from: .linearSRGB, to: .sRGB, alphaType: .premultiplied, pixelFormat: .unspecified)
        XCTAssert(outputImage.alphaType == .premultiplied)
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        
        func linearToSRGB(_ c: Float, alpha: Float) -> Float {
            let v = ((c < 0.0031308) ? (12.92 * c) : (1.055 * pow(c, 1.0/2.4) - 0.055))
            return v * 255.0 * alpha //cgImage has premultiplied alpha
        }
        
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(round(linearToSRGB(c, alpha: 0.5)))
                XCTAssert(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 128)
            }
        }
    }
    
    func testLinearToSRGB_inputPremultipliedAlpha() throws {
        let image = MTIImage(bitmapData: Data([64,64,64,128]), width: 1, height: 1, bytesPerRow: 4, pixelFormat: .bgra8Unorm, alphaType: .premultiplied)
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(image, from: .linearSRGB, to: .sRGB, alphaType: .nonPremultiplied, pixelFormat: .unspecified)
        XCTAssert(outputImage.alphaType == .nonPremultiplied)
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
      
        func linearToSRGB(_ c: Float, alpha: Float) -> Float {
            let v = ((c < 0.0031308) ? (12.92 * c) : (1.055 * pow(c, 1.0/2.4) - 0.055))
            return v * 255.0 * alpha //cgImage has premultiplied alpha
        }
        
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                let c: Float = 128.0/255.0
                let value = UInt8(round(linearToSRGB(c, alpha: 0.5)))
                XCTAssert(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 128)
            }
        }
    }
    
    func testSRGBToLinear() throws {
        let inputValue: Float = 128.0/255.0
        let image = MTIImage(color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 1), sRGB: false, size: CGSize(width: 1, height: 1))
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(image, from: .sRGB, to: .linearSRGB, alphaType: .nonPremultiplied, pixelFormat: .unspecified)
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(round((c <= 0.04045) ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) * 255.0))
                XCTAssert(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }
    
    func testLinearToLinear() throws {
        let inputValue: Float = 128.0/255.0
        let image = MTIImage(color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 1), sRGB: false, size: CGSize(width: 1, height: 1))
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(image, from: .linearSRGB, to: .linearSRGB, alphaType: .nonPremultiplied, pixelFormat: .unspecified)
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(c * 255.0)
                XCTAssert(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }
    
    func testSRGBToSRGB() throws {
        let inputValue: Float = 128.0/255.0
        let image = MTIImage(color: MTIColor(red: inputValue, green: inputValue, blue: inputValue, alpha: 1), sRGB: false, size: CGSize(width: 1, height: 1))
        let outputImage = MTIRGBColorSpaceConversionFilter.convert(image, from: .sRGB, to: .sRGB, alphaType: .nonPremultiplied, pixelFormat: .unspecified)
        let context = try makeContext()
        let cgImage = try context.makeCGImage(from: outputImage)
        PixelEnumerator.enumeratePixels(in: cgImage) { (pixel, coordinates) in
            if coordinates.x == 0 && coordinates.y == 0 {
                let c = inputValue
                let value = UInt8(c * 255.0)
                XCTAssert(pixel.r == value && pixel.g == value && pixel.b == value && pixel.a == 255)
            }
        }
    }
    
    @available(iOS 13.0, tvOS 13.0, *)
    func testRoundCornerFilter_circular() throws {
        try runRoundCornerTest(size: 32, curve: .circular, allowedDifference: 64)
    }
    
    @available(iOS 13.0, tvOS 13.0, *)
    func testRoundCornerFilter_continuous() throws {
        try runRoundCornerTest(size: 32, curve: .continuous, allowedDifference: 64)
    }
    
    func testMultilayerCompositing_roundCorner_circular() throws {
        let image = try XCTUnwrap(MTIImage.white.resized(to: CGSize(width: 32, height: 32)))
        let roundCornerFilter = MTIRoundCornerFilter()
        roundCornerFilter.cornerRadius = MTICornerRadius(16)
        roundCornerFilter.cornerCurve = .circular
        roundCornerFilter.inputImage = image
        let roundImage = try XCTUnwrap(roundCornerFilter.outputImage)
        
        let multilayerCompositingFilter = MultilayerCompositingFilter()
        multilayerCompositingFilter.inputBackgroundImage = MTIImage(color: .clear, sRGB: false, size: CGSize(width: 64, height: 64))
        multilayerCompositingFilter.layers = [MultilayerCompositingFilter.Layer(content: image).frame(CGRect(x: 32, y: 32, width: 32, height: 32), layoutUnit: .pixel).corner(radius: MTICornerRadius(16), curve: .circular)]
        let compositedImage = try XCTUnwrap(multilayerCompositingFilter.outputImage)
        
        let context = try makeContext()
        let roundCornerFilterOutput = try context.makeCGImage(from: roundImage)
        let multilayerCompositingFilterOutput = try context.makeCGImage(from: XCTUnwrap(compositedImage.cropped(to: CGRect(x: 32, y: 32, width: 32, height: 32))))
        
        XCTAssert(roundCornerFilterOutput.dataProvider?.data == multilayerCompositingFilterOutput.dataProvider?.data)
    }
    
    func testMultilayerCompositing_roundCorner_continuous() throws {
        let image = try XCTUnwrap(MTIImage.white.resized(to: CGSize(width: 32, height: 32)))
        let roundCornerFilter = MTIRoundCornerFilter()
        roundCornerFilter.cornerRadius = MTICornerRadius(8)
        roundCornerFilter.cornerCurve = .continuous
        roundCornerFilter.inputImage = image
        let roundImage = try XCTUnwrap(roundCornerFilter.outputImage)
        
        let multilayerCompositingFilter = MultilayerCompositingFilter()
        multilayerCompositingFilter.inputBackgroundImage = MTIImage(color: .clear, sRGB: false, size: CGSize(width: 64, height: 64))
        multilayerCompositingFilter.layers = [MultilayerCompositingFilter.Layer(content: image).frame(CGRect(x: 32, y: 32, width: 32, height: 32), layoutUnit: .pixel).corner(radius: MTICornerRadius(8), curve: .continuous)]
        let compositedImage = try XCTUnwrap(multilayerCompositingFilter.outputImage)
        
        let context = try makeContext()
        let roundCornerFilterOutput = try context.makeCGImage(from: roundImage)
        let multilayerCompositingFilterOutput = try context.makeCGImage(from: XCTUnwrap(compositedImage.cropped(to: CGRect(x: 32, y: 32, width: 32, height: 32))))
        
        XCTAssert(roundCornerFilterOutput.dataProvider?.data == multilayerCompositingFilterOutput.dataProvider?.data)
    }
    
    func testMultilayerCompositing_roundCorner_none() throws {
        let image = try XCTUnwrap(MTIImage.white.resized(to: CGSize(width: 32, height: 32)))
        let multilayerCompositingFilter = MultilayerCompositingFilter()
        multilayerCompositingFilter.inputBackgroundImage = MTIImage(color: .clear, sRGB: false, size: CGSize(width: 64, height: 64))
        multilayerCompositingFilter.layers = [MultilayerCompositingFilter.Layer(content: image).frame(CGRect(x: 32, y: 32, width: 32, height: 32), layoutUnit: .pixel).corner(radius: MTICornerRadius(0), curve: .continuous)]
        let compositedImage = try XCTUnwrap(multilayerCompositingFilter.outputImage)
        let context = try makeContext()
        let roundCornerFilterOutput = try context.makeCGImage(from: image)
        let multilayerCompositingFilterOutput = try context.makeCGImage(from: XCTUnwrap(compositedImage.cropped(to: CGRect(x: 32, y: 32, width: 32, height: 32))))
        XCTAssert(roundCornerFilterOutput.dataProvider?.data == multilayerCompositingFilterOutput.dataProvider?.data)
    }
    
    func testZeroSizeImage_failure() throws {
        let image = MTIImage(color: .white, sRGB: false, size: .zero)
        let context = try makeContext()
        do {
            try context.startTask(toRender: image, completion: nil)
            XCTFail()
        } catch {
            XCTAssert((error as? MTIError)?.code == .invalidTextureDimension)
        }
    }
    
    func testZeroSizeImage_filter_failure() throws {
        let image = MTIImage(color: .white, sRGB: false, size: CGSize(width: 1, height: 1))
        let intermediate = MTIRenderPipelineKernel.passthrough.apply(to: [image], parameters: [:], outputDimensions: MTITextureDimensions(width: 1, height: 0, depth: 1), outputPixelFormat: .unspecified)
        let output = MTIRenderPipelineKernel.passthrough.apply(to: [intermediate], parameters: [:], outputDimensions: MTITextureDimensions(width: 1, height: 1, depth: 1), outputPixelFormat: .unspecified)
        let context = try makeContext()
        do {
            try context.startTask(toRender: output, completion: nil)
            XCTFail()
        } catch {
            XCTAssert((error as? MTIError)?.code == .invalidTextureDimension)
        }
    }
}

extension RenderTests {

    private enum Task6BlendPath: String, CaseIterable {
        case individual
        case multilayer
    }

    private func canonicalBlendModes() -> [MTIBlendMode] {
        MTIBlendModes.all
            .filter { $0 != .colorLookup512x512 }
            .sorted { $0.rawValue < $1.rawValue }
    }

    private func legacyBlendGoldens() -> [String: SIMD4<Float>] {
        [
            "Add": SIMD4<Float>(1, 1, 1, 1),
            "Color": SIMD4<Float>(1, 1, 1, 1),
            "ColorBurn": SIMD4<Float>(1, 1, 0, 1),
            "ColorDodge": SIMD4<Float>(1, 1, 1, 1),
            "Darken": SIMD4<Float>(0.5, 0.25, 0.25, 1),
            "DarkerColor": SIMD4<Float>(0.5, 0.25, 0.75, 1),
            "Difference": SIMD4<Float>(1, 1, 0.5, 1),
            "Divide": SIMD4<Float>(1, 1, 0.33325195, 1),
            "Exclusion": SIMD4<Float>(0.5, 1, 0.625, 1),
            "HardLight": SIMD4<Float>(1, 0.75, 0.625, 1),
            "HardMix": SIMD4<Float>(1, 1, 0.5, 1),
            "Hue": SIMD4<Float>(1, 1, 1, 1),
            "Lighten": SIMD4<Float>(1, 1, 0.75, 1),
            "LighterColor": SIMD4<Float>(1, 1, 0.25, 1),
            "LinearBurn": SIMD4<Float>(1, 0.75, 0, 1),
            "LinearLight": SIMD4<Float>(1, 1, 0.75, 1),
            "Luminosity": SIMD4<Float>(0.53125, 0.37939453, 0, 1),
            "Multiply": SIMD4<Float>(1, 0.375, 0.1875, 1),
            "Normal": SIMD4<Float>(0.5, 0.25, 0.75, 1),
            "Overlay": SIMD4<Float>(1, 1, 0.375, 1),
            "PinLight": SIMD4<Float>(1, 0.5, 0.5, 1),
            "Saturation": SIMD4<Float>(1, 1, 1, 1),
            "Screen": SIMD4<Float>(1, 1, 0.8125, 1),
            "SoftLight": SIMD4<Float>(1, 1, 0.375, 1),
            "Subtract": SIMD4<Float>(1, 1, 0, 1),
            "VividLight": SIMD4<Float>(1, 1, 0.5, 1),
        ]
    }

    private func renderBlendPixel(
        mode: MTIBlendMode,
        backdrop: MTIImage,
        source: MTIImage,
        headroom: Float?,
        path: Task6BlendPath,
        outputAlphaType: MTIAlphaType = .nonPremultiplied,
        destinationAlphaType: MTIAlphaType = .alphaIsOne,
        context: MTIContext
    ) throws -> SIMD4<Float> {
        let output: MTIImage
        switch path {
        case .individual:
            let filter = MTIBlendFilter(blendMode: mode)
            filter.inputBackgroundImage = backdrop
            filter.inputImage = source
            if let headroom = headroom {
                filter.headroom = headroom
            }
            filter.outputAlphaType = outputAlphaType
            filter.outputPixelFormat = .rgba16Float
            output = try XCTUnwrap(filter.outputImage)
        case .multilayer:
            let filter = MultilayerCompositingFilter()
            filter.inputBackgroundImage = backdrop
            filter.layers = [.init(content: source).blendMode(mode)]
            if let headroom = headroom {
                filter.headroom = headroom
            }
            filter.outputAlphaType = outputAlphaType
            filter.outputPixelFormat = .rgba16Float
            output = try XCTUnwrap(filter.outputImage)
        }
        return try XCTUnwrap(renderFloatPixels(
            output,
            width: 1,
            height: 1,
            context: context,
            destinationAlphaType: destinationAlphaType
        ).first)
    }

    private func assertPixel(
        _ actual: SIMD4<Float>,
        equals expected: SIMD4<Float>,
        accuracy: Float,
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.x, expected.x, accuracy: accuracy, "\(message) red", file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: accuracy, "\(message) green", file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: accuracy, "\(message) blue", file: file, line: line)
        XCTAssertEqual(actual.w, expected.w, accuracy: accuracy, "\(message) alpha", file: file, line: line)
    }

    private func claheFixture(headroom: Float) -> MTIImage {
        let pixels = (0..<64).map { index -> SIMD4<Float> in
            let value = Float(index + 1) / 64 * headroom
            return SIMD4<Float>(value, value, value, 1)
        }
        return floatImage(pixels, width: 8, height: 8)
    }

    private func claheChromaticFixture(headroom: Float) -> MTIImage {
        let pixels = (0..<64).map { index -> SIMD4<Float> in
            let x = index % 8
            let y = index / 8
            let red = Float(x + 1) / 9
            let green = Float(y + 1) / 9
            let blue = Float((x * 3 + y * 5) % 8 + 1) / 9
            return SIMD4<Float>(red * headroom, green * headroom, blue * headroom, 1)
        }
        return floatImage(pixels, width: 8, height: 8)
    }

    private func resolvedBufferAndTexture(
        for image: MTIImage,
        context: MTIContext
    ) throws -> (buffer: MTIImage, texture: MTLTexture) {
        let task = try context.startTask(toRender: image, completion: nil)
        task.waitUntilCompleted()
        if let error = task.error {
            throw error
        }
        let buffer = try XCTUnwrap(context.renderedBuffer(for: image))
        let texture = try XCTUnwrap(buffer.value(forKeyPath: "promise.resolution.renderTarget.texture") as? MTLTexture)
        return (buffer, texture)
    }

    private func floatImage(
        _ pixels: [SIMD4<Float>],
        width: Int,
        height: Int,
        alphaType: MTIAlphaType = .alphaIsOne
    ) -> MTIImage {
        precondition(pixels.count == width * height)
        let data = pixels.withUnsafeBytes { Data($0) }
        return MTIImage(
            bitmapData: data,
            width: UInt(width),
            height: UInt(height),
            bytesPerRow: UInt(width * MemoryLayout<SIMD4<Float>>.stride),
            pixelFormat: .rgba32Float,
            alphaType: alphaType
        )
    }

    private func renderFloatPixels(
        _ image: MTIImage,
        width: Int,
        height: Int,
        context: MTIContext,
        destinationAlphaType: MTIAlphaType = .alphaIsOne
    ) throws -> [SIMD4<Float>] {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let texture = try XCTUnwrap(context.device.makeTexture(descriptor: descriptor))
        let task = try context.startTask(
            toRender: image,
            to: texture,
            destinationAlphaType: destinationAlphaType
        )
        task.waitUntilCompleted()
        if let error = task.error {
            throw error
        }
        var pixels = [SIMD4<Float>](repeating: .zero, count: width * height)
        pixels.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: width * MemoryLayout<SIMD4<Float>>.stride,
                from: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0
            )
        }
        return pixels
    }

    private func readBGRA8Pixels(from texture: MTLTexture, context: MTIContext) throws -> [UInt8] {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        #if os(macOS) || targetEnvironment(macCatalyst)
        descriptor.storageMode = .managed
        #endif
        let cpuTexture = try XCTUnwrap(context.device.makeTexture(descriptor: descriptor))
        let commandBuffer = try XCTUnwrap(context.commandQueue.makeCommandBuffer())
        let encoder = try XCTUnwrap(commandBuffer.makeBlitCommandEncoder())
        encoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: .init(x: 0, y: 0, z: 0),
            sourceSize: .init(width: texture.width, height: texture.height, depth: 1),
            to: cpuTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: .init(x: 0, y: 0, z: 0)
        )
        #if os(macOS) || targetEnvironment(macCatalyst)
        encoder.synchronize(resource: cpuTexture)
        #endif
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error {
            throw error
        }
        var pixels = [UInt8](repeating: 0, count: texture.width * texture.height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            cpuTexture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: texture.width * 4,
                from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0
            )
        }
        return pixels
    }
    
    @available(iOS 13.0, tvOS 13.0, *)
    private func runRoundCornerTest(size: Int, curve: MTICornerCurve, allowedDifference: Int) throws {
        let objectSize: Int = size
        let cgContext = try XCTUnwrap(CGContext(data: nil, width: objectSize, height: objectSize, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue))
        cgContext.setFillColor(CGColor.mti_white)
        cgContext.fill(CGRect(x: 0, y: 0, width: objectSize, height: objectSize))
        let whiteImage = try XCTUnwrap(cgContext.makeImage())
        let inputImage = MTIImage(cgImage: whiteImage, isOpaque: true)
        let context = try makeContext()
        for i in 0...objectSize/2 {
            let filter = MTIRoundCornerFilter()
            filter.inputImage = inputImage
            filter.cornerRadius = MTICornerRadius(Float(i))
            filter.cornerCurve = curve
            let output = try XCTUnwrap(filter.outputImage)
            cgContext.clear(CGRect(x: 0, y: 0, width: objectSize, height: objectSize))
            cgContext.draw((try context.makeCGImage(from: output)), in: CGRect(x: 0, y: 0, width: objectSize, height: objectSize))
            let outputCGImage = try XCTUnwrap(cgContext.makeImage())
            
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: objectSize, height: objectSize)
            layer.cornerRadius = CGFloat(i)
            switch curve {
            case .circular:
                layer.cornerCurve = .circular
            case .continuous:
                layer.cornerCurve = .continuous
            @unknown default:
                XCTFail()
            }
            layer.backgroundColor = CGColor.mti_white
            cgContext.clear(CGRect(x: 0, y: 0, width: objectSize, height: objectSize))
            layer.render(in: cgContext)
            let outputLayerImage = try XCTUnwrap(cgContext.makeImage())
            
            XCTAssert(outputCGImage.bytesPerRow == outputLayerImage.bytesPerRow)
            
            let outputImageData = try [UInt8](UnsafeBufferPointer<UInt8>(start: CFDataGetBytePtr(XCTUnwrap(outputCGImage.dataProvider?.data))!, count: outputCGImage.bytesPerRow * outputCGImage.height))
            let outputLayerData = try [UInt8](UnsafeBufferPointer<UInt8>(start: CFDataGetBytePtr(XCTUnwrap(outputLayerImage.dataProvider?.data))!, count: outputLayerImage.bytesPerRow * outputLayerImage.height))
            for (index, value) in outputImageData.enumerated() {
                let diff = abs(Int(value) - Int(outputLayerData[index]))
                XCTAssert(diff < allowedDifference)
            }
        }
    }
    
    private func fetchFirstPixel(from texture: MTLTexture, context: MTIContext) throws -> [UInt8] {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)
        #if os(macOS) || targetEnvironment(macCatalyst)
        textureDescriptor.storageMode = .managed
        #endif
        let cpuTexture = try XCTUnwrap(context.device.makeTexture(descriptor: textureDescriptor))
        let commandBuffer = try XCTUnwrap(context.commandQueue.makeCommandBuffer())
        let blitEncoder = try XCTUnwrap(commandBuffer.makeBlitCommandEncoder())
        blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: 1, height: 1, depth: 1), to: cpuTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        #if os(macOS) || targetEnvironment(macCatalyst)
        blitEncoder.synchronize(resource: cpuTexture)
        #endif
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        var pixels = [UInt8](repeating: 0, count: 4)
        pixels.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> Void in
            cpuTexture.getBytes(ptr.baseAddress!, bytesPerRow: 4, from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: 1, height: 1, depth: 1)), mipmapLevel: 0)
        }
        return pixels
    }
}
