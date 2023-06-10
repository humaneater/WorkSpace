using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteAlways]
public class ComputeMultiLights : MonoBehaviour
{
    //灯光结构体，是否可以放到别的地方
    private struct LightsInfo
    {
        public Color LightColor;
        public Vector4 LightPosition;
        public Vector4 LightDirection;
        public Vector4 LightAttenuation;

        static Vector4 k_DefaultLightAttenuation = new Vector4(0.0f, 1.0f, 0.0f, 1.0f);

        public LightsInfo(Color color, Vector4 position, Vector4 direction, float lightRange, LightType type,
            float spotAngle = 0, float innerSpotAngle = 0)
        {
            LightColor = color;
            LightPosition = position;
            LightDirection = direction;
            //根据range得到这个attnuation
            GetAttnuationByRange(lightRange, out LightAttenuation, type, spotAngle, innerSpotAngle);
        }

        private static void GetAttnuationByRange(float range, out Vector4 LightAttnuation, LightType type,
            float spotAngle = 0, float innerSpotAngle = 0)
        {
            LightAttnuation = k_DefaultLightAttenuation;
            //抄的unity的衰减判断
            // Light attenuation in universal matches the unity vanilla one.
            // attenuation = 1.0 / distanceToLightSqr
            // We offer two different smoothing factors.
            // The smoothing factors make sure that the light intensity is zero at the light range limit.
            // The first smoothing factor is a linear fade starting at 80 % of the light range.
            // smoothFactor = (lightRangeSqr - distanceToLightSqr) / (lightRangeSqr - fadeStartDistanceSqr)
            // We rewrite smoothFactor to be able to pre compute the constant terms below and apply the smooth factor
            // with one MAD instruction
            // smoothFactor =  distanceSqr * (1.0 / (fadeDistanceSqr - lightRangeSqr)) + (-lightRangeSqr / (fadeDistanceSqr - lightRangeSqr)
            //                 distanceSqr *           oneOverFadeRangeSqr             +              lightRangeSqrOverFadeRangeSqr

            // The other smoothing factor matches the one used in the Unity lightmapper but is slower than the linear one.
            // smoothFactor = (1.0 - saturate((distanceSqr * 1.0 / lightrangeSqr)^2))^2
            float lightRangeSqr = range * range;
            float fadeStartDistanceSqr = 0.8f * 0.8f * lightRangeSqr;
            float fadeRangeSqr = (fadeStartDistanceSqr - lightRangeSqr);
            float oneOverFadeRangeSqr = 1.0f / fadeRangeSqr;
            float lightRangeSqrOverFadeRangeSqr = -lightRangeSqr / fadeRangeSqr;
            float oneOverLightRangeSqr = 1.0f / Mathf.Max(0.0001f, range * range);

            // On untethered devices: Use the faster linear smoothing factor (SHADER_HINT_NICE_QUALITY).
            // On other devices: Use the smoothing factor that matches the GI.
            LightAttnuation.x =
                GraphicsSettings.HasShaderDefine(Graphics.activeTier, BuiltinShaderDefine.SHADER_API_MOBILE) ||
                SystemInfo.graphicsDeviceType == GraphicsDeviceType.Switch
                    ? oneOverFadeRangeSqr
                    : oneOverLightRangeSqr;
            LightAttnuation.y = lightRangeSqrOverFadeRangeSqr;
            if (type == LightType.Spot)
            {
                // Spot Attenuation with a linear falloff can be defined as
                // (SdotL - cosOuterAngle) / (cosInnerAngle - cosOuterAngle)
                // This can be rewritten as
                // invAngleRange = 1.0 / (cosInnerAngle - cosOuterAngle)
                // SdotL * invAngleRange + (-cosOuterAngle * invAngleRange)
                // If we precompute the terms in a MAD instruction
                float cosOuterAngle = Mathf.Cos(Mathf.Deg2Rad * spotAngle * 0.5f);
                // We neeed to do a null check for particle lights
                // This should be changed in the future
                // Particle lights will use an inline function
                float cosInnerAngle;
                if (innerSpotAngle > 0)
                    cosInnerAngle = Mathf.Cos(innerSpotAngle * Mathf.Deg2Rad * 0.5f);
                else
                    cosInnerAngle =
                        Mathf.Cos((2.0f *
                                   Mathf.Atan(Mathf.Tan(spotAngle * 0.5f * Mathf.Deg2Rad) * (64.0f - 18.0f) / 64.0f)) *
                                  0.5f);
                float smoothAngleRange = Mathf.Max(0.001f, cosInnerAngle - cosOuterAngle);
                float invAngleRange = 1.0f / smoothAngleRange;
                float add = -cosOuterAngle * invAngleRange;
                LightAttnuation.z = invAngleRange;
                LightAttnuation.w = add;
            }
        }

