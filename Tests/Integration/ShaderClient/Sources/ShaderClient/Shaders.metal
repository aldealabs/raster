#include <metal_stdlib>
#include <MetalPetal/MTIShaderLib.h>
using namespace metal;

fragment float4 shaderClientPassthrough(
    metalpetal::VertexOut vertexIn [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]]
) {
    constexpr sampler s(coord::normalized);
    return colorTexture.sample(s, vertexIn.textureCoordinate);
}
