using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


[Serializable, VolumeComponentMenu("MyPostProcess/VolumeLight")]
public class VolumeLightVolume : VolumeComponent
{
    [Header("开关")] public BoolParameter mTrigger = new BoolParameter(false);
    [Header("步长")] public ClampedFloatParameter mStep = new ClampedFloatParameter(1f, 0f, 10f);
    [Header("跳跃速度")] public ClampedIntParameter mSpeed = new ClampedIntParameter(1, 1, 4);
    [Header("步进最远距离")] public FloatParameter mMaxDistance = new FloatParameter(20);
    public bool IsActive() => mTrigger.value;
}