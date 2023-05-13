using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class SdfObjectController : MonoBehaviour
{

    public Renderer GroundSDF;
    public Vector4 mMapOffset;
    public List<Texture2D> mSDFTextures;
    private Material SDFMaterial;
    private static readonly int MapOffset = Shader.PropertyToID("_MapOffset");
    private static readonly int LightPosition = Shader.PropertyToID("_LightSourcePosition");
    private static readonly int SDFTexture = Shader.PropertyToID("_SDFTexture");
    void OnEnable()
    {
        SDFMaterial = GroundSDF.sharedMaterial;
        SDFMaterial.SetVector(MapOffset, mMapOffset);
        //制作2darray
        Texture2DArray array =
            new Texture2DArray(mSDFTextures[0].width, mSDFTextures[0].height, mSDFTextures.Count,
                TextureFormat.R8, false);
        for (int i = 0; i < mSDFTextures.Count; i++)
        {
            Graphics.CopyTexture(mSDFTextures[i], 0, 0, array, i, 0);
        }

        SDFMaterial.SetTexture(SDFTexture, array);
    }


    void Update()
    {
        SDFMaterial.SetVector(LightPosition,transform.position);
    }
}
