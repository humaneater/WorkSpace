using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class LightShaftFeature : ScriptableRendererFeature
{
    class LightShaftPass : ScriptableRenderPass
    {
        private static readonly string k_Tag = "Atmospheric Scattering";
        ProfilingSampler m_ProfilingSampler = new ProfilingSampler("LightShaft");
        private static readonly int DownSamplingRT01 = Shader.PropertyToID("_DownSamplingTexture01");
        private static readonly int DownSamplingRT02 = Shader.PropertyToID("_DownSamplingTexture02");
        private static readonly int LuminanceRT = Shader.PropertyToID("_LuminanceTexture");
        private static readonly int RadialBlurRT01 = Shader.PropertyToID("_RadialBlurTexture01");
        private static readonly int ResultTexutre = Shader.PropertyToID("_LightShaftTexture");
        private static readonly int CameraColor = Shader.PropertyToID("_CameraOpaqueTexture");
        private static readonly int MainTex = Shader.PropertyToID("_MainTex");
        private static readonly int _Radius = Shader.PropertyToID("_Radius");

        private float Radius;

        private Material mShaftMaterial;
        private ScriptableRenderer _renderer;

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public void Setup(Material mat, ScriptableRenderer renderer,float radius)
        {
            mShaftMaterial = mat;
            _renderer = renderer;
            Radius = radius;
        }

        //light shaft 简单做法就是径向模糊，先做一个试试，大气散射有点复杂
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("");
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                //降采样2次，提取亮度区域，模糊3次，一共5个dc，最后直接加到目标上
                DoLightShaft(renderingData.cameraData, cmd);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void DoLightShaft(CameraData cameraData, CommandBuffer cmd)
        {
            RenderTextureDescriptor descriptor = new RenderTextureDescriptor(cameraData.camera.pixelWidth/2 ,
                cameraData.camera.pixelHeight/2, RenderTextureFormat.RGB111110Float);
            //第一遍降采样
            cmd.GetTemporaryRT(DownSamplingRT01, descriptor);
            cmd.SetRenderTarget(DownSamplingRT01);
            cmd.SetGlobalTexture(MainTex, CameraColor);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mShaftMaterial, 0, 0);
            //第二遍降采样
            descriptor.width /= 2;
            descriptor.height /= 2;
            cmd.GetTemporaryRT(DownSamplingRT02, descriptor);
            cmd.SetRenderTarget(DownSamplingRT02);
            cmd.SetGlobalTexture(MainTex, DownSamplingRT01);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mShaftMaterial, 0, 0);
            //取亮度
            cmd.GetTemporaryRT(LuminanceRT,descriptor);
            cmd.SetRenderTarget(LuminanceRT);
            cmd.SetGlobalTexture(MainTex, DownSamplingRT02);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mShaftMaterial, 0, 1);
            //径向模糊
            cmd.GetTemporaryRT(RadialBlurRT01, descriptor);
            mShaftMaterial.SetFloat(_Radius,Radius);
            cmd.SetRenderTarget(RadialBlurRT01);
            cmd.SetGlobalTexture(MainTex, LuminanceRT);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mShaftMaterial, 0, 2);
            //径向模糊2
            mShaftMaterial.SetFloat(_Radius,Radius * 2f);
            cmd.SetRenderTarget(DownSamplingRT02);
            cmd.SetGlobalTexture(MainTex, RadialBlurRT01);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mShaftMaterial, 0, 2);
            //径向模糊3
            mShaftMaterial.SetFloat(_Radius,Radius * 4f);
            cmd.SetRenderTarget(DownSamplingRT01);
            cmd.SetGlobalTexture(MainTex, DownSamplingRT02);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mShaftMaterial, 0, 2);
            //放大
            descriptor.width = cameraData.camera.pixelWidth;
            descriptor.height = cameraData.camera.pixelHeight;
            cmd.GetTemporaryRT(ResultTexutre,descriptor);
            cmd.SetRenderTarget(ResultTexutre);
            cmd.SetGlobalTexture(MainTex, DownSamplingRT01);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mShaftMaterial, 0, 3);
            //与图像融合
            cmd.SetRenderTarget(_renderer.cameraColorTarget);
            cmd.SetGlobalTexture(MainTex, ResultTexutre);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mShaftMaterial, 0, 4);
            
            cmd.ReleaseTemporaryRT(LuminanceRT);
            cmd.ReleaseTemporaryRT(DownSamplingRT01);
            cmd.ReleaseTemporaryRT(DownSamplingRT02);
            cmd.ReleaseTemporaryRT(ResultTexutre);
            cmd.ReleaseTemporaryRT(RadialBlurRT01);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    LightShaftPass m_ScriptablePass;

    [Serializable]
    internal class LightShaftSetting
    {
        [SerializeField] public RenderPassEvent mEvent = RenderPassEvent.AfterRenderingTransparents;
        [SerializeField][Header("径向模糊距离")][Range(0f,2f)] public float radius = 1;
    }

    private Material mShaftMat;
    private Shader mShaftShader;
    private static readonly string k_shaderString = "PostPorcess/LightShaft";

    private bool GetMaterial()
    {
        if (mShaftMat != null) return true;
        if (mShaftShader == null)
        {
            mShaftShader = Shader.Find(k_shaderString);
            if (mShaftShader == null)
            {
                Debug.LogError("light shaft shader lost");
                return false;
            }
        }

        mShaftMat = CoreUtils.CreateEngineMaterial(mShaftShader);
        return true;
    }

    [SerializeField] private LightShaftSetting setting = new LightShaftSetting();

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new LightShaftPass();
        m_ScriptablePass.renderPassEvent = setting.mEvent;
        GetMaterial();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!GetMaterial()) return;
        m_ScriptablePass.Setup(mShaftMat, renderer,setting.radius);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}