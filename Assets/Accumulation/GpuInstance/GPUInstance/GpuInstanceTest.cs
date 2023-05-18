using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Random = UnityEngine.Random;

[ExecuteAlways]
public class GpuInstanceTest : MonoBehaviour
{
    [SerializeField] private Mesh mMesh;
    [SerializeField] private int mGpuInstanceCount;
    [SerializeField] private Material mMat;
    private List<Matrix4x4> mInstanceMatrix;
    private List<Vector4> colors;
    private MaterialPropertyBlock materialBlock;

    private void PrepareData()
    {
        if (mMesh == null || mMat == null)
        {
            Debug.LogError("mesh丢了！！");
            return;
        }

        mInstanceMatrix ??= new List<Matrix4x4>();
        colors ??= new List<Vector4>();
        materialBlock = new MaterialPropertyBlock();
        colors.Clear();
        mInstanceMatrix.Clear();

        for (int i = 0; i < mGpuInstanceCount; i++)
        {
            Matrix4x4 temp = Matrix4x4.identity;
            float x = Random.Range(-20, 20);
            float y = Random.Range(-20, 20);
            float z = Random.Range(-20, 20);
            temp.SetColumn(3,new Vector4(x,y,z,1));
            mInstanceMatrix.Add(temp);
            Vector3 A = new Vector3(Random.Range(0f,1f), Random.Range(0f,1f), Random.Range(0f,1f));
            colors.Add(A);
        }

        materialBlock.SetVectorArray("_Color", colors.ToArray());

    }

    void Start()
    {
        PrepareData();
    }

    // Update is called once per frame
    void Update()
    {
        if (mMesh == null || mMat == null)
        {
            Debug.LogError("mesh丢了！！");
            return;
        }
        Graphics.DrawMeshInstanced(mMesh,0,mMat,mInstanceMatrix.ToArray(),mInstanceMatrix.Count,materialBlock,ShadowCastingMode.On,true);
    }

    private void OnGUI()
    {
        if (GUI.Button(new Rect(10, 10, 200, 100),"Click It!"))
        {
            PrepareData();
        }
    }
}