        public static int Size()
        {
            return sizeof(float) * 4 + sizeof(float) * 4 + sizeof(float) * 4 + sizeof(float) * 4;
        }
    }
    //灯的相关数据
    public GameObject lightGroup;
    private List<Light> mLightList;
    private List<LightData> mCachedLight;
    private int lightNumber;

    private int nowCountNumber;

    //最起码做一个灯光是否需要更新的开关
    private bool mLightUpdateTrigger;

    //置脏就更新，否则不更新
    private bool isDirty;

    //接下来重头戏，需要用cs做判断，做排序，做一张图，x是世界空间x，y是世界空间y，z是世界空间z，先用一个xy做分层吧，混入y可能需要制作一张3dtexture，会让查找变得得不偿失
    public ComputeShader LightGetheringCS;
    private static readonly string DrawkernelString = "DrawIndexTexture";
    private ComputeBuffer LightInfoBuffer;
    private List<LightsInfo> mLightInfoList;
    private static readonly int ShaderLightInfoList = Shader.PropertyToID("_LightsInfo");

    private int DrawIndexTextureKernel;

    //id图的rt
    private RenderTexture LightIndexRT;
    private static readonly int LightIndexRTID = Shader.PropertyToID("_LightIndexTex");
    [SerializeField] private Vector3 TextureSize = new Vector3(256, 256, 32);
    private static readonly int LightTextureSize = Shader.PropertyToID("_LightIndexTex_Size");
    [SerializeField] private Vector3 MapOffset;
    private static readonly int MapOffsetID = Shader.PropertyToID("_MapOffset");
    private static readonly int LightListCount = Shader.PropertyToID("_LightListCount");


    void InitData()
    {
        mLightInfoList = new List<LightsInfo>();
        isDirty = false;
        mLightUpdateTrigger = true;
        mLightList = new List<Light>();
        mCachedLight = new List<LightData>();
        mLightList.Clear();
        mLightList.AddRange(lightGroup.transform.GetComponentsInChildren<Light>());
        ResetRT();
        InitCachedLightData();
        DrawIndexTexture();
        StartCoroutine(CheckIfLightChange());
    }

    private void InitCachedLightData()
    {
        for (int i = 0; i < mLightList.Count; i++)
        {
            mCachedLight.Add(new LightData(mLightList[i]));
        }

        lightNumber = mLightList.Count;
        nowCountNumber = 0;
    }

    

    private void ResetRT()
    {
        RenderTextureDescriptor descriptor =
            new RenderTextureDescriptor((int)TextureSize.x, (int)TextureSize.y, RenderTextureFormat.ARGBHalf);
        descriptor.enableRandomWrite = true;
        //思考：是不是3d也可以呢？如果本来用的就是point，那么3d又有什么消耗呢？
        descriptor.dimension = TextureDimension.Tex3D;
        descriptor.volumeDepth = (int)TextureSize.z;
        LightIndexRT = new RenderTexture(descriptor);
    }

