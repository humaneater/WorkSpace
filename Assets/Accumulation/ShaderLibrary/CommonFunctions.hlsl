#ifndef CommonFunction
#define CommonFunction

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"


float3 GetWorldPositionByDepth(float2 uv, float depth)
{
    #if !UNITY_REVERSED_Z
    // 调整 z 以匹配 OpenGL 的 NDC
    depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, depth);
    #endif
    float4 ndcSpace = ComputeClipSpacePosition(uv, depth);
    ndcSpace = mul(UNITY_MATRIX_I_VP, ndcSpace);
    //ndcSpace.z *= -1;
    ndcSpace /= ndcSpace.w;
    return ndcSpace.xyz;
}

float Unity_Dither_float4(float4 ScreenPosition)
{
    uint2 uv = ScreenPosition.xy;
    float DITHER_THRESHOLDS[16] =
    {
        1.0 / 17.0, 9.0 / 17.0, 3.0 / 17.0, 11.0 / 17.0,
        13.0 / 17.0, 5.0 / 17.0, 15.0 / 17.0, 7.0 / 17.0,
        4.0 / 17.0, 12.0 / 17.0, 2.0 / 17.0, 10.0 / 17.0,
        16.0 / 17.0, 8.0 / 17.0, 14.0 / 17.0, 6.0 / 17.0
    };
    uint index = (uint(uv.x) % 4) * 4 + uint(uv.y) % 4;
    return DITHER_THRESHOLDS[index];
}




#endif