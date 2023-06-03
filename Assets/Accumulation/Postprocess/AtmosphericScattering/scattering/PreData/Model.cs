using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Assertions;

namespace PrecomputerScatter
{
    public struct DensityProfileLayer
    {   
        // An atmosphere layer of width 'Width', and whose density is defined as
        //   'ExpTerm' * exp('ExpScale' * h) + 'LinearTerm' * h + 'ConstantTerm',
        // clamped to [0,1], and where h is the altitude.
        public double Width;
        public double ExpTerm;
        public double ExpScale;
        public double LinearTerm;
        public double ConstantTerm;
    }
    
    //为Model配置的参数
    [System.Serializable]
    public class ModelParams
    {
        // The wavelength values, in nanometers, and sorted in increasing order.
        public List<double> WaveLengths;
        
        // The solar irradiance at the top of the atmosphere, in W/m^2/nm. This
        // vector must have the same size as the wavelengths parameter.
        public List<double> SolarIrradiance;

        // The sun's angular radius, in radians. Warning: the implementation uses
        // approximations that are valid only if this value is smaller than 0.1.
        public double SunAngularRadius;
        
        // The distance between the planet center and the bottom of the atmosphere,
        // in m.
        public double BottomRadius;

        // The distance between the planet center and the top of the atmosphere,
        // in m.
        public double TopRadius;
        
        // The density profile of air molecules, i.e. a function from altitude to
        // dimensionless values between 0 (null density) and 1 (maximum density).
        // Layers must be sorted from bottom to top. The width of the last layer is
        // ignored, i.e. it always extend to the top atmosphere boundary. At most 2
        // layers can be specified.
        public List<DensityProfileLayer> RayleighDensity;
        
        // The scattering coefficient of air molecules at the altitude where their
        // density is maximum (usually the bottom of the atmosphere), as a function
        // of wavelength, in m^-1. The scattering coefficient at altitude h is equal
        // to 'rayleigh_scattering' times 'rayleigh_density' at this altitude. This
        // vector must have the same size as the wavelengths parameter.
        public List<double> RayleighScattering;
        
        // The density profile of aerosols, i.e. a function from altitude to
        // dimensionless values between 0 (null density) and 1 (maximum density).
        // Layers must be sorted from bottom to top. The width of the last layer is
        // ignored, i.e. it always extend to the top atmosphere boundary. At most 2
        // layers can be specified.
        public List<DensityProfileLayer> MieDensity;
        
        // The scattering coefficient of aerosols at the altitude where their
        // density is maximum (usually the bottom of the atmosphere), as a function
        // of wavelength, in m^-1. The scattering coefficient at altitude h is equal
        // to 'mie_scattering' times 'mie_density' at this altitude. This vector
        // must have the same size as the wavelengths parameter.
        public List<double> MieScattering;
        
        // The extinction coefficient of aerosols at the altitude where their
        // density is maximum (usually the bottom of the atmosphere), as a function
        // of wavelength, in m^-1. The extinction coefficient at altitude h is equal
        // to 'mie_extinction' times 'mie_density' at this altitude. This vector
        // must have the same size as the wavelengths parameter.
        public List<double> MieExtinction;
        
        // The asymetry parameter for the Cornette-Shanks phase function for the
        // aerosols.
        public double MiePhaseFunctionG;
        
        // The density profile of air molecules that absorb light (e.g. ozone), i.e.
        // a function from altitude to dimensionless values between 0 (null density)
        // and 1 (maximum density). Layers must be sorted from bottom to top. The
        // width of the last layer is ignored, i.e. it always extend to the top
        // atmosphere boundary. At most 2 layers can be specified.
        public List<DensityProfileLayer> AbsorptionDensity;
        
        // The extinction coefficient of molecules that absorb light (e.g. ozone) at
        // the altitude where their density is maximum, as a function of wavelength,
        // in m^-1. The extinction coefficient at altitude h is equal to
        // 'absorption_extinction' times 'absorption_density' at this altitude. This
        // vector must have the same size as the wavelengths parameter.
        public List<double> AbsorptionExtinction;
        
