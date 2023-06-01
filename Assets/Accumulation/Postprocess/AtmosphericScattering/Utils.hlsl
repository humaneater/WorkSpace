#ifndef ATMOSPHERE_SCATTERING_UTILS
#define ATMOSPHERE_SCATTERING_UTILS
struct AtmosphereParameter
{
    float3 top_radius;
    float3 bottom_radius;
    float3 rayleigh_scattering;
    float3 mie_scattering;
    float3 mie_extinction;
    float3 absorption_extinction;
    float rayleigh_density;
    float mie_density;
    float sun_angular_radius;
    float mu_s_min;
};
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

float GetProfileDensity(float density, float r)
{
    return clamp(exp(-(r) / density), 0.0, 1.0);
}

float GetTextureCoordFromUnitRange(float x, float texture_size)
{
    return 0.5 / float(texture_size) + x * (1.0 - 1.0 / float(texture_size));
}

float GetUnitRangeFromTextureCoord(float u, float texture_size)
{
    return (u - 0.5 / float(texture_size)) / (1.0 - 1.0 / float(texture_size));
}

AtmosphereParameter InitAtmosphereParameter(AtmosphereParameter atmosphere,float topRadius,float bottomRadius)
{
    atmosphere.bottom_radius = bottomRadius;
    atmosphere.top_radius = topRadius;
    atmosphere.rayleigh_density = 8.0;
    atmosphere.mie_density = 1.2;
    atmosphere.rayleigh_scattering = float3(5.802f, 13.558f, 33.100f) * 1e-3;
    atmosphere.mie_extinction = float3(0.0044f, 0.0044f, 0.0044f);
    atmosphere.mie_scattering = float3(0.0044f, 0.0044f, 0.0044f);
    atmosphere.absorption_extinction = float3(0.000650, 0.001881, 0.000085);
    atmosphere.mu_s_min = -0.2f;
    return atmosphere;
}




#endif