    private void DrawIndexTexture()
    {
        DrawIndexTextureKernel = LightGetheringCS.FindKernel(DrawkernelString);
        LightInfoBuffer ??= new ComputeBuffer(lightNumber, LightsInfo.Size(), ComputeBufferType.Default);
        mLightInfoList.Clear();
        for (int i = 0; i < lightNumber; i++)
        {
            int type = mLightList[i].type == LightType.Spot ? 1 : 0;
            Vector4 position = new Vector4(mLightList[i].transform.position.x, mLightList[i].transform.position.y,
                mLightList[i].transform.position.z, mLightList[i].range);
            Vector4 direction = new Vector4(-mLightList[i].transform.forward.x, -mLightList[i].transform.forward.y,
                -mLightList[i].transform.forward.z,mLightList[i].intensity );
            mLightInfoList.Add(new LightsInfo(mLightList[i].color *mLightList[i].intensity , position, direction,mLightList[i].range,mLightList[i].type,mLightList[i].spotAngle,mLightList[i].innerSpotAngle));
        }

        LightInfoBuffer.SetData(mLightInfoList);
        //向cs里输入需要的数据
        LightGetheringCS.SetVector(LightTextureSize, TextureSize);
        LightGetheringCS.SetVector(MapOffsetID, MapOffset);
        LightGetheringCS.SetInt(LightListCount, lightNumber);
        LightGetheringCS.SetBuffer(DrawIndexTextureKernel, ShaderLightInfoList, LightInfoBuffer);
        LightGetheringCS.SetTexture(DrawIndexTextureKernel, LightIndexRTID, LightIndexRT);
        LightGetheringCS.Dispatch(DrawIndexTextureKernel, (int)TextureSize.x / 8, (int)TextureSize.y / 8,
            (int)TextureSize.z / 8);
        Shader.SetGlobalBuffer(ShaderLightInfoList, LightInfoBuffer);
        Shader.SetGlobalTexture(LightIndexRTID, LightIndexRT);
        Shader.SetGlobalVector(MapOffsetID, MapOffset);
        Shader.SetGlobalVector(LightTextureSize,TextureSize);
    }


    /// <summary>
    /// 用一个协程判断是否需要更新
    /// </summary>
    /// <returns></returns>
    private IEnumerator CheckIfLightChange()
    {
        while (mLightUpdateTrigger)
        {
            for (int i = 0; i < 20; i++)
            {
                if (nowCountNumber == lightNumber)
                {
                    nowCountNumber = 0;
                    DoReset();
                    break;
                }

                if (mLightList[nowCountNumber].transform.hasChanged)
                {
                    mLightList[nowCountNumber].transform.hasChanged = false;
                    isDirty = true;
                }

                if (mLightList[nowCountNumber].intensity != mCachedLight[nowCountNumber].GetIntensity())
                {
                    mCachedLight[nowCountNumber].SetIntensity(mLightList[nowCountNumber].intensity);
                    isDirty = true;
                }

                if (mLightList[nowCountNumber].color != mCachedLight[nowCountNumber].GetLightColor())
                {
                    mCachedLight[nowCountNumber].SetLightColor(mLightList[nowCountNumber].color);
                    isDirty = true;
                }

                if (mLightList[nowCountNumber].range != mCachedLight[nowCountNumber].GetRange())
                {
                    mCachedLight[nowCountNumber].SetRange(mLightList[nowCountNumber].range);
                    isDirty = true;
                }

                if (mLightList[nowCountNumber].spotAngle != mCachedLight[nowCountNumber].GetSpotAngle())
                {
                    mCachedLight[nowCountNumber].SetSpotAngle(mLightList[nowCountNumber].spotAngle);
                    isDirty = true;
                }

                nowCountNumber++;
            }

            yield return null;
        }
    }

    /// <summary>
    /// 首先，传入位置信息，获取最近的几个信息，获取强度信息，获取最近的几个强度，在cs里运算，遍历2遍，然后画入一张图中
    /// </summary>
    private void DoReset()
    {
        //TODO:cs做图，重置rt，感觉不麻烦
        if (isDirty)
        {
            DrawIndexTexture();
            isDirty = false;
        }
    }

    private void OnEnable()
    {
        InitData();
    }

    // Update is called once per frame
    private void OnDisable()
    {
        LightIndexRT.Release();
        if (LightInfoBuffer != null)
        {
            LightInfoBuffer.Release();
            LightInfoBuffer = null;
        }

        mLightInfoList.Clear();
        mLightInfoList = null;
    }
}