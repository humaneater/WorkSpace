using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Random = UnityEngine.Random;

public class GrassInstance : MonoBehaviour
{
    [SerializeField] private Mesh grass;

    [SerializeField] private int Count;
    [SerializeField] private Material mInstanceMat;

    [SerializeField] private List<InstanceMatrix> drawMatrix;
    private Bounds bounds;

    public Vector3 starPosition;
    public Vector3 endPosition;

    private bool dirty;

    private RaycastHit[] hit;

    private ComputeBuffer meshPropertiesBuffer;
    private ComputeBuffer argsBuffer;
    private ComputeBuffer CullingResultBuffer;
    [SerializeField] private ComputeShader CullingCS;

    private static readonly string InstanceProperties = "_PropertisMatrix";
    private LayerMask layer;
    private Camera mainCamera;


    private void Start()
    {
        depthHandle.Init("_CameraDepthAttachment");
        mainCamera = Camera.main;
        hit = new RaycastHit[5];
        layer = LayerMask.GetMask("Terrain");
        GetherData();
    }

    private struct InstanceMatrix
    {
        public Matrix4x4 transformMatrix;
        public Matrix4x4 transformMatrix_I_M;
        public Color color;

        public InstanceMatrix(Matrix4x4 M, Matrix4x4 IM, Color C)
        {
            transformMatrix = M;
            transformMatrix_I_M = IM;
            color = C;
        }

        public static int Size()
        {
            return sizeof(float) * 16 * 2 + sizeof(float) * 4;
        }
    }

    private void GetherData()
    {
        if (endPosition.x < starPosition.x || endPosition.z < starPosition.z)
        {
            Debug.LogError("终止点小于起始点");
            return;
        }

        bounds = new Bounds(starPosition + (endPosition - starPosition) / 2, endPosition - starPosition);
        if (drawMatrix == null || dirty)
        {
            InitializeData();
        }
    }

    private RaycastHit hits;

    private void InitializeData()
    {
        drawMatrix ??= new List<InstanceMatrix>();

        for (float i = 0; i < bounds.size.x; i += 1f)
        {
            for (float j = 0; j < bounds.size.z; j += 1f)
            {
                Vector3 shoter = bounds.min +
                                 new Vector3(i + Random.Range(0.8f, 1.2f), 200f, j + Random.Range(0.8f, 1.2f));

                Ray ray = new Ray(shoter, Vector3.down);
                if (Physics.RaycastNonAlloc(ray, hit, 400f) > 0)
                {
                    Vector3 position = hit[0].point;
                    Quaternion rotation =
                        Quaternion.Euler(0f, Random.Range(-180, 180), 0f);
                    Vector3 size = new Vector3(Random.Range(0.8f, 1.2f), Random.Range(2f, 4f),
                        Random.Range(0.8f, 1.2f));
                    Matrix4x4 mat = Matrix4x4.TRS(position, rotation, size);
                    Matrix4x4 matIM = mat.inverse;
                    Color color = Color.green;
                    drawMatrix.Add(new InstanceMatrix(mat, matIM, color));
                }
            }
        }

        meshPropertiesBuffer = new ComputeBuffer(drawMatrix.Count, InstanceMatrix.Size());
        meshPropertiesBuffer.SetData(drawMatrix);
        //mInstanceMat.SetBuffer(InstanceProperties, meshPropertiesBuffer);

        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        //arg buffer used by draw instance indirectly
        args[0] = (uint)grass.GetIndexCount(0);
        args[1] = (uint)Count;
        args[2] = (uint)grass.GetIndexStart(0);
        args[3] = (uint)grass.GetBaseVertex(0);
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);
    }

    private static readonly string m_Kernel = "CSMain";
    private static readonly int CSInputMat = Shader.PropertyToID("_InputMatrix");
    private static readonly int MVMatrix = Shader.PropertyToID("_WorldToCameraMatrix");
    private RenderTargetHandle depthHandle;
    private int CameraDepthTextureID = Shader.PropertyToID("_CameraDepthTexture");
    private int depthTextureSizeX = Shader.PropertyToID("depthTextureSizeX");
    private int depthTextureSizeY = Shader.PropertyToID("depthTextureSizeY");
    public RenderTexture depthRT;

    private void CullByProjector()
    {
        CullingResultBuffer ??= new ComputeBuffer(drawMatrix.Count, InstanceMatrix.Size(), ComputeBufferType.Append);
        Matrix4x4 P = GL.GetGPUProjectionMatrix(mainCamera.projectionMatrix, false);
        Matrix4x4 V = mainCamera.worldToCameraMatrix;
        Matrix4x4 VP = P * V;
        //准备cs
        if (CullingCS != null)
        {
            int kernel = CullingCS.FindKernel(m_Kernel);
            CullingCS.SetBuffer(kernel, CSInputMat, meshPropertiesBuffer);
            CullingResultBuffer.SetCounterValue(0);
            CullingCS.SetBuffer(kernel, InstanceProperties, CullingResultBuffer);
            CullingCS.SetMatrix(MVMatrix, VP);
            //获取深度图
            
            CullingCS.SetTexture(kernel, CameraDepthTextureID, depthRT);
            CullingCS.SetInt(depthTextureSizeX,depthRT.width);
            CullingCS.SetInt(depthTextureSizeY,depthRT.height);
            CullingCS.Dispatch(kernel, (meshPropertiesBuffer.count / 640), 1, 1);
            ComputeBuffer.CopyCount(CullingResultBuffer, argsBuffer, sizeof(uint));
            mInstanceMat.SetBuffer(InstanceProperties, CullingResultBuffer);
            int[] count = new int[5] { 0, 0, 0, 0, 0 };
            argsBuffer.GetData(count);
            Debug.Log("数量:" + count[1]);
        }
    }

  

    private void Update()
    {
        CullByProjector();
        Graphics.DrawMeshInstancedIndirect(grass, 0, mInstanceMat, bounds, argsBuffer);
    }

    private void OnDisable()
    {
        if (meshPropertiesBuffer != null)
        {
            meshPropertiesBuffer.Release();
            meshPropertiesBuffer.Dispose();
        }

        meshPropertiesBuffer = null;

        if (argsBuffer != null)
        {
            argsBuffer.Release();
            argsBuffer.Dispose();
        }

        argsBuffer = null;

        if (CullingResultBuffer != null)
        {
            CullingResultBuffer.Release();
            CullingResultBuffer.Dispose();
        }

        CullingResultBuffer = null;
    }

    private void OnDestroy()
    {
        OnDisable();
    }
}