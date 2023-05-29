using System;
using System.Collections;
using System.Collections.Generic;
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
    private static readonly int TransparencyLUTID = Shader.PropertyToID("_TransparencyLUT");
    private static readonly int GasDensity = Shader.PropertyToID("_GasDensity");
    private static readonly int _AtmosphereTop = Shader.PropertyToID("_AtmosphereTop");
    private static readonly int _SampleCount = Shader.PropertyToID("_SampleCount");

    private RenderTexture ScatteringLUT;

    private int TransparencyLUTkernel;
    


    void Start()
    {
        InitData();
    }

    private void InitData()
    {
        RenderTextureDescriptor descriptor = new RenderTextureDescriptor(256, 256, RenderTextureFormat.ARGB32);
        descriptor.enableRandomWrite = true;
        TransparencyLUT = new RenderTexture(descriptor);
        
    }

    private void GenerateLUT()
    {
        TransparencyLUTkernel = ScatteringCS.FindKernel("TransparencyLUTPass");
        ScatteringCS.SetFloat(PlanetRadius,planetRadius);
        ScatteringCS.SetFloat(_AtmosphereTop,AtmosphereTop);
        ScatteringCS.SetInt(_SampleCount,SampleCount);
        ScatteringCS.SetTexture(TransparencyLUTkernel,TransparencyLUTID,TransparencyLUT);
        ScatteringCS.Dispatch(TransparencyLUTkernel,256/8,256/8,1);
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
