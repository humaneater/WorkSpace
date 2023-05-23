using System;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Color = UnityEngine.Color;
using ProfilingScope = UnityEngine.Rendering.ProfilingScope;

public class SaveDepthFeature : ScriptableRendererFeature
{
    class SaveDepthRenderPass : ScriptableRenderPass
    {
        private ScriptableRenderer _renderer;
        private int CameraDepthTextureMipID = Shader.PropertyToID("_CameraDepthTextureMip");
        private static readonly int TempLowTexID = Shader.PropertyToID("_TempHighTexture");
        private static readonly int TempHighTexID = Shader.PropertyToID("_TempLowTexture");
        private int m_MainTex = Shader.PropertyToID("_MainTex");
        private Material m_copyMat;
        ProfilingSampler m_ProfilingSampler = new ProfilingSampler("DepthMipBlit");
        private RenderTexture mDepthRT;


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
                using (new ProfilingScope(cmd, m_ProfilingSampler))
                {
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();
                    cmd.SetRenderTarget(mDepthRT);
                    cmd.ClearRenderTarget(true, true, Color.black, float.MinValue);
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();
                    cmd.SetGlobalTexture(m_MainTex, _renderer.cameraDepthTarget);
                    cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, m_copyMat, 0, 0);
                    //TODO:制作mip,需要大概制作8个mip
                    int width = renderingData.cameraData.camera.pixelWidth;
                    int height = renderingData.cameraData.camera.pixelHeight;
                    RenderTextureDescriptor descriptor =
                        new RenderTextureDescriptor(width, height, GraphicsFormat.R32_SFloat,32);
                    //descriptor.depthBufferBits = 32;
                    descriptor.useMipMap = true;
                    for (int i = 0; i < 8; i++)
                    {
                        cmd.GetTemporaryRT(TempHighTexID,descriptor,FilterMode.Point);

                        if (i == 0)
                        {
                            cmd.Blit(mDepthRT, TempHighTexID, m_copyMat, 1);
                            cmd.CopyTexture(TempHighTexID,0,0,mDepthRT,0,0);
                            cmd.ReleaseTemporaryRT(TempHighTexID);
                        }
                        else
                        {
                            width /= 2;
                            height /= 2;
                            descriptor.width = width;
                            descriptor.height = height;
                            cmd.GetTemporaryRT(TempLowTexID, descriptor,FilterMode.Point);
                            cmd.Blit(TempHighTexID,TempLowTexID, m_copyMat, 1);
                            cmd.CopyTexture(TempLowTexID,0,0,mDepthRT,0,i);
                            cmd.ReleaseTemporaryRT(TempLowTexID);
                            cmd.ReleaseTemporaryRT(TempHighTexID);
                        }
                    }
                  

                    cmd.SetRenderTarget(renderingData.cameraData.targetTexture);
                }

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
        if (GetMaterial() && !renderingData.cameraData.isSceneViewCamera)
        {
            m_ScriptablePass.Setup(depthTex, renderer,CopyMaterial);
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }
}