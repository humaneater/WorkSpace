using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;
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
    private static readonly int TransmittanceLUTID_Size = Shader.PropertyToID("_TransmittanceLUT_Size");
    private static readonly int PrecomputeScatteringLUTID = Shader.PropertyToID("_PrecomputeScatteringLUTID");
    private static readonly int PrecomputeScatteringLUTID_Size = Shader.PropertyToID("_PrecomputeScatteringLUTID_Size");
    private static readonly int GasDensity = Shader.PropertyToID("_GasDensity");
    private static readonly int _AtmosphereTop = Shader.PropertyToID("_AtmosphereTop");
    private static readonly int _SampleCount = Shader.PropertyToID("_SampleCount");
    private static readonly string TransmittanceLUTPass = "TransmittanceLUTPass";
    private static readonly string PrecomputeScattering = "PrecomputeScattering";
    private static readonly Vector2 TransmittanceLUTSize = new Vector2(256, 256);
    private static readonly Vector2 PrecomputeScatteringSize = new Vector2(512, 512);

    private int TransmittanceLUTkernel;

    private int PrecomputeScatteringkernel;
    
    
    


    void Start()
    {
        InitData();
    }

    private void InitData()
    {
        RenderTextureDescriptor descriptor = new RenderTextureDescriptor(256, 256, RenderTextureFormat.ARGB32);
        descriptor.enableRandomWrite = true;
        TransparencyLUT = new RenderTexture(descriptor);
        descriptor.width = (int)PrecomputeScatteringSize.x;
        descriptor.height = (int)PrecomputeScatteringSize.y;
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
        ScatteringCS.SetVector(PrecomputeScatteringLUTID_Size,PrecomputeScatteringSize);
        ScatteringCS.SetTexture(PrecomputeScatteringkernel,PrecomputeScatteringLUTID,PrecomputeScatteringLUT);
        ScatteringCS.SetTexture(PrecomputeScatteringkernel,TransmittanceLUTID,TransparencyLUT);
        ScatteringCS.Dispatch(PrecomputeScatteringkernel,(int)PrecomputeScatteringSize.x/8,(int)PrecomputeScatteringSize.y/8,1);
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
        PrecomputeScatteringLUT.Release();
    }
}
