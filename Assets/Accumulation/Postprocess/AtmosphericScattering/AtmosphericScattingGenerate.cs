using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AtmosphericScattingGenerate : MonoBehaviour
{
    public ComputeShader ScatteringShader;

    private static readonly int PlanetRadius = Shader.PropertyToID("_PlanetRadius");

    private RenderTexture TransparencyLUT;

    private RenderTexture ScatteringLUT;

    private int TransparencyLUTkernel;
    


    void Start()
    {
        
    }

    private void InitData()
    {
        TransparencyLUT = new RenderTexture(256, 360,0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear);
        TransparencyLUTkernel = ScatteringShader.FindKernel("TransparenceLUTPass");
        
    }

    private void GenerateLUT()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
