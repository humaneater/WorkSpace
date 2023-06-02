#ifndef ATMOSPHERE_SCATTERING_FUNCTION
#define ATMOSPHERE_SCATTERING_FUNCTION

#include "./Utils.hlsl"
#include "./header.hlsl"

float DistanceToTopAtmosphereBoundary(AtmosphereParameter atmosphere, float r, float mu)
{
    //推一下：r == 高度  mu == theta角
    //求距离D，则 需要知道坐标系下 D的终点i的xy坐标
    //x: D * 根号1-cosmu^2, y : r+cosmu*D
    //D^2 * (1-cos^2) + r^2+ 2rCosmuD + cosmu * D ^2
    //简化如下 R^2 = D^2 + 2HCosmu * D + H^2
    // 则简化为以下形式:(D+HCosmu)^2 = R^2-H^2+H^2*cosmu^2
    //大概就是 (x + ab)^2 = c^2 + a^2*(b^2 - 1);
    float discriminant = r * r * (mu * mu - 1.0) + atmosphere.top_radius * atmosphere.top_radius;
    return ClampDistance(-r * mu + SafeSqrt(discriminant));
}

float DistanceToBottomAtmosphereBoundary(AtmosphereParameter atmosphere, float r, float mu)
{
    float discriminant = r * r * (mu * mu - 1.0) + atmosphere.bottom_radius * atmosphere.bottom_radius;
    return ClampDistance(-r * mu - SafeSqrt(discriminant));
}

bool RayIntersectsGround(AtmosphereParameter atmosphere, float r, float mu)
{
    return mu < 0.0f && r * r * (mu * mu - 1.0f) + atmosphere.bottom_radius * atmosphere.bottom_radius >= 0.0f;
}


float2 GetTransmittanceTextureUvFromRMu(AtmosphereParameter atmosphere,
                                        float r, float mu)
{
    // Distance to top atmosphere boundary for a horizontal ray at ground level.
    float H = sqrt(atmosphere.top_radius * atmosphere.top_radius - atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the horizon.
    float rho = SafeSqrt(r * r - atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the top atmosphere boundary for the ray (r,mu), and its minimum
    // and maximum values over all mu - obtained for (r,1) and (r,mu_horizon).
    float d = DistanceToTopAtmosphereBoundary(atmosphere, r, mu);
    float d_min = atmosphere.top_radius - r;
    float d_max = rho + H;
    float x_mu = (d - d_min) / (d_max - d_min);
    float x_r = rho / H;
    return float2(GetTextureCoordFromUnitRange(x_mu, _TransmittanceLUT_Size.x),
                  GetTextureCoordFromUnitRange(x_r, _TransmittanceLUT_Size.y));
}

//根据上边这个反退出来的
void GetHeightAndCosTheta(AtmosphereParameter atmosphere, in float2 uv, out float height, out float cosT)
{
    //切线长度
    float H = sqrt(atmosphere.top_radius * atmosphere.top_radius - atmosphere.bottom_radius * atmosphere.bottom_radius);
    float x_mu = uv.x;
    float x_r = uv.y;
    //把线性的y变成曲面的y，通过三角函数算回去
    float rho = H * x_r;
    height = sqrt(rho * rho + atmosphere.bottom_radius * atmosphere.bottom_radius);
    float d_min = atmosphere.top_radius - height;
    float d_max = rho + H;
    float d = d_min + x_mu * (d_max - d_min);
    //根据d2+2rμd+r2 = rmax2推出mu
    cosT = d == 0.0 ? float(1.0) : (H * H - rho * rho - d * d) / (2.0 * height * d);
    cosT = ClampCosine(cosT);
}

// total optical length of rayleigh and mie
float ComputeOpticalLengthToTopAtmosphereBoundary(AtmosphereParameter atmosphere, DensityProfile profile, float r,
                                                  float mu)
{
    int _SampleCount = 500;
    float dx = DistanceToTopAtmosphereBoundary(atmosphere, r, mu) / float(_SampleCount);
    float result = 0.0;
    for (int i = 0; i <= _SampleCount; i++)
    {
        float d_i = float(i) * dx;
        // Distance between the current sample point and the planet center.
        float r_i = sqrt(d_i * d_i + 2.0 * r * mu * d_i + r * r);
        // Number density at the current sample point (divided by the number density
        // at the bottom of the atmosphere, yielding a dimensionless number).
        float y_i = GetProfileDensity(profile, r_i - atmosphere.bottom_radius);
        result += y_i * dx;
    }
    return result;
}


float3 ComputeTransmittanceToTopAtmosphereBoundary(AtmosphereParameter atmosphere, float r, float mu)
{
    float3 attenuation_rayleigh = atmosphere.rayleigh_scattering * ComputeOpticalLengthToTopAtmosphereBoundary(
        atmosphere, atmosphere.rayleigh_density, r, mu);
    float3 attenuation_mie = atmosphere.mie_extinction * ComputeOpticalLengthToTopAtmosphereBoundary(
        atmosphere, atmosphere.mie_density, r, mu);
    float3 kBetaOzone = atmosphere.absorption_extinction * ComputeOpticalLengthToTopAtmosphereBoundary(
        atmosphere, atmosphere.absorption_density, r, mu);
    float3 attenuation_total = attenuation_rayleigh + attenuation_mie + kBetaOzone;
    return exp(-attenuation_total);
}


///单次散射用到的方法们
float3 GetTransmittanceToTopAtmosphereBoundary(AtmosphereParameter atmosphere, Texture2D<float4> transmittance_texture,
                                               float r, float mu)
{
    float2 uv = GetTransmittanceTextureUvFromRMu(atmosphere, r, mu);
    return float3(transmittance_texture.SampleLevel(sampler_TransmittanceLUT_Pre, uv, 0).xyz);
}

/*r=∥op∥    d=∥pq∥      μ=(op⋅pq)/rd    μs=(op⋅ωs)/r    ν=(pq⋅ωs)/d*/
float3 GetTransmittance(AtmosphereParameter atmosphere, Texture2D<float4> transmittance_texture, float r, float mu,
                        float d, bool ray_r_mu_intersects_ground)
{
    float r_d = ClampRadius(atmosphere, sqrt(d * d + 2.0 * r * mu * d + r * r));
    float mu_d = ClampCosine((r * mu + d) / r_d);
    //向地面需要反转方向
    if (ray_r_mu_intersects_ground)
    {
        return min(GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r_d, -mu_d) /
                   GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r, -mu),
                   float3(1.0f, 1.0f, 1.0f));
    }
    else
    {
        return min(GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r, mu) /
                   GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r_d, mu_d),
                   float3(1.0f, 1.0f, 1.0f));
    }
}

