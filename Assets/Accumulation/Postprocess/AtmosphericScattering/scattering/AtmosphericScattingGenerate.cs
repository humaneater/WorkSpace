using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

public class AtmosphericScattingGenerate : MonoBehaviour
{
    
    //需要添加的数据
    public float planetRadius = 6360f; 
    public float AtmosphereTop = 6420f;
    public int SampleCount = 500;
    public ComputeShader ScatteringCS;
    private static readonly int _SampleCount = Shader.PropertyToID("_SampleCount");
    private static readonly int PlanetRadius = Shader.PropertyToID("_PlanetRadius");
    private static readonly int _AtmosphereTop = Shader.PropertyToID("_AtmosphereTop");
    //通透度数据
    private static readonly int TransmittanceLUTRWID = Shader.PropertyToID("_TransmittanceLUT_RW");
    private static readonly int TransmittanceLUTID = Shader.PropertyToID("_TransmittanceLUT");
    private static readonly int TransmittanceLUTID_Size = Shader.PropertyToID("_TransmittanceLUT_Size");
    private static readonly Vector2 TransmittanceLUTSize = new Vector2(256, 64);
    //大地的irradiance数据
    private static readonly int IrradianceLUTRWID = Shader.PropertyToID("_IrradianceTex_RW");
    private static readonly int IrradianceLUTID = Shader.PropertyToID("_IrradianceTex");
    private static readonly int IrradianceSize = Shader.PropertyToID("_IrradianceTex_Size");
    private static readonly Vector2 IrradianceTexSize = new Vector2(64, 16);
    //单次散射数据，其实瑞丽和mie散射是两个3d图存的，所以要建2个。。。
    private static readonly int PrecomputeSingleRayleighScatteringLUTRWID = Shader.PropertyToID("_SingleRayleighScatteringTex_RW");
    private static readonly int PrecomputeSingleMieScatteringLUTRWID = Shader.PropertyToID("_SingleMieScatteringTex_RW");
    private static readonly Vector3 PrecomputeScatteringSize = new Vector3(256, 128,32);
    ////x:SCATTERING_TEXTURE_NU_SIZE; y: SCATTERING_TEXTURE_MU_S_SIZE z: SCATTERING_TEXTURE_MU_SIZE, w: SCATTERING_TEXTURE_R_SIZE
    private static readonly int SCATTERING_TEXTURE_SIZEID = Shader.PropertyToID("SCATTERING_TEXTURE_SIZE");
    private static readonly Vector4 SCATTERING_TEXTURE_SIZE = new Vector4(8,32,128,32);
    //计算大气密度数据
    private static readonly int ScatteringDensityRWID = Shader.PropertyToID("_ScatteringDensityTex_RW");
    private static readonly int ScatteringDensityID = Shader.PropertyToID("_ScatteringDensityTex");
    
    //多次散射相关数据
    private static readonly int PrecomputeRayleighScatteringLUTID = Shader.PropertyToID("_SingleRayleighScatteringTex");
    private static readonly int PrecomputeMieScatteringLUTID = Shader.PropertyToID("_SingleMieScatteringTex");
    private static readonly int PrecomputeMultiScatteringRWID = Shader.PropertyToID("_MultiScatteringTex_RW");
    private static readonly int PrecomputeMultiScatteringID = Shader.PropertyToID("_MultiScatteringTex");
    
    //computeshader数据
    private int TransmittanceLUTkernel;
    private int Irradiancekernel;
    private int PrecomputeScatteringkernel;
    private int PreComputeMultiScatteringKernel;
    private int ScatteringDensityKernel;
    private static readonly string TransmittanceLUTPass = "TransmittanceLUTPass";
    private static readonly string IrradiancePass = "IrradianceLUT";
    private static readonly string PrecomputeSingleScattering = "PrecomputeSingleScattering";
    private static readonly string PreComputeMultiScattering = "PreComputeMultiScattering";
    private static readonly string ComputeScatteringDensity = "ComputeScatteringDensity";
    
    //申请的rt，因为rw和非rw用一张就行了，不用重复申请这个挺方便的
    private RenderTexture TransparencyLUT;
    private RenderTexture IrradianceLUT;
    private RenderTexture PrecomputeSingleRayleighScatteringLUT;
    private RenderTexture PrecomputeSingleMieScatteringLUT;
    private RenderTexture PrecomputeMultiScatteringRT;
    private RenderTexture ScatteringDensityRT;

    void Start()
    {
        InitData();
    }

    private void InitData()
    {
        RenderTextureDescriptor descriptor = new RenderTextureDescriptor((int)TransmittanceLUTSize.x, (int)TransmittanceLUTSize.y, RenderTextureFormat.ARGBHalf);
        descriptor.enableRandomWrite = true;
        TransparencyLUT = new RenderTexture(descriptor);
        descriptor.width = (int)IrradianceTexSize.x;
        descriptor.height = (int)IrradianceTexSize.y;
        IrradianceLUT = new RenderTexture(descriptor);
        descriptor.width = (int)PrecomputeScatteringSize.x;
        descriptor.height = (int)PrecomputeScatteringSize.y;
        descriptor.dimension = TextureDimension.Tex3D;
        descriptor.volumeDepth = (int)PrecomputeScatteringSize.z;
        PrecomputeSingleRayleighScatteringLUT = new RenderTexture(descriptor);
        PrecomputeSingleMieScatteringLUT = new RenderTexture(descriptor);
        PrecomputeMultiScatteringRT = new RenderTexture(descriptor);
        ScatteringDensityRT = new RenderTexture(descriptor);
    }

