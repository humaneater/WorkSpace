using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public class ContactShadowSetting
{
    [SerializeField] public float MaxDistance;
    [SerializeField] public RenderPassEvent _event = RenderPassEvent.AfterRenderingTransparents;
}

public class ContactShadowFeature : ScriptableRendererFeature
{
    class ContactShadowPass : ScriptableRenderPass
    {
        private static readonly string k_Tag = "ContactShadow";
        private ScriptableRenderer _renderer;
        private Material mContactShadowMat;
        private RenderSettingManager.ContactShadowData _data;
        private static readonly int MaxDistance = Shader.PropertyToID("_MaxDistance");
        private static readonly int LightSourcePosition = Shader.PropertyToID("_LightSource");


        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }


        public void SetUp(ScriptableRenderer renderer, Material mMat,RenderSettingManager.ContactShadowData data)
        {
            _renderer = renderer;
            mContactShadowMat = mMat;
            _data = data;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(k_Tag);
            mContactShadowMat.SetVector(LightSourcePosition,_data.LightsPosition);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh,Matrix4x4.identity, mContactShadowMat,0,0);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }


    ContactShadowPass m_ScriptablePass;
    private Shader k_shader = null;
    private Material mMat = null;
    private static readonly string k_shaderString = "PostProcess/ContactShadow";

    private bool GetMaterial()
    {
        if (mMat != null)
        {
            return true;
        }
        if (k_shader == null)
        {
            k_shader = Shader.Find(k_shaderString);
            if (k_shader == null)
            {
                return false;
            }
        }
        mMat = CoreUtils.CreateEngineMaterial(k_shader);
        return true;
    }

    public ContactShadowSetting setting = new ContactShadowSetting();

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new ContactShadowPass();

        m_ScriptablePass.renderPassEvent = setting._event;
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (!GetMaterial())
        {
            Debug.LogError("材质丢了!!!");
            return;
        }

        if (!RenderSettingManager.GetInstance().GetContactShadow().isOpen) return;
        
        m_ScriptablePass.SetUp(renderer,mMat,RenderSettingManager.GetInstance().GetContactShadow());
        renderer.EnqueuePass(m_ScriptablePass);
    }
}