float3 GetTransmittanceToSun(AtmosphereParameter atmosphere, Texture2D<float4> transmittance_texture, float r,
                             float mu_s)
{
    float sin_theta_h = atmosphere.bottom_radius / r;
    float cos_theta_h = -sqrt(max(1.0 - sin_theta_h * sin_theta_h, 0.0));
    return GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r, mu_s) * smoothstep(
        -sin_theta_h * DegToRad(atmosphere.sun_angular_radius), sin_theta_h * DegToRad(atmosphere.sun_angular_radius),
        mu_s - cos_theta_h);
}


void ComputeSingleScatteringIntegrand(AtmosphereParameter atmosphere, Texture2D<float4> transmittance_texture, float r,
                                      float mu, float mu_s, float nu, float d, bool ray_r_mu_intersects_ground,
                                      out float3 rayleigh, out float3 mie)
{
    float r_d = ClampRadius(atmosphere, sqrt(d * d + 2.0 * r * mu * d + r * r));
    float mu_s_d = ClampCosine((r * mu_s + d * nu) / r_d);
    float3 transmittance = GetTransmittance(atmosphere, transmittance_texture, r, mu, d, ray_r_mu_intersects_ground) *
        GetTransmittanceToSun(atmosphere, transmittance_texture, r_d, mu_s_d);
    rayleigh = transmittance * GetProfileDensity(atmosphere.rayleigh_density, r_d - atmosphere.bottom_radius);
    mie = transmittance * GetProfileDensity(atmosphere.mie_density, r_d - atmosphere.bottom_radius);
}

float DistanceToNearestAtmosphereBoundary(AtmosphereParameter atmosphere, float r, float mu,
                                          bool ray_r_mu_intersects_ground)
{
    if (ray_r_mu_intersects_ground)
    {
        return DistanceToBottomAtmosphereBoundary(atmosphere, r, mu);
    }
    else
    {
        return DistanceToTopAtmosphereBoundary(atmosphere, r, mu);
    }
}

void ComputeSingleScattering(AtmosphereParameter atmosphere, Texture2D<float4> transmittance_texture, float r, float mu,
                             float mu_s, float nu, bool ray_r_mu_intersects_ground, out float3 rayleigh, out float3 mie)
{
    // Number of intervals for the numerical integration.
    int SAMPLE_COUNT = 50;
    // The integration step, i.e. the length of each integration interval.
    float dx = DistanceToNearestAtmosphereBoundary(atmosphere, r, mu, ray_r_mu_intersects_ground) / float(SAMPLE_COUNT);
    // Integration loop.
    float3 rayleigh_sum = 0.0;
    float3 mie_sum = 0.0;
    for (int i = 0; i <= SAMPLE_COUNT; i++)
    {
        float d_i = float(i) * dx;
        // The Rayleigh and Mie single scattering at the current sample point.
        float3 rayleigh_i;
        float3 mie_i;
        ComputeSingleScatteringIntegrand(atmosphere, transmittance_texture, r, mu, mu_s, nu, d_i,
                                         ray_r_mu_intersects_ground, rayleigh_i, mie_i);
        // Sample weight (from the trapezoidal rule).
        float weight_i = (i == 0 || i == SAMPLE_COUNT) ? 0.5 : 1.0;
        rayleigh_sum += rayleigh_i * weight_i;
        mie_sum += mie_i * weight_i;
    }
    rayleigh = rayleigh_sum * dx * atmosphere.solar_irradiance * atmosphere.rayleigh_scattering;
    mie = mie_sum * dx * atmosphere.solar_irradiance * atmosphere.mie_scattering;
}

