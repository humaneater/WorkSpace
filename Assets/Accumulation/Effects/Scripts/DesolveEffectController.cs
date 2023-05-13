using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class DesolveEffectController : MonoBehaviour
{
    [Range(0f,1f)]public float mDesolveValue;

    private List<Material> mMats;

    private readonly int desolveTime = Shader.PropertyToID("_DesolveValue");
    private readonly string _DesolveEffect = "_DesolveEffect";


    private void OnEnable()
    {
        mMats = new List<Material>();
        Renderer[] renderers = gameObject.GetComponentsInChildren<Renderer>();
        for (int i = 0; i < renderers.Length; i++)
        {
            mMats.AddRange(renderers[i].sharedMaterials);
        }
        
    }

    private void UpdateDesovleTime(float time)
    {
        if (time >0.9f)
        {
            foreach (var i in mMats)
            {
                i.DisableKeyword(_DesolveEffect);
            }
            return;
        }
        foreach (var i in mMats)
        {
            i.EnableKeyword(_DesolveEffect);
            i.SetFloat(desolveTime,time);
        }
    }

    private void Update()
    {
        UpdateDesovleTime(mDesolveValue);
    }
}
