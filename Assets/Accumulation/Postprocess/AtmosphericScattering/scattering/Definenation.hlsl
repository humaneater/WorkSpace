#ifndef ATMOSPHERE_SCATTERING_DEFINE
#define ATMOSPHERE_SCATTERING_DEFINE
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
RWTexture2D<float4> _TransmittanceLUT;
Texture2D<float4> _TransmittanceLUT_Pre;
SAMPLER(sampler_TransmittanceLUT);
SAMPLER(sampler_TransmittanceLUT_Pre);
float2 _TransmittanceLUT_Size;
RWTexture3D<float4> _SCATTERING_TEXTURE;
SAMPLER(sampler_SCATTERING_TEXTURE);
#define OUT(x) out x

//x:SCATTERING_TEXTURE_NU_SIZE; y: SCATTERING_TEXTURE_MU_S_SIZE z: SCATTERING_TEXTURE_MU_SIZE, w: SCATTERING_TEXTURE_R_SIZE
float4 SCATTERING_TEXTURE_SIZE;
float _GasDensity, _AtmosphereTop, _PlanetRadius;
int _SampleCount;

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