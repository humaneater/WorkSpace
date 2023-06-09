using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class ComputeMultiLights : MonoBehaviour
{
    //拟定一个灯光结构体，因为要变化所以就用class制定了，不知道会不会很大
    private class LightData
    {
        private Color lightColor;
        private float _intensity { get; set; }
        private float spotAngle;
        private float innerAngle;

        public void SetIntensity(float value)
        {
            _intensity = value;
        }

        public float GetIntensity()
        {
            return _intensity;
        }

        public LightData(Light light)
        {
            lightColor = light.color;
            _intensity = light.intensity;
            innerAngle = light.innerSpotAngle;
            spotAngle = light.spotAngle;
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

    private struct LightsInfo
    {
        public Color LightColor;
        public Vector4 LightPosition;
        public Vector4 LightDirection;

        public LightsInfo(Color color, Vector4 position, Vector4 direction)
        {
            LightColor = color;
            LightPosition = position;
            LightDirection = direction;
        }

        public static int Size()
        {
            return sizeof(float) * 4 + sizeof(float) * 4 + sizeof(float) * 4;
        }
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
            Vector4 position = new Vector4(mLightList[i].transform.position.x, mLightList[i].transform.position.y,
                mLightList[i].transform.position.z, mLightList[i].range);
            Vector4 direction = new Vector4(mLightList[i].transform.forward.x, mLightList[i].transform.forward.y,
                mLightList[i].transform.forward.z, mLightList[i].spotAngle);
            mLightInfoList.Add(new LightsInfo(mLightList[i].color,position,direction));
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
    }

    private void Update()
    {
        DrawIndexTexture();
    }


    /// <summary>
    /// 用一个协程判断是否需要更新
    /// </summary>
    /// <returns></returns>
    private IEnumerator CheckIfLightChange()
    {
        while (mLightUpdateTrigger)
        {
            for (int i = 0; i < 2; i++)
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
            Debug.Log("有变化了");
            isDirty = false;
        }
    }

    private void Start()
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
        }
    }
}