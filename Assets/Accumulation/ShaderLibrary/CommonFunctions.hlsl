#ifndef CommonFunction
#define CommonFunction

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "./LightingRefFunction.hlsl"

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

float3 NDCNormalized(float4 clip)
{
    float3 idx = clip.xyz / clip.w;
    idx.xy = idx.xy * 0.5 + 0.5;
    idx.y = 1 - idx.y;
    //idx.z = 1-idx.z;
    //idx.z = idx.z < 0 || idx.z>1?  1 - idx.z: idx.z;
    return idx;
}

inline float3 HunpackNormal(float3 normalMap)
{
    float3 normalRes;
    normalRes.xy = normalMap.xy * 2 - 1;
    normalRes.z = sqrt(1 - saturate(dot(normalRes.xy, normalRes.xy)));
    return normalRes;
}

InputData InitInputData(float3 worldPos, float3 normalWS, float3 viewDir, float3 ambient)
{
    InputData data = (InputData)1;
    data.positionWS = worldPos;
    data.normalWS = normalWS;
    data.viewDirectionWS = normalize(viewDir);
    data.bakedGI = ambient;

    return data;
}


float4 DesolveColor(sampler2D noiseTex,float2 uv,float desolveValue,float4 desolveColor,float4 baseColor,float range = 0.05f)
{
    float desolve = tex2D(noiseTex,uv).x;
    float cutValue = desolveValue - desolve;
    clip(cutValue);
    clip(desolve - 0.05);
    if (abs(cutValue) < range)
    {
        baseColor = desolveColor;
    }
    return baseColor;
}




#endif