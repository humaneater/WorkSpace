#ifndef ATMOSPHERE_SCATTERING_DEFINE
#define ATMOSPHERE_SCATTERING_DEFINE
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

#define OUT(x) out x
#define IN(x) x
#define Length float
#define Number float
#define Angle float
#define pi 3.141592653589

float2 _TransmittanceLUT_Size;
RWTexture2D<float4> _TransmittanceLUT_RW;
Texture2D<float4> _TransmittanceLUT;
SamplerState sampler_linear_clamp_Transmittance;
//计算irradiance
RWTexture2D<float4> _IrradianceTex_RW;
Texture2D<float4> _IrradianceTex;
SAMPLER(sampler_IrradianceTex);
float2 _IrradianceTex_Size;
SamplerState sampler_linear_clamp_IrradianceTex;
//大气密度的图
RWTexture3D<float4> _ScatteringDensityTex_RW;
Texture3D<float4> _ScatteringDensityTex;
//单次散射多个图
RWTexture3D<float4> _SingleRayleighScatteringTex_RW;
RWTexture3D<float4> _SingleMieScatteringTex_RW;
Texture3D<float4> _SingleRayleighScatteringTex;
Texture3D<float4> _SingleMieScatteringTex;
SamplerState sampler_linear_clamp_singleScatter3D;

RWTexture3D<float4> _MultiScatteringTex_RW;
Texture3D<float4> _MultiScatteringTex;



//x:SCATTERING_TEXTURE_NU_SIZE; y: SCATTERING_TEXTURE_MU_S_SIZE z: SCATTERING_TEXTURE_MU_SIZE, w: SCATTERING_TEXTURE_R_SIZE
float4 SCATTERING_TEXTURE_SIZE;

float _GasDensity, _AtmosphereTop, _PlanetRadius;

struct DensityProfileLayer {
 float width;
 float exp_term;
 float exp_scale;
 float linear_term;
 float constant_term;
};

struct DensityProfile {
 DensityProfileLayer layers[2];
};

struct AtmosphereParameter
{
 float top_radius;
 float bottom_radius;
 float3 rayleigh_scattering;
 float3 mie_scattering;
 float3 mie_extinction;
 float3 absorption_extinction;
 float3 solar_irradiance;
 DensityProfile rayleigh_density;
 DensityProfile mie_density;
 DensityProfile absorption_density;
 float mie_phase_function_g;
 float sun_angular_radius;
 float mu_s_min;
 float3 ground_albedo;
};





#endif