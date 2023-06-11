#ifndef LightingRefFunction
#define LightingRefFunction

#define HGetWorldNormal(v2fData) (float3(v2fData.tToW[0].z,v2fData.tToW[1].z,v2fData.tToW[2].z))
#define HGetWorldPos(v2fData)       (float3( (v2fData).tToW[0].w, (v2fData).tToW[1].w, (v2fData).tToW[2].w ))
#define HGetWorldPosTBN(v2fData)       (float3( (v2fData).tbn[0].w, (v2fData).tbn[1].w, (v2fData).tbn[2].w ))

struct LightsInfo
{
    float4 color;
    float4 position;
    float4 direction;
    float4 attenuation;
};

inline SurfaceData InitSurfaceData(float3 albedo,float metallic,float roughness,float3 normalTS)
{
    SurfaceData data = (SurfaceData)0;
    data.albedo = albedo;
    data.alpha = 1;
    data.metallic = metallic;
    data.smoothness = 1- roughness;
    data.specular = 0;
    data.normalTS = normalTS;
    data.occlusion = 1;
    return data;
    
}
float CubemapMipmapLevel(float roughness)
{
    half mip = roughness * (1.7 - 0.7 * roughness);
    mip *= UNITY_SPECCUBE_LOD_STEPS;
    return mip;
}

float3 SampleEnviroment(float3 viewDir, float3 normal, float roughness, float3 worldPos)
{
    float3 reflects = reflect(-viewDir, normal);
    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
    reflects = BoxProjectedCubemapDirection(reflects, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
    #endif
    float mip = CubemapMipmapLevel(roughness);
    float4 environment = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflects, mip);
    return DecodeHDREnvironment(environment, unity_SpecCube0_HDR);
}

inline float3 BlinnPhoneSpecular(float3 specularColor, float nDotH, float gloss)
{
    return specularColor * pow(nDotH, exp2(gloss));
}
Light InitCustomLight(float3 color,float3 lightPosition, float3 direction, float3 worldPosition,float4 lightAttenuation)
{
    Light light;
    light.color = color;
    float3 lightVector = lightPosition - worldPosition;
    light.direction = normalize(lightVector);
    //根据attenuation计算衰减
    float distanceSqr = max(dot(lightVector, lightVector), HALF_MIN);
    float attenuation = half(DistanceAttenuation(distanceSqr, lightAttenuation.xy) * AngleAttenuation(direction.xyz, light.direction, lightAttenuation.zw));
    light.distanceAttenuation = attenuation;
    light.shadowAttenuation = 1.0;
    return light;
    
}


float3 GetCustomAdditionalLighting(Light light, InputData data,float glossy = 2.0f)
{
    //漫反射
    float NOL = dot(light.direction,data.normalWS);
    float3 diffuse = light.color * NOL ;
    float3 halfDir = normalize(light.direction+data.viewDirectionWS);
    float HON = dot(halfDir,data.normalWS);
    float3 specular = light.color * pow(HON,exp2(glossy));
    return saturate((diffuse+specular) * light.distanceAttenuation);
}




#endif