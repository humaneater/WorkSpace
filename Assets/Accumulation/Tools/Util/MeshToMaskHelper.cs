using UnityEngine;

namespace Game
{
    public static class MeshToMaskHelper
    {
        private static MeshToMaskTexture _meshToMaskTexture;

        public static void GenerateMask(ref Camera orthographicCamera, ref RenderTexture DecalRT, Vector3 center,
            float size, LayerMask mask) =>
            (_meshToMaskTexture ??= new MeshToMaskTexture()).GenerateMask(ref orthographicCamera,ref DecalRT, center, size,mask);

        public static Camera InitOrthographicCamera(LayerMask mask) =>
            (_meshToMaskTexture ??= new MeshToMaskTexture()).InitOrthographicCamera(mask);
    }

    class MeshToMaskTexture
    {


        /// <summary>
        /// 通过一个摄像机拍的一个rt
        /// </summary>
        /// <param name="orthographicCamera"></param>
        /// <param name="decalRT"></param>
        /// <param name="center"></param>
        /// <param name="size"></param>
        public void GenerateMask(ref Camera orthographicCamera, ref RenderTexture decalRT, Vector3 center, float size,LayerMask mask)
        {
            //初始化摄像机位置
            orthographicCamera.transform.position = new Vector3(center.x, center.y + 1f, center.z);
            orthographicCamera.orthographicSize = size/2f;
            orthographicCamera.targetTexture = decalRT;
            orthographicCamera.Render();
            orthographicCamera.targetTexture = null;

        }

        public Camera InitOrthographicCamera(LayerMask mask)
        {
            var gameObject = new GameObject("OrthographicCamera");
            var camera = gameObject.AddComponent<Camera>();
            camera.gameObject.SetActive(false);
            camera.orthographic = true;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = Color.black;
            camera.cullingMask =  mask;
            camera.transform.Rotate(Vector3.right,90f);
            camera.aspect = 1f;
            return camera;
        }

    }
}