//将r，mu，mu_s，nu转为ScatteringTexture的四维参数
float4 GetScatteringTextureUvwzFromRMuMuSNu(AtmosphereParameter atmosphere, float r, float mu, float mu_s, float nu,
                                            bool ray_r_mu_intersects_ground)
{
    // Distance to top atmosphere boundary for a horizontal ray at ground level.
    float H = sqrt(atmosphere.top_radius * atmosphere.top_radius -
        atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the horizon.
    float rho = SafeSqrt(r * r - atmosphere.bottom_radius * atmosphere.bottom_radius);
    float u_r = GetTextureCoordFromUnitRange(rho / H, SCATTERING_TEXTURE_SIZE.w);

    // Discriminant of the quadratic equation for the intersections of the ray
    // (r,mu) with the ground (see RayIntersectsGround).
    float r_mu = r * mu;
    float discriminant = r_mu * r_mu - r * r + atmosphere.bottom_radius * atmosphere.bottom_radius;
    float u_mu;
    if (ray_r_mu_intersects_ground)
    {
        // Distance to the ground for the ray (r,mu), and its minimum and maximum
        // values over all mu - obtained for (r,-1) and (r,mu_horizon).
        float d = -r_mu - SafeSqrt(discriminant);
        float d_min = r - atmosphere.bottom_radius;
        float d_max = rho;
        u_mu = 0.5 - 0.5 * GetTextureCoordFromUnitRange(d_max == d_min ? 0.0 : (d - d_min) / (d_max - d_min),
                                                        SCATTERING_TEXTURE_SIZE.z / 2);
    }
    else
    {
        // Distance to the top atmosphere boundary for the ray (r,mu), and its
        // minimum and maximum values over all mu - obtained for (r,1) and
        // (r,mu_horizon).
        float d = -r_mu + SafeSqrt(discriminant + H * H);
        float d_min = atmosphere.top_radius - r;
        float d_max = rho + H;
        u_mu = 0.5 + 0.5 * GetTextureCoordFromUnitRange(
            (d - d_min) / (d_max - d_min), SCATTERING_TEXTURE_SIZE.z / 2);
    }

    float d = DistanceToTopAtmosphereBoundary(atmosphere, atmosphere.bottom_radius, mu_s);
    float d_min = atmosphere.top_radius - atmosphere.bottom_radius;
    float d_max = H;
    float a = (d - d_min) / (d_max - d_min);
    float D = DistanceToTopAtmosphereBoundary(atmosphere, atmosphere.bottom_radius, atmosphere.mu_s_min);
    float A = (D - d_min) / (d_max - d_min);
    // An ad-hoc function equal to 0 for mu_s = mu_s_min (because then d = D and
    // thus a = A), equal to 1 for mu_s = 1 (because then d = d_min and thus
    // a = 0), and with a large slope around mu_s = 0, to get more texture 
    // samples near the horizon.
    float u_mu_s = GetTextureCoordFromUnitRange(max(1.0 - a / A, 0.0) / (1.0 + a), SCATTERING_TEXTURE_SIZE.y);

    float u_nu = (nu + 1.0) / 2.0;
    return float4(u_nu, u_mu_s, u_mu, u_r);
}

void GetRMuMuSNuFromScatteringTextureUvwz(AtmosphereParameter atmosphere, float4 uvwz, out float r, out float mu,
                                          out float mu_s, out float nu, out int ray_r_mu_intersects_ground)
{
    uvwz = clamp(uvwz, 0.0, 1.0);
    // Distance to top atmosphere boundary for a horizontal ray at ground level.
    float H = sqrt(atmosphere.top_radius * atmosphere.top_radius -
        atmosphere.bottom_radius * atmosphere.bottom_radius);
    // Distance to the horizon.
    float rho = H * GetUnitRangeFromTextureCoord(uvwz.w, SCATTERING_TEXTURE_SIZE.w);
    r = sqrt(rho * rho + atmosphere.bottom_radius * atmosphere.bottom_radius);

    //视线与地面相交时结果
    if (uvwz.z <= 0.5)
    {
        // Distance to the ground for the ray (r,mu), and its minimum and maximum
        // values over all mu - obtained for (r,-1) and (r,mu_horizon) - from which
        // we can recover mu:
        float d_min = r - atmosphere.bottom_radius;
        float d_max = rho;
        float d = d_min + (d_max - d_min) * GetUnitRangeFromTextureCoord(
            1.0 - 2.0 * uvwz.z, SCATTERING_TEXTURE_SIZE.z / 2);
        mu = d == 0.0 ? float(-1.0) : ClampCosine(-(rho * rho + d * d) / (2.0 * r * d));
        ray_r_mu_intersects_ground = true;
    }
    else
    {
        // Distance to the top atmosphere boundary for the ray (r,mu), and its
        // minimum and maximum values over all mu - obtained for (r,1) and
        // (r,mu_horizon) - from which we can recover mu:
        float d_min = atmosphere.top_radius - r;
        float d_max = rho + H;
        float d = d_min + (d_max - d_min) * GetUnitRangeFromTextureCoord(
            2.0 * uvwz.z - 1.0, SCATTERING_TEXTURE_SIZE.z / 2);
        mu = d == 0.0 ? float(1.0) : ClampCosine((H * H - rho * rho - d * d) / (2.0 * r * d));
        ray_r_mu_intersects_ground = false;
    }
    float x_mu_s = GetUnitRangeFromTextureCoord(uvwz.y, SCATTERING_TEXTURE_SIZE.y);
    float d_min = atmosphere.top_radius - atmosphere.bottom_radius;
    float d_max = H;
    float D = DistanceToTopAtmosphereBoundary(atmosphere, atmosphere.bottom_radius, atmosphere.mu_s_min);
    float A = (D - d_min) / (d_max - d_min);
    float a = (A - x_mu_s * A) / (1.0 + x_mu_s * A);
    float d = d_min + min(a, A) * (d_max - d_min);
    mu_s = d == 0.0 ? float(1.0) : ClampCosine((H * H - d * d) / (2.0 * atmosphere.bottom_radius * d));
    nu = ClampCosine(uvwz.x * 2.0 - 1.0);
}

/*
<p>We assumed above that we have 4D textures, which is not the case in practice.
We therefore need a further mapping, between 3D and 4D texture coordinates. The
function below expands a 3D texel coordinate into a 4D texture coordinate, and
then to $(r,\mu,\mu_s,\nu)$ parameters. It does so by "unpacking" two texel
coordinates from the $x$ texel coordinate. Note also how we clamp the $\nu$
parameter at the end. This is because $\nu$ is not a fully independent variable:
its range of values depends on $\mu$ and $\mu_s$ (this can be seen by computing
$\mu$, $\mu_s$ and $\nu$ from the cartesian coordinates of the zenith, view and
sun unit direction vectors), and the previous functions implicitely assume this
(their assertions can break if this constraint is not respected).
*/
//根据传入的纹理坐标，还原四维参数
void GetRMuMuSNuFromScatteringTextureFragCoord(
    AtmosphereParameter atmosphere, float3 frag_coord,
    out float r, out float mu, out float mu_s, out float nu,
    out int ray_r_mu_intersects_ground)
{
    float4 size = SCATTERING_TEXTURE_SIZE;
    size.x -= 1;
    float frag_coord_nu = floor(frag_coord.x / size.y);
    float frag_coord_mu_s = fmod(frag_coord.x, size.y);
    float4 uvwz = float4(frag_coord_nu, frag_coord_mu_s, frag_coord.y, frag_coord.z) / size;
    GetRMuMuSNuFromScatteringTextureUvwz(atmosphere, uvwz, r, mu, mu_s, nu, ray_r_mu_intersects_ground);
    // Clamp nu to its valid range of values, given mu and mu_s.
    nu = clamp(nu, mu * mu_s - sqrt((1.0 - mu * mu) * (1.0 - mu_s * mu_s)),
               mu * mu_s + sqrt((1.0 - mu * mu) * (1.0 - mu_s * mu_s)));
}

void ComputeSingleScatteringTexture(AtmosphereParameter atmosphere, Texture2D<float4> transmittance_texture,
                                    float3 frag_coord, out float3 rayleigh, out float3 mie)
{
    float r, mu, mu_s, nu;
    bool ray_r_mu_intersects_ground;
    GetRMuMuSNuFromScatteringTextureFragCoord(atmosphere, frag_coord,
                                              r, mu, mu_s, nu, ray_r_mu_intersects_ground);
    ComputeSingleScattering(atmosphere, transmittance_texture,
                            r, mu, mu_s, nu, ray_r_mu_intersects_ground, rayleigh, mie);
}

//


#endif
