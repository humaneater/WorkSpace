using System;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Color = UnityEngine.Color;

public class SaveDepthFeature : ScriptableRendererFeature
{
    class SaveDepthRenderPass : ScriptableRenderPass
    {
        private RenderTexture mDepthRT;
        private ScriptableRenderer _renderer;
        private int CameraDepthTextureID = Shader.PropertyToID("_CameraDepthTexture");
        private int m_MainTex = Shader.PropertyToID("_MainTex");
        private Material m_copyMat;


        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public void Setup(RenderTexture depthRT, ScriptableRenderer renderer,Material material)
        {
            mDepthRT = depthRT;
            _renderer = renderer;
            m_copyMat = material;
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.camera.tag == "MainCamera")
            {
                var cmd = CommandBufferPool.Get();
                cmd.SetRenderTarget(mDepthRT);
                cmd.ClearRenderTarget(true, true, Color.black, float.MinValue);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                cmd.SetGlobalTexture(m_MainTex,_renderer.cameraDepthTarget);
                cmd.DrawMesh(RenderingUtils.fullscreenMesh,Matrix4x4.identity, m_copyMat,0,0);
                //TODO:制作mip
                cmd.SetRenderTarget(renderingData.cameraData.targetTexture);
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    SaveDepthRenderPass m_ScriptablePass;
    public RenderTexture depthTex;
    private Material CopyMaterial;
    private Shader CopyShader;
    private static readonly string CopyDepthString = "Util/CopyDepthMip";

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new SaveDepthRenderPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        GetMaterial();
    }

    private bool GetMaterial()
    {
        if (CopyMaterial != null) return true;
        if (CopyShader == null)
        {
            CopyShader = Shader.Find(CopyDepthString);
            if (CopyShader == null)
            {
                return false;
            }
        }

        CopyMaterial = CoreUtils.CreateEngineMaterial(CopyShader);

        return true;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (depthTex != null && !renderingData.cameraData.isSceneViewCamera)
        {
            m_ScriptablePass.Setup(depthTex, renderer,CopyMaterial);
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }
}