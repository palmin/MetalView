//
//  MyShader.metal
//  CameraTest
//
//  Created by Anders Borum on 22/11/2024.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[position]];
    float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexMain(uint vertexID [[vertex_id]]) {
    VertexOut out;

    // Define a full-screen quad with positions and texture coordinates
    float4 positions[] = {
        float4(-1.0, -1.0, 0.0, 1.0),
        float4( 1.0, -1.0, 0.0, 1.0),
        float4(-1.0,  1.0, 0.0, 1.0),
        float4( 1.0,  1.0, 0.0, 1.0),
    };
    float2 texCoords[] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0),
    };

    out.position = positions[vertexID];
    out.texCoord = texCoords[vertexID];
    return out;
}

// Simulated chrome-like environment reflection
fragment float4 textureFragment(VertexOut in [[stage_in]], texture2d<float> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler(coord::normalized, address::clamp_to_edge, filter::linear);

    // Rotate texture coordinates 90 degrees
    float2 rotatedTexCoord = float2(in.texCoord.y, in.texCoord.x);

    // Simulate a curved reflective surface
    float2 reflectedTexCoord = float2(
        0.5 + 0.5 * sin(rotatedTexCoord.x * 3.14159),  // Simulate curvature horizontally
        0.5 + 0.5 * cos(rotatedTexCoord.y * 3.14159)   // Simulate curvature vertically
    );
    
    // Sample the texture based on the reflected coordinates
    float4 textureColor = colorTexture.sample(textureSampler, reflectedTexCoord);

    // Desaturate the texture color for a metallic look
    float gray = dot(textureColor.rgb, float3(0.3, 0.59, 0.11));  // Weighted average for luminance
    float3 desaturatedColor = mix(textureColor.rgb, float3(gray), 0.8);  // Adjust desaturation factor (0.0 - 1.0)

    // Move the highlight up and to the right
    float2 center = float2(0.2, 0.7);  // Light source is offset
    float distanceFromCenter = length(rotatedTexCoord - center);
    float highlight = smoothstep(0.4, 0.0, distanceFromCenter);  // Create a soft circular highlight

    // Combine the desaturated color with the highlight for a shiny look
    float3 chromeColor = mix(desaturatedColor, float3(1.0), highlight);  // Blend towards white for highlights

    // Increase brightness of the final color
    chromeColor = min(0.3 + chromeColor * 1.1, float3(1.0));  // Scale brightness (factor: 2.0)

    return float4(chromeColor, 1.0);  // Output the final color
}
