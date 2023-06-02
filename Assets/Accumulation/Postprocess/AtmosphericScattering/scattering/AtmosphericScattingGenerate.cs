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
    
    private static readonly int PlanetRadius = Shader.PropertyToID("_PlanetRadius");

    private RenderTexture TransparencyLUT;
    private RenderTexture PrecomputeScatteringLUT;
    private static readonly int TransmittanceLUTID = Shader.PropertyToID("_TransmittanceLUT");
    private static readonly int TransmittanceLUTID_Pre = Shader.PropertyToID("_TransmittanceLUT_Pre");
    private static readonly int TransmittanceLUTID_Size = Shader.PropertyToID("_TransmittanceLUT_Size");
    private static readonly int PrecomputeScatteringLUTID = Shader.PropertyToID("_SCATTERING_TEXTURE");
    private static readonly int GasDensity = Shader.PropertyToID("_GasDensity");
    private static readonly int _AtmosphereTop = Shader.PropertyToID("_AtmosphereTop");
    private static readonly int _SampleCount = Shader.PropertyToID("_SampleCount");
    private static readonly string TransmittanceLUTPass = "TransmittanceLUTPass";
    private static readonly string PrecomputeScattering = "PrecomputeScattering";
    private static readonly Vector2 TransmittanceLUTSize = new Vector2(256, 64);
    private static readonly Vector3 PrecomputeScatteringSize = new Vector3(256, 128,32);
    private static readonly int SCATTERING_TEXTURE_SIZEID = Shader.PropertyToID("SCATTERING_TEXTURE_SIZE");
    private static readonly Vector4 SCATTERING_TEXTURE_SIZE = new Vector4(8,32,128,32);

    private int TransmittanceLUTkernel;

    private int PrecomputeScatteringkernel;
    
    
    


    void Start()
    {
        InitData();
    }

    private void InitData()
    {
        RenderTextureDescriptor descriptor = new RenderTextureDescriptor((int)TransmittanceLUTSize.x, (int)TransmittanceLUTSize.y, RenderTextureFormat.ARGB32);
        descriptor.enableRandomWrite = true;
        TransparencyLUT = new RenderTexture(descriptor);
        descriptor.width = (int)PrecomputeScatteringSize.x;
        descriptor.height = (int)PrecomputeScatteringSize.y;
        descriptor.dimension = TextureDimension.Tex3D;
        descriptor.volumeDepth = (int)PrecomputeScatteringSize.z;
        PrecomputeScatteringLUT = new RenderTexture(descriptor);
    }

    private void GenerateLUT()
    {
        TransmittanceLUTkernel = ScatteringCS.FindKernel(TransmittanceLUTPass);
        PrecomputeScatteringkernel = ScatteringCS.FindKernel(PrecomputeScattering);
        //set一些数值
        ScatteringCS.SetFloat(PlanetRadius,planetRadius);
        ScatteringCS.SetFloat(_AtmosphereTop,AtmosphereTop);
        ScatteringCS.SetVector(TransmittanceLUTID_Size,TransmittanceLUTSize);
        ScatteringCS.SetInt(_SampleCount,SampleCount);
        ScatteringCS.SetTexture(TransmittanceLUTkernel,TransmittanceLUTID,TransparencyLUT);
        //执行预计算通透度lut
        ScatteringCS.Dispatch(TransmittanceLUTkernel,(int)TransmittanceLUTSize.x/8, (int)TransmittanceLUTSize.y/8,1);
        //执行预计算散射
        ScatteringCS.SetVector(SCATTERING_TEXTURE_SIZEID,SCATTERING_TEXTURE_SIZE);
        ScatteringCS.SetTexture(PrecomputeScatteringkernel,TransmittanceLUTID_Pre,TransparencyLUT);
        ScatteringCS.SetTexture(PrecomputeScatteringkernel,PrecomputeScatteringLUTID,PrecomputeScatteringLUT);
        ScatteringCS.Dispatch(PrecomputeScatteringkernel,(int)PrecomputeScatteringSize.x/8,(int)PrecomputeScatteringSize.y/8,(int)PrecomputeScatteringSize.z/8);
    }

    // Update is called once per frame
    void Update()
    {
        GenerateLUT();
    }

    private void OnDisable()
    {
//        ScatteringLUT.Release();
        TransparencyLUT.Release();
        
    }
}