        // The average albedo of the ground, as a function of wavelength. This
        // vector must have the same size as the wavelengths parameter.
        public List<double> GroundAlbedo;

        // The maximum Sun zenith angle for which atmospheric scattering must be
        // precomputed, in radians (for maximum precision, use the smallest Sun
        // zenith angle yielding negligible sky light radiance values. For instance,
        // for the Earth case, 102 degrees is a good choice for most cases (120
        // degrees is necessary for very high exposure values).
        public double MaxSunZenithAngle;
        
        // The length unit used in your shaders and meshes. This is the length unit
        // which must be used when calling the atmosphere model shader functions.
        public double LengthUnitInMeters;
        
    }

    class Model
    {
        //透射率Texture
        public RenderTexture Transmittance;
        //散射Texture，包含Single Rayleigh(No phase function) and Multi Scattering(with phase funciton),A channel save Single Mie'R component(no phase function) 
        public RenderTexture Scattering;
        //地面的Irradiance texture
        public RenderTexture Irradiance;
        
        
        //Temp RT，可以使用Temporary RT
        public RenderTexture deltaIrradiance;
        public RenderTexture deltaRayleighScattering;
        public RenderTexture deltaMieScattering;
        public RenderTexture deltaScatteringDensity;
        
        public Config Conf;

        private RenderTextureDescriptor TrnDesc, SctDesc, IrrDesc;

        private Material ComputeTransmittance,
            ComputeDirectIrradiance,
            ComputeSingleScattering,
            ComputeScatteringDensity,
            ComputeIndirectIrradiance,
            ComputeMultipleScattering;

        public Model(Config conf)
        {
            Conf = conf;
            TrnDesc = Util.Tex2Desc(Const.TransmittanceTextureSize.Width, Const.TransmittanceTextureSize.Height);
            SctDesc = Util.Tex3Desc();
            IrrDesc = Util.Tex2Desc(Const.IrradianceTextureSize.Width, Const.IrradianceTextureSize.Height);
            Transmittance = new RenderTexture(TrnDesc);
            Scattering = new RenderTexture(SctDesc);
            Irradiance = new RenderTexture(IrrDesc);

            deltaIrradiance = new RenderTexture(IrrDesc);
            deltaRayleighScattering = new RenderTexture(SctDesc);
            deltaMieScattering = new RenderTexture(SctDesc);
            deltaScatteringDensity = new RenderTexture(SctDesc);
        }

        public void Init(Material[] debugMat, uint numScatteringOrders = 4)
        {
            if (ComputeTransmittance == null)
            {
                ComputeTransmittance = new Material(Conf.ComputeTransmittance);
                ComputeDirectIrradiance = new Material(Conf.ComputeDirectIrradiance);
                ComputeIndirectIrradiance = new Material(Conf.ComputeIndirectIrradiance);
                ComputeScatteringDensity = new Material(Conf.ComputeScatteringDensity);
                ComputeSingleScattering = new Material(Conf.ComputeSingleScattering);
                ComputeMultipleScattering = new Material(Conf.ComputeMultipleScattering);
            }
            // The precomputations require temporary textures, in particular to store the
            // contribution of one scattering order, which is needed to compute the next
            // order of scattering (the final precomputed textures store the sum of all
            // the scattering orders). We allocate them here, and destroy them at the end
            // of this method.
            //需要创建RT存储中间结果，特别是计算多重散射时，我们每次计算出的高阶散射需要存储
            //在下一阶计算时需要用到
            /*RenderTexture deltaIrradiance = RenderTexture.GetTemporary(IrrDesc);
            RenderTexture deltaRayleighScattering = RenderTexture.GetTemporary(SctDesc);
            RenderTexture deltaMieScattering = RenderTexture.GetTemporary(SctDesc);
            RenderTexture deltaScatteringDensity = RenderTexture.GetTemporary(SctDesc);*/
            
            // delta_multiple_scattering_texture is only needed to compute scattering
            // order 3 or more, while delta_rayleigh_scattering_texture and
            // delta_mie_scattering_texture are only needed to compute double scattering.
            // Therefore, to save memory, we can store delta_rayleigh_scattering_texture
            // and delta_multiple_scattering_texture in the same GPU texture.
            //delta_multiple_scattering_texture只有在计算第三阶时才会用上，因为计算第二阶时用的
            //是delta_rayleigh_scattering_texture和delta_mie_scattering_texture，所以让
            //delta_multiple_scattering_texture和delta_rayleigh_scattering_texture用同一份GPU数据
            RenderTexture deltaMultipleScattering = deltaRayleighScattering;

            PreCompute(
                deltaIrradiance, 
                deltaRayleighScattering,
                deltaMieScattering, 
                deltaScatteringDensity, 
                deltaMultipleScattering,
                Matrix4x4.identity, 
                numScatteringOrders,
                debugMat);
            
            //RenderTexture.ReleaseTemporary(deltaIrradiance);
            //RenderTexture.ReleaseTemporary(deltaRayleighScattering);
            //RenderTexture.ReleaseTemporary(deltaMieScattering);
            //RenderTexture.ReleaseTemporary(deltaScatteringDensity);

        }

