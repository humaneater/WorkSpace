using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ComputeMultiLights : MonoBehaviour
{
    public GameObject lightGroup;

    private List<Light> mLightList;
    private List<LightData> mCachedLight;

    // Start is called before the first frame update
    private int lightNumber;
    private int nowCountNumber;
    private bool mTrigger;

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

    void InitData()
    {
        mTrigger = true;
        mLightList = new List<Light>();
        mCachedLight = new List<LightData>();
        mLightList.Clear();
        mLightList.AddRange(lightGroup.transform.GetComponentsInChildren<Light>());
        InitCachedLightData();
        lightNumber = mLightList.Count;
        nowCountNumber = 0;
        StartCoroutine(CheckIfLightChange());
    }

    private void InitCachedLightData()
    {
        for (int i = 0; i < mLightList.Count; i++)
        {
            mCachedLight.Add(new LightData(mLightList[i]));
        }
    }

    private IEnumerator CheckIfLightChange()
    {
        while (mTrigger)
        {
            for (int i = 0; i < 2; i++)
            {
                if (nowCountNumber == lightNumber)
                {
                    nowCountNumber = 0;
                    break;
                }

                if (mLightList[nowCountNumber].transform.hasChanged)
                {
                    mLightList[nowCountNumber].transform.hasChanged = false;
                    DoReset();
                }

                if (mLightList[nowCountNumber].intensity != mCachedLight[nowCountNumber].GetIntensity())
                {
                    mCachedLight[nowCountNumber].SetIntensity(mLightList[nowCountNumber].intensity);
                    DoReset();
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
        Debug.Log("有变化了");
    }

    private void Start()
    {
        InitData();
    }

    // Update is called once per frame
    void Update()
    {
    }
}