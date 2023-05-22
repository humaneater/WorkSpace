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


        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public void Setup(RenderTexture depthRT, ScriptableRenderer renderer)
        {
            mDepthRT = depthRT;
            _renderer = renderer;
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.camera.tag == "MainCamera")
            {
                var depthTexture = renderingData.cameraData.camera;
                var cmd = CommandBufferPool.Get();
                cmd.SetRenderTarget(mDepthRT);
                cmd.ClearRenderTarget(true,true,Color.black,float.MinValue);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                cmd.Blit(_renderer.cameraDepthTarget, mDepthRT);
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

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new SaveDepthRenderPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!renderingData.cameraData.isSceneViewCamera)
        {
            m_ScriptablePass.Setup(depthTex, renderer);
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }
}