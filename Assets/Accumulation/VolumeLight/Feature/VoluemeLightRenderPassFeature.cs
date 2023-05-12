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
        private static readonly int mStepSpeed = Shader.PropertyToID("_SpeedUp");
        private static readonly int mMaxDistance = Shader.PropertyToID("_CameraMaxDistance");
        private static readonly int mStepCount = Shader.PropertyToID("_StepCount");
        private static readonly int mMieVector = Shader.PropertyToID("_MieScatteringFactor");
        private static readonly int mBlurValue = Shader.PropertyToID("_BlurValue");
        private static readonly int mVolumeLightRT = Shader.PropertyToID("_VolumeLightTex");
        private static readonly int mVolumeLightTemp = Shader.PropertyToID("_VolumeLightTemp");
        private Vector3 mMieFactor = Vector3.one;
        private RenderTargetIdentifier mVolumeLightID = new RenderTargetIdentifier(mVolumeLightRT);
        private RenderTargetIdentifier mVolumeLightTempID = new RenderTargetIdentifier(mVolumeLightTemp);
        private ScriptableRenderer _renderer;


        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public void SetUp(VolumeLightVolume volume, Material material, ScriptableRenderer renderer)
        {
            mVolume = volume;
            mMat = material;
            _renderer = renderer;
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            mMieFactor.x = mVolume.mMieStrength.value;
            mMieFactor.y = mVolume.mMieY.value;
            mMieFactor.z = mVolume.mMieScatter.value;
            mMat.SetFloat(mStepLength, mVolume.mStep.value);
            mMat.SetFloat(mStepSpeed, mVolume.mSpeed.value);
            mMat.SetFloat(mMaxDistance, mVolume.mMaxDistance.value);
            mMat.SetFloat(mStepCount, mVolume.mStepCount.value);
            mMat.SetFloat(mBlurValue, mVolume.mBlueValue.value);
            mMat.SetVector(mMieVector, mMieFactor);
            var cmd = CommandBufferPool.Get();
            cmd.Clear();
            DoRender(cmd, renderingData);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        private void DoRender(CommandBuffer cmd, RenderingData renderingData)
        {
            var source = _renderer.cameraColorTarget;
            var depth = _renderer.cameraDepthTarget;
            //降分辨率
            int width = renderingData.cameraData.camera.pixelWidth / mVolume.mDownSampling.value;
            int height = renderingData.cameraData.camera.pixelHeight / mVolume.mDownSampling.value;

            RenderTextureDescriptor descriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.ARGB32);
            //思路：先全屏画到一个rt上，再把这个rt模糊，再画回原图
            cmd.GetTemporaryRT(mVolumeLightRT, descriptor);
            cmd.GetTemporaryRT(mVolumeLightTemp, descriptor);
            cmd.SetRenderTarget(mVolumeLightID);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mMat, 0, 0);
            cmd.SetRenderTarget(mVolumeLightTempID);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mMat, 0, 1);
            cmd.SetRenderTarget(source);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, mMat, 0, 2);
            cmd.ReleaseTemporaryRT(mVolumeLightRT);
            cmd.ReleaseTemporaryRT(mVolumeLightTemp);
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
            m_ScriptablePass.SetUp(volumeLight, m_Mat, renderer);
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }
}