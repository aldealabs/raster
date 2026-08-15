import Metal
import MetalPetal

let device = MTLCreateSystemDefaultDevice()!
let context = try MTIContext(device: device)
let image = MTIImage(
    color: MTIColor(red: 1, green: 0, blue: 0, alpha: 1),
    sRGB: false,
    size: CGSize(width: 1, height: 1)
)
_ = try context.makeCGImage(from: image)

let multilayer = MultilayerCompositingFilter()
precondition(multilayer.headroom == 1)
multilayer.headroom = 4
precondition(multilayer.headroom == 4)
