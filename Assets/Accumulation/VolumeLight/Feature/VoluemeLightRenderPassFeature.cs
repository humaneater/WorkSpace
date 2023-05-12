using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
internal class VolumeLightSettings
{
    [SerializeField] internal RenderPassEvent m_Event = RenderPassEvent.AfterRenderingOpaques;


}
public class VoluemeLightRenderPassFeature : ScriptableRendererFeature
{
    class VolumeLightRenderPass : ScriptableRenderPass
    {
        private VolumeLightVolume mVolume;
        private Material mMat;
        private static readonly int mStepLength = Shader.PropertyToID("_StepLength");
        private static readonly int mStepSpeed = Shader.PropertyToID("_StepSpeed");
        private static readonly int mMaxDistance = Shader.PropertyToID("_CameraMaxDistance");
        private static readonly int mVolumeLightRT = Shader.PropertyToID("_VolumeLightTex");
        private RenderTargetIdentifier mVolumeLightID = new RenderTargetIdentifier(mVolumeLightRT);
        private ScriptableRenderer _renderer;
        
        

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public void SetUp(VolumeLightVolume volume,Material material,ScriptableRenderer renderer)
        {
            mVolume = volume;
            mMat = material;
            _renderer = renderer;
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            mMat.SetFloat(mStepLength,mVolume.mStep.value);
            mMat.SetFloat(mStepSpeed,mVolume.mSpeed.value);
            mMat.SetFloat(mMaxDistance,mVolume.mMaxDistance.value);
            var cmd = CommandBufferPool.Get();
            cmd.Clear();
            DoRender(cmd,renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void DoRender(CommandBuffer cmd,RenderingData renderingData)
        {
            var source = _renderer.cameraColorTarget;
            var depth = _renderer.cameraDepthTarget;
            int width = renderingData.cameraData.camera.pixelWidth / 2;
            int height = renderingData.cameraData.camera.pixelHeight / 2;

            RenderTextureDescriptor descriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGB32);
            cmd.GetTemporaryRT(mVolumeLightRT,descriptor);
            //cmd.SetRenderTarget(mVolumeLightID);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh,Matrix4x4.identity, mMat,0,0);
            cmd.ReleaseTemporaryRT(mVolumeLightRT);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }
    }

    [SerializeField] private VolumeLightSettings m_Setting = new VolumeLightSettings();

    VolumeLightRenderPass m_ScriptablePass;

    private Shader m_Shader = null;
    private Material m_Mat;
    private static string k_ShaderName = "PostProcess/VolumeLight";

    private bool GetMaterial()
    {
        if (m_Mat != null)
        {
            return true;
        }

        if (m_Shader == null)
        {
            m_Shader = Shader.Find(k_ShaderName);
            if (m_Shader == null)
            {
                return false;
            }
        }
        m_Mat = CoreUtils.CreateEngineMaterial(m_Shader);
        return true;
    }

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new VolumeLightRenderPass();
    
        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = m_Setting.m_Event;
        GetMaterial();
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!GetMaterial())
        {
            Debug.LogError("材质丢失！！！");
            return;
        }
        VolumeLightVolume volumeLight = VolumeManager.instance.stack.GetComponent<VolumeLightVolume>();
        if (volumeLight != null && volumeLight.IsActive())
        {
            m_ScriptablePass.SetUp(volumeLight,m_Mat,renderer);
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }
}