        void PreCompute(
            RenderTexture deltaIrradiance,
            RenderTexture deltaRayleighScattering,
            RenderTexture deltaMieScattering,
            RenderTexture deltaScatteringDensity,
            RenderTexture deltaMultipleScattering,
            Matrix4x4 luminanceFromRadiance,
            uint numScatteringOrders,Material[] debugMat)
        {
            Debug.Log("Pre-compute model");
            
            // Compute the transmittance, and store it in transmittance_texture_.
            //预计算透射率
            Util.DrawRect(ComputeTransmittance,Transmittance);
            
            // Compute the direct irradiance, store it in delta_irradiance_texture.
            // (we don't want the direct irradiance in irradiance_texture_,
            // but only the irradiance from the sky).
            //预计算地面 direct irradiance
            //这里的direct irradiance只是用来计算2阶的ScatteringDensity，不要放到Irradiance texture中
            ComputeDirectIrradiance.SetTexture("transmittance_texture",Transmittance);
            Util.DrawRect(ComputeDirectIrradiance,deltaIrradiance,Irradiance);

            // Compute the rayleigh and mie single scattering, store them in
            // delta_rayleigh_scattering_texture and delta_mie_scattering_texture, and
            // either store them or accumulate them in scattering_texture_ and
            // optional_single_mie_scattering_texture_.
            //计算一阶Scattering
            ComputeSingleScattering.SetMatrix("luminance_from_radiance",luminanceFromRadiance);
            ComputeSingleScattering.SetTexture("transmittance_texture",Transmittance);
            Util.DrawCube(ComputeSingleScattering,deltaRayleighScattering,deltaMieScattering,Scattering);

            // Compute the 2nd, 3rd and 4th order of scattering, in sequence.
            for (uint order = 2; order <= numScatteringOrders; order++)
            {
                // Compute the scattering density, and store it in
                // delta_scattering_density_texture.
                //可以简单地理解为计算每一点的n阶scattering
                ComputeScatteringDensity.SetTexture("transmmittance_texture",Transmittance);
                ComputeScatteringDensity.SetTexture("single_rayleigh_scattering_texture",deltaRayleighScattering);
                ComputeScatteringDensity.SetTexture("single_mie_scattering_texture",deltaMieScattering);
                ComputeScatteringDensity.SetTexture("multiple_scattering_texture",deltaMultipleScattering);
                ComputeScatteringDensity.SetTexture("irradiance_texture",deltaIrradiance);
                ComputeScatteringDensity.SetInt("scattering_order",(int)order);
                Util.DrawCube(ComputeScatteringDensity,deltaScatteringDensity);
                
                // Compute the indirect irradiance, store it in delta_irradiance_texture and
                // accumulate it in irradiance_texture_.
                //计算（n-2）次bounce后地面受到的indirect irradiance，虽然代码中是 order-1，
                //但是该项其实是用来在 n+1 阶的 ScatteringDensity时使用，所以实际是 (n-2)，
                //虽然是 n-2 ，但这里是计算的是地面法线半球空间中的 （n-2）次bounce后的indirect irradiance，
                //所以在 在下一阶计算 ScatteringDensity时，为了获取地面（n-1）次bounce后的 radiance，
                //只需要利用（n-2）的irradiance 与地面的albedo，以及法线，进行一次光照计算，就是（n-1）次 bounce(reflection)的radiance
                ComputeIndirectIrradiance.SetMatrix("luminance_from_radiance",luminanceFromRadiance);
                ComputeIndirectIrradiance.SetTexture("single_rayleigh_scattering_texture",deltaRayleighScattering);
                ComputeIndirectIrradiance.SetTexture("single_mie_scattering_texture",deltaMieScattering);
                ComputeIndirectIrradiance.SetTexture("multiple_scattering_texture",deltaMultipleScattering);
                ComputeIndirectIrradiance.SetInt("scattering_order",(int)order-1);
                deltaIrradiance.DiscardContents();
                Util.DrawRect(ComputeIndirectIrradiance,deltaIrradiance,Irradiance);
                
                // Compute the multiple scattering, store it in
                // delta_multiple_scattering_texture, and accumulate it in
                // scattering_texture_.
                //计算高阶散射，deltaMultipleScattering中存储的只是当前阶的散射，并且是计算了phase function了的scattering
                //Scattering中存储的是累计Scattering，通过Alpha Blend One One，将每阶散射叠上去，
                //因为一阶Scattering如果也计算phase function了之后存到Scattering中，实际渲染会有精度影响，
                //所以一阶的Rayleigh 和 Mie 在Scattering中都没有计算Phase Function,而是在实际渲染时计算，
                //但由于一阶以上的Scattering都是计算了Phase Function的（在ComputeScatteringDensity时），
                //所以为了实际渲染时，消除一阶Scattering的Phase Function的影响，每一阶Scattering叠上Scattering时，需要先除以Phase Function
                ComputeMultipleScattering.SetMatrix("luminance_from_radiance",luminanceFromRadiance);
                ComputeMultipleScattering.SetTexture("transmittance_texture",Transmittance);
                ComputeMultipleScattering.SetTexture("scattering_density_texture",deltaScatteringDensity);
                deltaMultipleScattering.DiscardContents();
                Util.DrawCube(ComputeMultipleScattering,deltaMultipleScattering,Scattering);

            }
            
            //设置debug材质的贴图
            if (debugMat.Length>0)
            {
                for (int i = 0; i < debugMat.Length; i++)
                {
                    debugMat[i].SetTexture("debug_transmittance",Transmittance);
                    debugMat[i].SetTexture("debug_directIrradiance",deltaIrradiance);
                    debugMat[i].SetTexture("debug_singleRayleighScattering",deltaRayleighScattering);
                    debugMat[i].SetTexture("debug_singleMieScattering",deltaMieScattering);
                    debugMat[i].SetTexture("debug_scatteringDensity",deltaScatteringDensity);
                    debugMat[i].SetTexture("debug_indirectIrradiance",Irradiance);
                    debugMat[i].SetTexture("debug_scattering",Scattering);
                }
            }
        }
        
