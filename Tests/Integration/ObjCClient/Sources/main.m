#import <Metal/Metal.h>
#import <MetalPetal/MetalPetal.h>

int main(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSError *error = nil;
    MTIContext *context = [[MTIContext alloc] initWithDevice:device options:nil error:&error];
    if (!context || error) {
        return 1;
    }

    MTIBlendFilter *blend = [[MTIBlendFilter alloc] initWithBlendMode:MTIBlendModeNormal];
    if (blend.headroom != 1) {
        return 2;
    }
    blend.headroom = 4;
    if (blend.headroom != 4) {
        return 3;
    }

    MTIMultilayerCompositingFilter *multilayer = [[MTIMultilayerCompositingFilter alloc] init];
    if (multilayer.headroom != 1) {
        return 4;
    }
    multilayer.headroom = 4;
    if (multilayer.headroom != 4) {
        return 5;
    }

    MTICLAHEFilter *clahe = [[MTICLAHEFilter alloc] init];
    if (clahe.headroom != 1) {
        return 6;
    }
    clahe.headroom = 4;
    return clahe.headroom == 4 ? 0 : 7;
}
