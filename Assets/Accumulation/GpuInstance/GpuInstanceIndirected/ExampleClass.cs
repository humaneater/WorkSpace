using UnityEngine;
using System.Collections;

public class ExampleClass : MonoBehaviour
{
    public int instanceCount = 100;
    public Mesh instanceMesh;
    public Material instanceMaterial;
    public int subMeshIndex = 0;
    
    private ComputeBuffer positionBuffer;
    private ComputeBuffer argsBuffer;
    private uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
    private Bounds bounds;

    void Start()
    {
        bounds = new Bounds(transform.position, Vector3.one * 10);
        
        UpdateBuffers();
    }

    void Update()
    {
        // Render
        Graphics.DrawMeshInstancedIndirect(instanceMesh, 0, instanceMaterial, bounds, argsBuffer);
    }


    void UpdateBuffers()
    {
        // Indirect args
        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        args[0] = (uint)instanceMesh.GetIndexCount(0);
        args[1] = (uint)instanceCount;
        args[2] = (uint)instanceMesh.GetIndexStart(0);
        args[3] = (uint)instanceMesh.GetBaseVertex(0);
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);

        // Positions
        positionBuffer = new ComputeBuffer(instanceCount, sizeof(float) * 4);
        Vector4[] positions = new Vector4[instanceCount];
        for (int i = 0; i < instanceCount; i++)
        {
            float x = Random.Range(-20.0f, 20.0f);
            float y = Random.Range(-20.0f, 20.0f);
            float z = Random.Range(-20.0f, 20.0f);
            float w = Random.Range(0.05f, 0.25f);
            positions[i] = new Vector4(x,y,z,w);
        }
        positionBuffer.SetData(positions);
        instanceMaterial.SetBuffer("positionBuffer", positionBuffer);
    }

    void OnDisable()
    {
        if (positionBuffer != null)
            positionBuffer.Release();
        positionBuffer = null;

        if (argsBuffer != null)
            argsBuffer.Release();
        argsBuffer = null;
    }
}