    private void GenerateLUT()
    {
        TransmittanceLUTkernel = ScatteringCS.FindKernel(TransmittanceLUTPass);
        Irradiancekernel = ScatteringCS.FindKernel(IrradiancePass);
        PrecomputeScatteringkernel = ScatteringCS.FindKernel(PrecomputeSingleScattering);
        PreComputeMultiScatteringKernel = ScatteringCS.FindKernel(PreComputeMultiScattering);
        ScatteringDensityKernel = ScatteringCS.FindKernel(ComputeScatteringDensity);
        //set一些数值
        ScatteringCS.SetFloat(PlanetRadius,planetRadius);
        ScatteringCS.SetFloat(_AtmosphereTop,AtmosphereTop);
        ScatteringCS.SetVector(TransmittanceLUTID_Size,TransmittanceLUTSize);
        ScatteringCS.SetInt(_SampleCount,SampleCount);
        ScatteringCS.SetVector(IrradianceSize,IrradianceTexSize);
        //执行预计算通透度lut
        ScatteringCS.SetTexture(TransmittanceLUTkernel,TransmittanceLUTRWID,TransparencyLUT);
        ScatteringCS.Dispatch(TransmittanceLUTkernel,(int)TransmittanceLUTSize.x/8, (int)TransmittanceLUTSize.y/8,1);
        //计算irradiance的lut，也就是irradiancetex
        ScatteringCS.SetTexture(Irradiancekernel,TransmittanceLUTID,TransparencyLUT);
        ScatteringCS.SetTexture(Irradiancekernel,IrradianceLUTRWID,IrradianceLUT);
        ScatteringCS.Dispatch(Irradiancekernel,(int)IrradianceTexSize.x/8,(int)IrradianceTexSize.y/8,1);
        //执行预计算单次散射
        ScatteringCS.SetVector(SCATTERING_TEXTURE_SIZEID,SCATTERING_TEXTURE_SIZE);
        ScatteringCS.SetTexture(PrecomputeScatteringkernel,TransmittanceLUTID,TransparencyLUT);
        ScatteringCS.SetTexture(PrecomputeScatteringkernel,PrecomputeSingleRayleighScatteringLUTRWID,PrecomputeSingleRayleighScatteringLUT);
        ScatteringCS.SetTexture(PrecomputeScatteringkernel,PrecomputeSingleMieScatteringLUTRWID,PrecomputeSingleMieScatteringLUT);
        ScatteringCS.Dispatch(PrecomputeScatteringkernel,(int)PrecomputeScatteringSize.x/8,(int)PrecomputeScatteringSize.y/8,(int)PrecomputeScatteringSize.z/8);
        //计算大气密度，一个3d图，大小和散射的是一样的，运算也差不多
        ScatteringCS.SetTexture(ScatteringDensityKernel,TransmittanceLUTID,TransparencyLUT);
        ScatteringCS.SetTexture(ScatteringDensityKernel,IrradianceLUTID,IrradianceLUT);
        ScatteringCS.SetTexture(ScatteringDensityKernel,PrecomputeRayleighScatteringLUTID,PrecomputeSingleRayleighScatteringLUT);
        ScatteringCS.SetTexture(ScatteringDensityKernel,PrecomputeMieScatteringLUTID,PrecomputeSingleMieScatteringLUT);
        ScatteringCS.SetTexture(ScatteringDensityKernel,PrecomputeMultiScatteringID,PrecomputeMultiScatteringRT);
        ScatteringCS.SetTexture(ScatteringDensityKernel,ScatteringDensityRWID,ScatteringDensityRT);
        ScatteringCS.Dispatch(ScatteringDensityKernel,(int)PrecomputeScatteringSize.x/8,(int)PrecomputeScatteringSize.y/8,(int)PrecomputeScatteringSize.z/8);
        //执行预计算多次散射,我只计算2次，也就是只有2阶素材，后边多了也没啥必要
        //这里需要先计算两个东西，第一个是地面的irradiance，一个是多次散射的值，因为用的是cs，所以rw和普通texture需要分开传入，配置量需要double
        ScatteringCS.SetTexture(PreComputeMultiScatteringKernel,TransmittanceLUTID,TransparencyLUT);
        ScatteringCS.SetTexture(PreComputeMultiScatteringKernel,ScatteringDensityID,ScatteringDensityRT);
        ScatteringCS.SetTexture(PreComputeMultiScatteringKernel,PrecomputeMultiScatteringRWID,PrecomputeMultiScatteringRT);
        ScatteringCS.Dispatch(PreComputeMultiScatteringKernel,(int)PrecomputeScatteringSize.x/8,(int)PrecomputeScatteringSize.y/8,(int)PrecomputeScatteringSize.z/8);
        Shader.SetGlobalTexture(PrecomputeMultiScatteringID,PrecomputeMultiScatteringRT);
        
    }

    // Update is called once per frame
    void Update()
    {
        GenerateLUT();
    }

    private void OnDisable()
    {
        TransparencyLUT.Release();
        PrecomputeSingleRayleighScatteringLUT.Release();
        PrecomputeMultiScatteringRT.Release();
        PrecomputeSingleMieScatteringLUT.Release();
        ScatteringDensityRT.Release();
    }
}
