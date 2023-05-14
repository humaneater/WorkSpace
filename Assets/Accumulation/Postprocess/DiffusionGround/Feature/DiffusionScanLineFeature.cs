using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public class DiffusionScanLineSetting
{
    [SerializeField] internal RenderPassEvent _event = RenderPassEvent.AfterRenderingTransparents;
    [SerializeField] internal Material _material = null;
}

public class DiffusionScanLineFeature : ScriptableRendererFeature
{
    class DiffusionScanLinePass : ScriptableRenderPass
    {
        private static readonly string k_Tag = "GridDiffusion";
        private ScriptableRenderer _renderer;
        private Material mMat;
        private RenderSettingManager.DiffusionData data;
        private static readonly int position = Shader.PropertyToID("_DiffusionPosition");
        private static readonly int diffusionValue = Shader.PropertyToID("_DiffusionValue");
        private static readonly int diffusionTexture = Shader.PropertyToID("_GridTexture");
        private static readonly int color = Shader.PropertyToID("_Color");

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public void SetUp(ScriptableRenderer renderer,  RenderSettingManager.DiffusionData mData)
        {
            _renderer = renderer;
            data = mData;
            mMat = mData.Mat;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(k_Tag);
            mMat.SetVector(position,data.DiffusionStartPosition);
            mMat.SetFloat(diffusionValue,data.DiffusionValue);
            mMat.SetTexture(diffusionTexture,data.GridTexture);
            mMat.SetColor(color,data.Color);
            DoRender(cmd, renderingData.cameraData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void DoRender(CommandBuffer cmd, CameraData cameraData)
        {
            /*var source = _renderer.cameraColorTarget;
            var depth = _renderer.cameraDepthTarget;*/
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mMat, 0, 0);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    DiffusionScanLinePass m_ScriptablePass;
    [SerializeField] private DiffusionScanLineSetting setting = new DiffusionScanLineSetting();


    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new DiffusionScanLinePass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = setting._event;
        GetMaterial();
    }

    private void GetMaterial()
    {
        if (setting._material == null)
        {
            Material mat = new Material(Shader.Find("PostProcess/DiffusionScanLine"));
            setting._material = mat;
        }
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if ( RenderSettingManager.GetInstance() == null || RenderSettingManager.GetInstance().GetDiffusionData().Mat == null) return;

        m_ScriptablePass.SetUp(renderer, RenderSettingManager.GetInstance().GetDiffusionData());
        renderer.EnqueuePass(m_ScriptablePass);
    }
}