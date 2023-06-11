using System;
using System.IO;
using UnityEditor;
using UnityEngine;

#if UNITY_EDITOR
public class SDFGenerater : EditorWindow
{
    private GameObject mShooter;
    public float startX;
    public float startY;
    public float startZ;
    private int countZ;
    private Color[] SDFValue;
    private static LayerMask layerMask;
    public int mTexSize;
    public string mOutputPath;
    public string mName;
    public float mUnit = 0.5f;

    [MenuItem("Tools/SDFGenerater")]
    private static void Init()
    {
        SDFGenerater sdfGenerater = GetWindow<SDFGenerater>();
        sdfGenerater.Show();
    }

    public void OnGUI()
    {
        EditorGUILayout.BeginVertical("GroupBox");
        startX = EditorGUILayout.FloatField("起始点x", startX);
        startY = EditorGUILayout.FloatField("起始点Y", startY);
        startZ = EditorGUILayout.FloatField("起始点z", startZ);
        mUnit = EditorGUILayout.FloatField("几米为一次检索单位", mUnit);
        EditorGUILayout.EndVertical();
        EditorGUILayout.BeginVertical("GroupBox");
        mTexSize = EditorGUILayout.IntField("图片大小:", mTexSize);
        mName = EditorGUILayout.TextField("图片名称", mName);
        EditorGUILayout.EndVertical();
        EditorGUILayout.BeginHorizontal("GroupBox");
        if (GUILayout.Button("预览", GUILayout.Width(50f)))
        {
            var pathtemp = EditorUtility.OpenFolderPanel("选择文件夹", Application.dataPath, "");
            var index = pathtemp.IndexOf("Assets", StringComparison.Ordinal);
            mOutputPath = pathtemp.Substring(index, pathtemp.Length - index);
        }
        mOutputPath = EditorGUILayout.TextField("输出路径：", mOutputPath);
        EditorGUILayout.EndHorizontal();
        if (GUILayout.Button(" 开始 "))
        {
            Drawline();
        }
    }

    private void InitData()
    {
        layerMask = LayerMask.GetMask("Block");
        mShooter = new GameObject("sdfGenerate");
        mShooter.transform.position = new Vector3(startX, startY, startZ);
        countZ = 0;
        SDFValue = new Color[mTexSize * mTexSize];
    }


    void Drawline()
    {
        InitData();
        for (; countZ < mTexSize; countZ++)
        {
            for (int i = 0; i < mTexSize; i++)
            {
                Color a = new Color();
                a.r = DrawLine();
                mShooter.transform.position = new Vector3(mShooter.transform.position.x + mUnit,
                    mShooter.transform.position.y, mShooter.transform.position.z);
                SDFValue[countZ * mTexSize + i] = a / 255.0f;
            }

            mShooter.transform.position =
                new Vector3(startX, mShooter.transform.position.y, mShooter.transform.position.z + mUnit);
        }

        DrawTexture();
        DestroyImmediate(mShooter);
    }


    public float DrawLine()
    {
        float c = 255f;
        if (Physics.OverlapSphere(mShooter.transform.position, 0.5f,layerMask).Length != 0)
        {
            return 0f;
        }

        for (int i = 0; i < 360; i++)
        {
            mShooter.transform.Rotate(new Vector3(0, 1f, 0));
            RaycastHit hit;
            if (Physics.Raycast(mShooter.transform.position, mShooter.transform.forward, out hit, 255f, layerMask))
            {
                //Debug.DrawLine(hit.point, mShooter.transform.position,Color.red);
                float cc = Vector3.Distance(hit.point, mShooter.transform.position);
                c = cc < c ? cc : c;
            }
        }

        return c;
    }

    private void DrawTexture()
    {
        Texture2D tex = new Texture2D(mTexSize, mTexSize, TextureFormat.R8, false);
        tex.SetPixels(SDFValue);
        tex.Apply();
        //byte[] texBytes = tex.EncodeToTGA();
        // var path = "Assets/Arts/TA/Test/";
        var outpath = Path.Combine(mOutputPath, mName+".asset");
        AssetDatabase.CreateAsset(tex, outpath);
        //File.WriteAllBytes(path + "sdf.png",texBytes);
        AssetDatabase.Refresh();
    }
}
#endif