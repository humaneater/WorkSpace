using System;
using System.Collections.Generic;
using UnityEngine;
using Random = UnityEngine.Random;

public class ExplosionEffectMaterialController : MonoBehaviour
{
    [SerializeField]
    private Material mExplosionMat;
    private List<Renderer> mExplosionRenderer;
    private readonly int mHighLightValue = Shader.PropertyToID("_ExplosionValue");
    private readonly int mExplosionMatID = Shader.PropertyToID("Effect_AddExplosion");
    public float _HighLightValue;
    public bool isExplosion = false;
    private Action<float> DoExplosion;
    private Action PrePareExplosion;
    
    private float mLastValue;

    private List<Material> tempMats;

    private Vector3 offset;

    private bool exchangeMode = false;
    [SerializeField]
    private GameObject boom;

    private void OnEnable()
    {
        mExplosionRenderer = new List<Renderer>();
        tempMats = new List<Material>();
        Renderer[] renderers = gameObject.GetComponentsInChildren<Renderer>();
        mExplosionRenderer.AddRange(renderers);
        DoExplosion += ExplosionValue;
        PrePareExplosion += StartExplosion;
        offset = new Vector3(Random.Range(0f, 0.1f),Random.Range(0f, 0.05f),Random.Range(0f, 0.05f)); 
    }

  

    private void ExplosionValue(float value)
    {
        if (exchangeMode)
        {
            transform.position += offset;
        }
        else
        {
            transform.position -= offset;
            offset = new Vector3(Random.Range(0f, 0.1f),Random.Range(0f, 0.05f),Random.Range(0f, 0.05f)); 
        }
        
        
        mExplosionMat.SetFloat(mHighLightValue,_HighLightValue);
    }

    private void StartExplosion()
    {
        PrePareExplosion -= StartExplosion;
        for (int i = 0; i < mExplosionRenderer.Count; i++)
        {
            tempMats.Clear();
            tempMats.AddRange(mExplosionRenderer[i].sharedMaterials);
            tempMats.Add(mExplosionMat);
            mExplosionRenderer[i].sharedMaterials = tempMats.ToArray();
        }
    }

    private void Update()
    {
        if (isExplosion)
        {
            PrePareExplosion?.Invoke();
        }
        exchangeMode = !exchangeMode;
        if (_HighLightValue != mLastValue)
        {
            mLastValue = _HighLightValue;
            DoExplosion?.Invoke(_HighLightValue);
        }

        if (_HighLightValue > 0.99f)
        {
            Instantiate(boom);
            boom.transform.position = transform.position;
            boom.GetComponent<ParticleSystem>().Play();
            gameObject.SetActive(false);
        }
    }


    private void OnDestroy()
    {
        DoExplosion -= ExplosionValue;
    }
}