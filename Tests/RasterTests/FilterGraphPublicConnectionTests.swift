import XCTest
import Raster

final class FilterGraphPublicConnectionTests: XCTestCase {
    func testPublicConnectBuildsAFilterGraph() {
        let input = MTIImage(
            color: MTIColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1),
            sRGB: false,
            size: CGSize(width: 2, height: 2)
        )
        let filter = MTISaturationFilter()

        let output = FilterGraph.makeImage { output in
            input.outputPort.connect(to: filter.inputPorts.inputImage)
            filter.outputPort.connect(to: output)
        }

        XCTAssertNotNil(output)
    }
}
