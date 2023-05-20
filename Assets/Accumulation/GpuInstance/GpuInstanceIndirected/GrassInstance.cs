using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing.Drawing2D;
using UnityEngine;
using Random = UnityEngine.Random;

public class GrassInstance : MonoBehaviour
{
    [SerializeField] private Mesh grass;

    private Bounds bounds;

    public Vector3 starPosition;

    public Vector3 endPosition;

    [SerializeField] private List<InstanceMatrix> drawMatrix;

    private bool dirty;

    private RaycastHit[] hit;

    private ComputeBuffer meshPropertiesBuffer;
    private ComputeBuffer argsBuffer;

    [SerializeField] private Material mInstanceMat;

    private static readonly string InstanceProperties = "_PropertisMatrix";
    private LayerMask layer;


    private void Start()
    {
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
                Vector3 shoter = bounds.min + new Vector3(i+Random.Range(0.8f, 1.2f), 200f, j+Random.Range(0.8f, 1.2f));
              
                Ray ray = new Ray(shoter, Vector3.down);
                if ( /*Physics.RaycastNonAlloc(ray,hit,400f,layer) > 0*/Physics.Raycast(ray, out hits, 200))
                {
                    Vector3 position = hits.point;
                    Quaternion rotation =
                        Quaternion.Euler(0f, Random.Range(-180, 180), 0f);
                    Vector3 size = new Vector3(Random.Range(0.8f, 1.2f), Random.Range(2f,4f),
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
        mInstanceMat.SetBuffer(InstanceProperties, meshPropertiesBuffer);

        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        //arg buffer used by draw instance indirectly
        args[0] = (uint)grass.GetIndexCount(0);
        args[1] = (uint)drawMatrix.Count;
        args[2] = (uint)grass.GetIndexStart(0);
        args[3] = (uint)grass.GetBaseVertex(0);
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);
    }

    private void Update()
    {
        Graphics.DrawMeshInstancedIndirect(grass, 0, mInstanceMat, bounds, argsBuffer);
    }
}