#ifndef ATMOSPHERE_SCATTERING_UTILS
#define ATMOSPHERE_SCATTERING_UTILS
#include "./Definenation.hlsl"
//utils
float ClampDistance(float d)
{
    return max(d, 0.0);
}

float ClampCosine(float mu)
{
    return clamp(mu, -1.0, 1.0);
}

float ClampRadius(AtmosphereParameter atmosphere, float r)
{
    return clamp(r, atmosphere.bottom_radius, atmosphere.top_radius);
}


//为了每个参数读取时在纹素中心
float GetTextureCoordFromUnitRange(float x, int texture_size)
{
    return 0.5 / float(texture_size) + x * (1.0 - 1.0 / float(texture_size));
}
//为了将每个参数的值写在纹素中心
float GetUnitRangeFromTextureCoord(float u, int texture_size)
{
    return (u - 0.5 / float(texture_size)) / (1.0 - 1.0 / float(texture_size));
}
float RayleighPhaseFunction(float nu)
{
    float k = 3.0 / (16.0 * PI);
    return k * (1.0 + nu * nu);
}

float MiePhaseFunction(float g, float nu)
{
    float k = 3.0 / (8.0 * PI) * (1.0 - g * g) / (2.0 + g * g);
    return k * (1.0 + nu * nu) / pow(1.0 + g * g - 2.0 * g * nu, 1.5);
}
float GetLayerDensity(DensityProfileLayer layer,float altitude)
{
    float density = layer.exp_term * exp(layer.exp_scale*altitude) + layer.linear_term *altitude + layer.constant_term;
    return clamp(density,float(0.0),float(1.0));
}

float GetProfileDensity(DensityProfile profile,float altitude)
{
    return altitude < profile.layers[0].width ? GetLayerDensity(profile.layers[0],altitude) : GetLayerDensity(profile.layers[1],altitude);
}




//初始化两层密度，上层和下层
DensityProfileLayer _DensityProfileLayer(float w, float t, float s, float l, float c)
{
    DensityProfileLayer layer;
    layer.width = w;
    layer.exp_term = t;
    layer.exp_scale = s;
    layer.linear_term = l;
    layer.constant_term = c;
    return layer;
}
DensityProfile _DensityProfile(DensityProfileLayer l0, DensityProfileLayer l1)
{
    DensityProfile p;
    p.layers[0] = l0;
    p.layers[1] = l1;
    return p;
}

AtmosphereParameter InitAtmosphereParameter(AtmosphereParameter atmosphere,float topRadius,float bottomRadius)
{
    atmosphere.bottom_radius = bottomRadius;
    atmosphere.top_radius = topRadius;
    atmosphere.solar_irradiance = float3(1.474,1.8504,1.91198);
    atmosphere.sun_angular_radius = 0.004675;
    atmosphere.rayleigh_density = _DensityProfile(
        _DensityProfileLayer(0,0,0,0,0),
        _DensityProfileLayer(0,1,-0.125,0,0));
    atmosphere.rayleigh_scattering = float3(0.00580233938171238,0.0135577624479202,0.0331000059763677);
    atmosphere.mie_density = _DensityProfile(
        _DensityProfileLayer(0,0,0,0,0),
        _DensityProfileLayer(0,1,-0.833333333333333,0,0));
    atmosphere.mie_scattering = float3(0.003996,0.003996,0.003996);
    atmosphere.mie_extinction = float3(0.00444,0.00444,0.00444);
    atmosphere.mie_phase_function_g = 0.8;
    atmosphere.absorption_density = _DensityProfile(
        _DensityProfileLayer(25,0,0,0.0666666666666667,-0.666666666666667),
        _DensityProfileLayer(0,0,0,-0.0666666666666667,2.66666666666667));
    atmosphere.absorption_extinction = float3(0.0006497166,0.0018809,8.501668e-05);
    atmosphere.ground_albedo = float3(0.1,0.1,0.1);
    atmosphere.mu_s_min = -0.207911690817759;
    return atmosphere;
}





#endif