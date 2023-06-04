using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AtmosphericScatteringPostProcess : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        private Material mScatteringMat;
        private ScriptableRenderer _renderer;
        ProfilingSampler m_ProfilingSampler = new ProfilingSampler("Atmospheric Scattering");

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }


        public void Setup(ScriptableRenderer renderer, Material mat)
        {
            _renderer = renderer;
            mScatteringMat = mat;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                cmd.DrawMesh(RenderingUtils.fullscreenMesh,Matrix4x4.identity, mScatteringMat,0,0);
            }
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    [Serializable]
    internal class AtmosphericScatteringSetting
    {
        [SerializeField] public RenderPassEvent mEvent = RenderPassEvent.AfterRenderingTransparents;

        [SerializeField] [Header("强度")] [Range(0f, 2f)]
        public float strength = 1;
    }

    private Material mScatteringMat;
    private Shader mScatteringShader;
    private static readonly string k_shaderString = "PostPorcess/AtmosphericScattering";

    private bool GetMaterial()
    {
        if (mScatteringMat != null) return true;
        if (mScatteringShader == null)
        {
            mScatteringShader = Shader.Find(k_shaderString);
            if (mScatteringShader == null)
            {
                Debug.LogError("light shaft shader lost");
                return false;
            }
        }

        mScatteringMat = CoreUtils.CreateEngineMaterial(mScatteringShader);
        return true;
    }

    CustomRenderPass m_ScriptablePass;
    [SerializeField] AtmosphericScatteringSetting _setting = new AtmosphericScatteringSetting();

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = _setting.mEvent;
        GetMaterial();
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (GetMaterial())
        {
            m_ScriptablePass.Setup(renderer, mScatteringMat);
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }
}