        static Vector3 CIEColorMatchingFunctionTableValue(double wavelength) {
            Func<int, int, double> color = (int row, int column) =>
                Const.CIE2DegColorMatchingFunctions[4 * row + column];

            if (wavelength < Const.LambdaMin || wavelength > Const.LambdaMax) {
                return Vector3.zero;
            }
            double u = (wavelength - Const.LambdaMin) / Const.CIEFuncDeltaLambda;
            int row = (int)Math.Floor(u);
            Assert.IsTrue(row >= 0 && row + 1 < 95);
            Assert.IsTrue(Const.CIE2DegColorMatchingFunctions[4 * row] <= wavelength &&
                          Const.CIE2DegColorMatchingFunctions[4 * (row + 1)] >= wavelength);
            u -= row;
            var x = color(row, 1) * (1.0 - u) + color(row + 1, 1) * u;
            var y = color(row, 2) * (1.0 - u) + color(row + 1, 2) * u;
            var z = color(row, 3) * (1.0 - u) + color(row + 1, 3) * u;
            return new Vector3((float)x, (float)y, (float)z);
        }
        
        static double Interpolate(
            in List<double> wavelengths,
            in List<double> wavelengthFunction,
            double wavelength) {
            Assert.IsTrue(wavelengthFunction.Count == wavelengths.Count);
            if (wavelength < wavelengths[0]) {
                return wavelengthFunction[0];
            }
            for (int i = 0; i < wavelengths.Count - 1; i++) {
                if (wavelength < wavelengths[i + 1]) {
                    double u = (wavelength - wavelengths[i]) / (wavelengths[i + 1] - wavelengths[i]);
                    return wavelengthFunction[i] * (1.0 - u) + wavelengthFunction[i + 1] * u;
                }
            }
            return wavelengthFunction[wavelengthFunction.Count - 1];
        }
        // The returned constants are in lumen.nm / watt.
        static Vector3 ComputeSpectralRadianceToLuminanceFactors(
            List<double> wavelengths,
            List<double> solarIrradiance,
            double lambdaPower) {
            Vector3 kRGB = Vector3.zero;
            double solarR = Interpolate(wavelengths, solarIrradiance, Const.LambdaR);
            double solarG = Interpolate(wavelengths, solarIrradiance, Const.LambdaG);
            double solarB = Interpolate(wavelengths, solarIrradiance, Const.LambdaB);
            int dLambda = 1;
            for (int lambda = Const.LambdaMin; lambda < Const.LambdaMax; lambda += dLambda) {
                var xyzBar = CIEColorMatchingFunctionTableValue(lambda);
                var rBar = Vector3.Dot(Const.XYZToSRGB[0], xyzBar);
                var gBar = Vector3.Dot(Const.XYZToSRGB[1], xyzBar);
                var bBar = Vector3.Dot(Const.XYZToSRGB[2], xyzBar);
                double irradiance = Interpolate(wavelengths, solarIrradiance, lambda);
                kRGB.x += (float)(rBar * irradiance / solarR * Math.Pow(lambda / Const.LambdaR, lambdaPower));
                kRGB.y += (float)(gBar * irradiance / solarG * Math.Pow(lambda / Const.LambdaG, lambdaPower));
                kRGB.z += (float)(bBar * irradiance / solarB * Math.Pow(lambda / Const.LambdaB, lambdaPower));
            }
            kRGB *= (float)Const.MaxLuminousEfficacy * dLambda;
            return kRGB;
        }

        
        public static string Header(ModelParams para, Vector3 lambdas)
        {
            Func<List<double>, double, string> toString = (List<double> spectrum, double scale) =>
            {
                double r = Model.Interpolate(para.WaveLengths, spectrum, lambdas.x) * scale;
                double g = Model.Interpolate(para.WaveLengths, spectrum, lambdas.y) * scale;
                double b = Model.Interpolate(para.WaveLengths, spectrum, lambdas.z) * scale;
                return $"float3({r:g},{g:g},{b:g})";
            };
            Func<DensityProfileLayer, string> densityLayer = (DensityProfileLayer layer) =>
            {
                return
                    $@"_DensityProfileLayer({layer.Width / para.LengthUnitInMeters},{layer.ExpTerm},{layer.ExpScale * para.LengthUnitInMeters},{layer.LinearTerm * para.LengthUnitInMeters},{layer.ConstantTerm})";
            };
            Func<List<DensityProfileLayer>, string> densityProfile = (List<DensityProfileLayer> layers) => {
                const int layerCount = 2;
                while (layers.Count < layerCount) {
                    layers.Insert(0, new DensityProfileLayer());
                }

                var nl = Environment.NewLine;
                string result = $"_DensityProfile({nl}        ";
                for (int i = 0; i < layerCount; i++) {
                    result += densityLayer(layers[i]);
                    result += i < layerCount - 1 ? $",{nl}        " : ")";
                }
                return result;
            };
            var skyRGB = Model.ComputeSpectralRadianceToLuminanceFactors(para.WaveLengths, para.SolarIrradiance, -3);
            var sunRGB = Model.ComputeSpectralRadianceToLuminanceFactors(para.WaveLengths, para.SolarIrradiance, 0);
            
            //写入hlsl文件
            string header = $@"
#define IN(x) const in x
#define OUT(x) out x
#define TEMPLATE(x)
#define TEMPLATE_ARGUMENT(x)
#define assert(x)

static const int TRANSMITTANCE_TEXTURE_WIDTH = {Const.TransmittanceTextureSize.Width};
static const int TRANSMITTANCE_TEXTURE_HEIGHT = {Const.TransmittanceTextureSize.Height};
static const int SCATTERING_TEXTURE_R_SIZE = {Const.ScatteringTextureSize.R};
static const int SCATTERING_TEXTURE_MU_SIZE = {Const.ScatteringTextureSize.Mu};
static const int SCATTERING_TEXTURE_MU_S_SIZE = {Const.ScatteringTextureSize.MuS};
static const int SCATTERING_TEXTURE_NU_SIZE = {Const.ScatteringTextureSize.Nu};
static const int IRRADIANCE_TEXTURE_WIDTH = {Const.IrradianceTextureSize.Width};
static const int IRRADIANCE_TEXTURE_HEIGHT = {Const.IrradianceTextureSize.Height};

static const int2 TRANSMITTANCE_TEXTURE_SIZE = int2(TRANSMITTANCE_TEXTURE_WIDTH, TRANSMITTANCE_TEXTURE_HEIGHT);
static const int3 SCATTERING_TEXTURE_SIZE = int3(
    SCATTERING_TEXTURE_NU_SIZE * SCATTERING_TEXTURE_MU_S_SIZE,
    SCATTERING_TEXTURE_MU_SIZE,
    SCATTERING_TEXTURE_R_SIZE);
static const int2 IRRADIANCE_TEXTURE_SIZE = int2(IRRADIANCE_TEXTURE_WIDTH, IRRADIANCE_TEXTURE_HEIGHT);

AtmosphereParameters _ATMOSPHERE()
{{
    AtmosphereParameters a;
    a.solar_irradiance = {toString(para.SolarIrradiance, 1.0)};
    a.sun_angular_radius = {para.SunAngularRadius};
    a.bottom_radius = {para.BottomRadius / para.LengthUnitInMeters};
    a.top_radius = {para.TopRadius / para.LengthUnitInMeters};
    a.rayleigh_density = {densityProfile(para.RayleighDensity)};
    a.rayleigh_scattering = {toString(para.RayleighScattering, para.LengthUnitInMeters)};
    a.mie_density = {densityProfile(para.MieDensity)};
    a.mie_scattering = {toString(para.MieScattering, para.LengthUnitInMeters)};
    a.mie_extinction = {toString(para.MieExtinction, para.LengthUnitInMeters)};
    a.mie_phase_function_g = {para.MiePhaseFunctionG};
    a.absorption_density = {densityProfile(para.AbsorptionDensity)};
    a.absorption_extinction = {toString(para.AbsorptionExtinction, para.LengthUnitInMeters)};
    a.ground_albedo = {toString(para.GroundAlbedo, 1.0)};
    a.mu_s_min = {Math.Cos(para.MaxSunZenithAngle)};
    return a;
}}
static const AtmosphereParameters ATMOSPHERE = _ATMOSPHERE();
static const float3 SKY_SPECTRAL_RADIANCE_TO_LUMINANCE = float3({skyRGB.x},{skyRGB.y},{skyRGB.z});
static const float3 SUN_SPECTRAL_RADIANCE_TO_LUMINANCE = float3({sunRGB.x},{sunRGB.y},{sunRGB.z});
";
            return header;
        }
    }
}