using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


[Serializable, VolumeComponentMenu("MyPostProcess/VolumeLight")]
public class VolumeLightVolume : VolumeComponent
{
    [Header("开关")] public BoolParameter mTrigger = new BoolParameter(false);
    [Header("米散射强度")] public ClampedFloatParameter mMieStrength = new ClampedFloatParameter(1f,0f,2f);
    [Header("米散射扩散")] public ClampedFloatParameter mMieY = new ClampedFloatParameter(1f,1f,10f);
    [Header("米散射散射幅度")] public ClampedFloatParameter mMieScatter = new ClampedFloatParameter(1f,0f,1f);
    [Header("步长")] public ClampedFloatParameter mStep = new ClampedFloatParameter(1f, 0f, 10f);
    [Header("跳跃速度")] public ClampedIntParameter mSpeed = new ClampedIntParameter(1, 1, 4);
    [Header("步进最远距离")] public FloatParameter mMaxDistance = new FloatParameter(20);
    [Header("步进次数")] public ClampedIntParameter mStepCount = new ClampedIntParameter(1, 1, 20);
    [Header("模糊幅度")] public ClampedFloatParameter mBlueValue = new ClampedFloatParameter(1f,0.5f,10f);
    [Header("降分辨率")] public ClampedIntParameter mDownSampling = new ClampedIntParameter(1,1,4);
    public bool IsActive() => mTrigger.value;
}