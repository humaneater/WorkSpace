#ifndef ATMOSPHERE_SCATTERING_FUNCTION
#define ATMOSPHERE_SCATTERING_FUNCTION
#include "./Utils.hlsl"

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
    return float3(transmittance_texture.SampleLevel(sampler_linear_clamp_Transmittance, uv, 0).xyz);
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
float4 GetScatteringTextureUvwzFromRMuMusNu(AtmosphereParameter atmosphere, float r, float mu, float mu_s, float nu,
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

//多次散射,方法排序不是推理排序
//首先采集单次散射，单词散射的采集以来uv的转变，uv也是从四个维度来的，依赖上边的一个方法
//解除统一量纲是个很容出错的东西，反向也证明了统一量纲的重要性，让你不会再写代码的时候出现思路不清晰的清空，角度就是角度，距离就是距离，是一个重要的思路
//但我已经回不了头了,后边用统一量纲了，看的比较费劲
/*
<h4 id="single_scattering_lookup">Lookup</h4>
*/


float3 GetScattering(AtmosphereParameter atmosphere, Texture3D<float4> scattering_texture, float r, float mu,
                     float mu_s, float nu, bool ray_r_mu_intersects_ground)
{
    float4 uvwz = GetScatteringTextureUvwzFromRMuMusNu(atmosphere, r, mu, mu_s, nu, ray_r_mu_intersects_ground);

    float tex_coord_x = uvwz.x * float(SCATTERING_TEXTURE_SIZE.x - 1);
    float tex_x = floor(tex_coord_x);
    float lerp = tex_coord_x - tex_x;
    float3 uvw0 = float3((tex_x + uvwz.y) / float(SCATTERING_TEXTURE_SIZE.x),
                         uvwz.z, uvwz.w);
    float3 uvw1 = float3((tex_x + 1.0 + uvwz.y) / float(SCATTERING_TEXTURE_SIZE.x),
                         uvwz.z, uvwz.w);
    //因为nu与mu_s在texture占用同一维，导致nu精度较低，使用两个nu进行采样插值，防止出现阶层
    return float3(
        scattering_texture.SampleLevel(sampler_linear_repeat_singleScatter3D, uvw0, 0).xyz * (1.0 - lerp) +
        scattering_texture.SampleLevel(
            sampler_linear_repeat_singleScatter3D, uvw1, 0).xyz * lerp);
}


//用来计算两个散射的多层（n-1）层的预积分，这里把mie散射和rayleigh散射加到了一起，之前我用a通道存的，所以倒是没啥问题，两个都读一遍就好了
//从第二层开始就只用读多次散射的图就ok了，两个散射系数已经在一起了，很nice
float3 GetScattering(AtmosphereParameter atmosphere, Texture3D<float4> single_rayleigh_scattering_texture,
                     Texture3D<float4> single_mie_scattering_texture, Texture3D<float4> multiple_scattering_texture,
                     float r, float mu, float mu_s, float nu, bool ray_r_mu_intersects_ground, int scattering_order)
{
    if (scattering_order == 1)
    {
        float3 rayleigh = GetScattering(atmosphere, single_rayleigh_scattering_texture, r, mu, mu_s, nu,
                                        ray_r_mu_intersects_ground);
        float3 mie = GetScattering(atmosphere, single_mie_scattering_texture, r, mu, mu_s, nu,
                                   ray_r_mu_intersects_ground);
        return rayleigh * RayleighPhaseFunction(nu) + mie * MiePhaseFunction(atmosphere.mie_phase_function_g, nu);
    }
    else
    {
        return GetScattering(
            atmosphere, multiple_scattering_texture, r, mu, mu_s, nu,
            ray_r_mu_intersects_ground);
    }
}


//只预计算了任意高度处水平表面的地面Irradiance，所以就只有两个参数
float2 GetIrradianceTextureUvFromRMus(IN(AtmosphereParameter) atmosphere,Length r,Number mu_s)
{
    Number x_r = (r - atmosphere.bottom_radius) / (atmosphere.top_radius - atmosphere.bottom_radius);
    Number x_mu_s = mu_s * 0.5 + 0.5;
    return float2(GetTextureCoordFromUnitRange(x_mu_s, _IrradianceTex_Size.x),
                  GetTextureCoordFromUnitRange(x_r, _IrradianceTex_Size.y));
}

float3 GetIrradiance(AtmosphereParameter atmosphere, Texture2D<float4> irradiance_texture, float r, float mu_s)
{
    float2 uv = GetIrradianceTextureUvFromRMus(atmosphere, r, mu_s);
    return float3(irradiance_texture.SampleLevel(sampler_linear_clamp_IrradianceTex, uv, 0).xyz);
}

//计算ScatteringDensity
float3 ComputeScatteringDensity(IN(AtmosphereParameter) atmosphere,IN(Texture2D<float4>) transmittance_texture,
                                IN(Texture3D<float4>) single_rayleigh_scattering_texture,
                                IN(Texture3D<float4>) single_mie_scattering_texture,
                                IN(Texture3D<float4>) multiple_scattering_texture,
                                IN(Texture2D<float4>) irradiance_texture,Length r, Number mu, Number mu_s, Number nu,
                                int scattering_order)
{
    // Compute unit direction vectors for the zenith, the view direction omega and
    // and the sun direction omega_s, such that the cosine of the view-zenith
    // angle is mu, the cosine of the sun-zenith angle is mu_s, and the cosine of
    // the view-sun angle is nu. The goal is to simplify computations below.
    float3 zenith_direction = float3(0.0, 0.0, 1.0);
    float3 omega = float3(sqrt(1.0 - mu * mu), 0.0, mu);
    Number sun_dir_x = omega.x == 0.0 ? 0.0 : (nu - mu * mu_s) / omega.x;
    Number sun_dir_y = sqrt(max(1.0 - sun_dir_x * sun_dir_x - mu_s * mu_s, 0.0));
    float3 omega_s = float3(sun_dir_x, sun_dir_y, mu_s);

    int SAMPLE_COUNT = 16;
    Angle dphi = pi / Number(SAMPLE_COUNT);
    Angle dtheta = pi / Number(SAMPLE_COUNT);
    float3 rayleigh_mie = 0;

    // Nested loops for the integral over all the incident directions omega_i.
    //外层循环天顶角
    float3 a = 0;
    for (int l = 0; l < SAMPLE_COUNT; l++)
    {
        Angle theta = (Number(l) + 0.5) * dtheta;
        Number cos_theta = cos(theta);
        Number sin_theta = sin(theta);
        bool ray_r_theta_intersects_ground = RayIntersectsGround(atmosphere, r, cos_theta);

        // The distance and transmittance to the ground only depend on theta, so we
        // can compute them in the outer loop for efficiency.
        Length distance_to_ground = 0.0;
        float3 transmittance_to_ground = 0.0;
        float3 ground_albedo = 0.0;
        if (ray_r_theta_intersects_ground)
        {
            distance_to_ground = DistanceToBottomAtmosphereBoundary(atmosphere, r, cos_theta);
            transmittance_to_ground = GetTransmittance(atmosphere, transmittance_texture, r, cos_theta,
                                                       distance_to_ground, true /* ray_intersects_ground */);
            ground_albedo = atmosphere.ground_albedo;
        }
        //二层循环方位角,*2是因为方位角积分是2PI
        for (int m = 0; m < 2 * SAMPLE_COUNT; m++)
        {
            Angle phi = (Number(m) + 0.5) * dphi;
            float3 omega_i = float3(cos(phi) * sin_theta, sin(phi) * sin_theta, cos_theta);
            float domega_i = (dtheta) * (dphi) * sin(theta);
            // The radiance L_i arriving from direction omega_i after n-1 bounces is
            // the sum of a term given by the precomputed scattering texture for the
            // (n-1)-th order:
            Number nu1 = dot(omega_s, omega_i);
            float3 incident_radiance = GetScattering(atmosphere,
                                                     single_rayleigh_scattering_texture, single_mie_scattering_texture,
                                                     multiple_scattering_texture, r, omega_i.z, mu_s, nu1,
                                                     ray_r_theta_intersects_ground, scattering_order - 1);

            // and of the contribution from the light paths with n-1 bounces and whose
            // last bounce is on the ground. This contribution is the product of the
            // transmittance to the ground, the ground albedo, the ground BRDF, and
            // the irradiance received on the ground after n-2 bounces.
            float3 ground_normal = normalize(zenith_direction * r + omega_i * distance_to_ground);
            float3 ground_irradiance = GetIrradiance(atmosphere, irradiance_texture, atmosphere.bottom_radius,
                                                     dot(ground_normal, omega_s));
            incident_radiance += transmittance_to_ground * ground_albedo * (1.0 / (PI)) * ground_irradiance;
            // The radiance finally scattered from direction omega_i towards direction
            // -omega is the product of the incident radiance, the scattering
            // coefficient, and the phase function for directions omega and omega_i
            // (all this summed over all particle types, i.e. Rayleigh and Mie).
            Number nu2 = dot(omega, omega_i);
            Number rayleigh_density = GetProfileDensity(atmosphere.rayleigh_density, r - atmosphere.bottom_radius);
            Number mie_density = GetProfileDensity(atmosphere.mie_density, r - atmosphere.bottom_radius);
            rayleigh_mie += incident_radiance * (atmosphere.rayleigh_scattering * rayleigh_density * RayleighPhaseFunction(nu2)
                    + atmosphere.mie_scattering * mie_density * MiePhaseFunction(atmosphere.mie_phase_function_g, nu2))*domega_i;
        }
    }
    return rayleigh_mie;
}


//计算高阶散射，只需要根据ScatteringDensity沿着mu进行积分即可
float3 ComputeMultipleScattering(IN(AtmosphereParameter) atmosphere,IN(Texture2D<float4>) transmittance_texture,
                                 IN(Texture3D<float4>) scattering_density_texture,Length r,Number mu,Number mu_s,
                                 Number nu, bool ray_r_mu_intersects_ground)
{
    // Number of intervals for the numerical integration.
    const int SAMPLE_COUNT = 50;

    // The integration step, i.e. the length of each integration interval.
    Length dx = DistanceToNearestAtmosphereBoundary(
        atmosphere, r, mu, ray_r_mu_intersects_ground) / Number(SAMPLE_COUNT);

    // Integration loop.
    float3 rayleigh_mie_sum = 0.0 * 1.0;
    float3 a = 0;
    for (int i = 0; i <= SAMPLE_COUNT; i++)
    {
        Length d_i = Number(i) * dx;

        // The r, mu and mu_s parameters at the current integration point (see the
        // single scattering section for a detailed explanation).
        Length r_i = ClampRadius(atmosphere, sqrt(d_i * d_i + 2.0 * r * mu * d_i + r * r));
        Number mu_i = ClampCosine((r * mu + d_i) / r_i);
        Number mu_s_i = ClampCosine((r * mu_s + d_i * nu) / r_i);

        // The Rayleigh and Mie multiple scattering at the current sample point.
        float3 rayleigh_mie_i = GetScattering(atmosphere, scattering_density_texture, r_i, mu_i, mu_s_i, nu,ray_r_mu_intersects_ground)* GetTransmittance(atmosphere, transmittance_texture, r, mu, d_i, ray_r_mu_intersects_ground)* dx;

        // Sample weight (from the trapezoidal rule).
        Number weight_i = (i == 0 || i == SAMPLE_COUNT) ? 0.5 : 1.0;
        rayleigh_mie_sum += rayleigh_mie_i * weight_i;
    }
    return rayleigh_mie_sum;
}

//计算n-1阶的scattering
float3 ComputeScatteringDensityTexture(IN(AtmosphereParameter) atmosphere,IN(Texture2D<float4>) transmittance_texture,
                                       IN(Texture3D<float4>) single_rayleigh_scattering_texture,
                                       IN(Texture3D<float4>) single_mie_scattering_texture,
                                       IN(Texture3D<float4>) multiple_scattering_texture,
                                       IN(Texture2D<float4>) irradiance_texture,IN(float3) frag_coord,
                                       int scattering_order)
{
    Length r;
    Number mu;
    Number mu_s;
    Number nu;
    bool ray_r_mu_intersects_ground;

    GetRMuMuSNuFromScatteringTextureFragCoord(atmosphere, frag_coord,
                                              r, mu, mu_s, nu, ray_r_mu_intersects_ground);
    return ComputeScatteringDensity(atmosphere, transmittance_texture, single_rayleigh_scattering_texture,
                                    single_mie_scattering_texture, multiple_scattering_texture, irradiance_texture, r,
                                    mu, mu_s, nu, scattering_order);
}

float3 ComputeMultipleScatteringTexture(IN(AtmosphereParameter) atmosphere,IN(Texture2D<float4>) transmittance_texture,
                                        IN(Texture3D<float4>) scattering_density_texture,IN(float3) frag_coord,
                                        OUT(Number) nu)
{
    Length r;
    Number mu;
    Number mu_s;
    bool ray_r_mu_intersects_ground;
    GetRMuMuSNuFromScatteringTextureFragCoord(atmosphere, frag_coord, r, mu, mu_s, nu, ray_r_mu_intersects_ground);
    return ComputeMultipleScattering(atmosphere, transmittance_texture, scattering_density_texture, r, mu, mu_s, nu,
                                     ray_r_mu_intersects_ground);
}

//计算地面direct irradiance
float3 ComputeDirectIrradiance(IN(AtmosphereParameter) atmosphere,IN(Texture2D<float4>) transmittance_texture,Length r,
                               Number mu_s)
{
    Number alpha_s = atmosphere.sun_angular_radius;

    // Approximate average of the cosine factor mu_s over the visible fraction of
    // the Sun disc.
    //根据太阳的 view facor计 算余弦因子，因为太阳的角半径很小，所以可以将余弦因子看作常数，而不需要积分
    Number average_cosine_factor = mu_s < -alpha_s
                                       ? 0.0
                                       : (mu_s > alpha_s
                                              ? mu_s
                                              : (mu_s + alpha_s) * (mu_s + alpha_s) / (4.0 * alpha_s));

    return atmosphere.solar_irradiance * exp(
        GetTransmittanceToTopAtmosphereBoundary(atmosphere, transmittance_texture, r, mu_s)) * average_cosine_factor;
}

//计算地面法向方向的半球空间内收到的(n-2)次bounce后受到的irradiance，因为计算n次bounce的multiple scattering时需要地面上的(n-1)次bounce后的radiance
float3 ComputeIndirectIrradiance(IN(AtmosphereParameter) atmosphere,
                                 IN(Texture3D<float4>) single_rayleigh_scattering_texture,
                                 IN(Texture3D<float4>) single_mie_scattering_texture,
                                 IN(Texture3D<float4>) multiple_scattering_texture,Length r,Number mu_s,
                                 int scattering_order)
{
    const int SAMPLE_COUNT = 32;
    const Angle dphi = pi / Number(SAMPLE_COUNT);
    const Angle dtheta = pi / Number(SAMPLE_COUNT);
    float3 result = 0.0 * 1.0;
    float3 omega_s = float3(sqrt(1.0 - mu_s * mu_s), 0.0, mu_s);
    for (int j = 0; j < SAMPLE_COUNT / 2; j++)
    {
        Angle theta = (Number(j) + 0.5) * dtheta;
        for (int i = 0; i < 2 * SAMPLE_COUNT; i++)
        {
            Angle phi = (Number(i) + 0.5) * dphi;
            float3 omega = float3(cos(phi) * sin(theta), sin(phi) * sin(theta), cos(theta));
            float domega = (dtheta / 1.0) * (dphi / 1.0) * sin(theta) * 1.0;

            Number nu = dot(omega, omega_s);
            result += GetScattering(atmosphere, single_rayleigh_scattering_texture, single_mie_scattering_texture,
                                    multiple_scattering_texture, r, omega.z, mu_s, nu, false, scattering_order) * omega.
                z * domega;
        }
    }
    return result;
}

/*
<p>The inverse mapping follows immediately:
*/
void GetRMusFromIrradianceTextureUv(IN(AtmosphereParameter) atmosphere,
                                    IN(float2) uv,OUT(Length) r,OUT(Number) mu_s)
{
    Number x_mu_s = GetUnitRangeFromTextureCoord(uv.x, _IrradianceTex_Size.x);
    Number x_r = GetUnitRangeFromTextureCoord(uv.y, _IrradianceTex_Size.y);
    r = atmosphere.bottom_radius + x_r * (atmosphere.top_radius - atmosphere.bottom_radius);
    mu_s = ClampCosine(2.0 * x_mu_s - 1.0);
}

/*
<p>It is now easy to define a fragment shader function to precompute a texel of
the ground irradiance texture, for the direct irradiance:
*/
float3 ComputeDirectIrradianceTexture(IN(AtmosphereParameter) atmosphere,IN(Texture2D<float4>) transmittance_texture,
                                      IN(float2) frag_coord)
{
    Length r;
    Number mu_s;
    GetRMusFromIrradianceTextureUv(atmosphere, frag_coord / _IrradianceTex_Size, r, mu_s);
    return ComputeDirectIrradiance(atmosphere, transmittance_texture, r, mu_s);
}

//计算地面的间接Irradiance
float3 ComputeIndirectIrradianceTexture(IN(AtmosphereParameter) atmosphere,
                                        IN(Texture3D<float4>) single_rayleigh_scattering_texture,
                                        IN(Texture3D<float4>) single_mie_scattering_texture,
                                        IN(Texture3D<float4>) multiple_scattering_texture,IN(float2) frag_coord,
                                        int scattering_order)
{
    Length r;
    Number mu_s;
    GetRMusFromIrradianceTextureUv(atmosphere, frag_coord / _IrradianceTex_Size, r, mu_s);
    return ComputeIndirectIrradiance(atmosphere, single_rayleigh_scattering_texture, single_mie_scattering_texture,
                                     multiple_scattering_texture, r, mu_s, scattering_order);
}

//从累计的scattering中分离一阶mie scattering
float3 GetExtrapolatedSingleMieScattering(IN(AtmosphereParameter) atmosphere,IN(float4) scattering)
{
    // Algebraically this can never be negative, but rounding errors can produce
    // that effect for sufficiently short view rays.
    if (scattering.r <= 0.0)
    {
        return 0.0;
    }
    return scattering.rgb * scattering.a / scattering.r * (atmosphere.rayleigh_scattering.r / atmosphere.mie_scattering.
        r) * (atmosphere.mie_scattering / atmosphere.rayleigh_scattering);
}

//得到一阶  mie，以及累计高阶scattering和一阶rayleigh
float3 GetCombinedScattering(IN(AtmosphereParameter) atmosphere,IN(Texture3D<float4>) scattering_texture,
                             IN(Texture3D<float4>) single_mie_scattering_texture,Length r,Number mu, Number mu_s,
                             Number nu, bool ray_r_mu_intersects_ground,OUT(float3) single_mie_scattering)
{
    float4 uvwz = GetScatteringTextureUvwzFromRMuMusNu(atmosphere, r, mu, mu_s, nu, ray_r_mu_intersects_ground);
    Number tex_coord_x = uvwz.x * Number(SCATTERING_TEXTURE_SIZE.x - 1);
    Number tex_x = floor(tex_coord_x);
    Number lerp = tex_coord_x - tex_x;
    float3 uvw0 = float3((tex_x + uvwz.y) / Number(SCATTERING_TEXTURE_SIZE.x), uvwz.z, uvwz.w);
    float3 uvw1 = float3((tex_x + 1.0 + uvwz.y) / Number(SCATTERING_TEXTURE_SIZE.x), uvwz.z, uvwz.w);
    float4 combined_scattering = scattering_texture.SampleLevel(sampler_linear_repeat_singleScatter3D, uvw0, 0) * (1.0 -
            lerp) +
        scattering_texture.SampleLevel(sampler_linear_repeat_singleScatter3D, uvw1, 0) * lerp;
    float3 scattering = float3(combined_scattering.xyz);
    single_mie_scattering = GetExtrapolatedSingleMieScattering(atmosphere, combined_scattering);
    return scattering;
}


#endif
