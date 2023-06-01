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

//x:SCATTERING_TEXTURE_NU_SIZE -1; y: SCATTERING_TEXTURE_MU_S_SIZE z: SCATTERING_TEXTURE_MU_SIZE, w: SCATTERING_TEXTURE_R_SIZE
float4 SCATTERING_TEXTURE_SIZE;
float _GasDensity, _AtmosphereTop, _PlanetRadius;
int _SampleCount;
const float3 kBetaR = float3(5.802f, 13.558f, 33.100f) * 1e-3; // Rayleigh scattering coeffcient
const float3 kBetaM = float3(0.0044f, 0.0044f, 0.0044f); // Mie extinction
const float3 kBetaOzone = float3(0.000650, 0.001881, 0.000085); // absorption_extinction
const float kHeightR = 8.0; // scale height for rayleigh 
const float kHeightM = 1.2; // scale height for mie






#endif