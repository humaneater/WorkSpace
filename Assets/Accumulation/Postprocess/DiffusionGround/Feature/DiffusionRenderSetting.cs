using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DiffusionRenderSetting : MonoBehaviour
{
    [SerializeField] private float mDiffusionValue;
    [SerializeField] private Texture2D mDiffusionTexture;
    [SerializeField] [Range(0,10)]private float timePassBy;
    [SerializeField] private Material mMat;
    [SerializeField] private float angle;
    [SerializeField] private AnimationCurve startCurve;
    [SerializeField] [ColorUsage(true,true)]private Color color;
    
    
    // Start is called before the first frame update
    void Start()
    {
        
        RenderSettingManager.GetInstance().SetDiffusionData(mDiffusionValue,Vector3.zero,mDiffusionTexture,color,angle * Mathf.Deg2Rad,mMat);
    }

    // Update is called once per frame
    private void UpdateData()
    {
        RenderSettingManager.GetInstance().SetDiffusionData(mDiffusionValue,transform.position,mDiffusionTexture,color,angle* Mathf.Deg2Rad,mMat);
    }

    private void OnGUI()
    {
        if (GUI.Button(new Rect(10, 10, 200, 100), "Click me!"))
        {
            timePassBy = 0f;
            mDiffusionValue = 0f;
            UpdateData();
        }
    }

    private void Update()
    {
        if (mDiffusionValue < 300f)
        {
            timePassBy += Time.deltaTime;
            mDiffusionValue += startCurve.Evaluate(timePassBy) * 0.1f;
            UpdateData();
        }
    }

    private void OnDestroy()
    {
        mDiffusionValue = 0f;
        UpdateData();
    }
}
