
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Game
{
    public class LocalTextureGenerate
    {
        private static LocalTextureGenerate _instance;

        public static LocalTextureGenerate GetInstance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = new LocalTextureGenerate();
                    return _instance;
                }

                return _instance;
            }
        }
        
        private LocalTextureHandler _localTextureHandler;

        public RenderTexture Generate(GameObject target, int width, int height, LayerMask mask,
            float rotateAngle = 0f, float scale = 1f) =>
            (_localTextureHandler ??= new LocalTextureHandler()).Generate(target, width, height, mask,
                rotateAngle, scale);

        public void ReleaseRenderTexture(ref RenderTexture rt) =>
            _localTextureHandler.ReleaseRenderTexture(ref rt);


       
    }
    

    class LocalTextureHandler
    {
        private Camera mCam;

        private Transform mCapturePoint;
        private List<Light> addLights;
        private Volume mVolume;

        public RenderTexture Generate(GameObject target, int width, int height, LayerMask mask,
            float rotateAngle, float scale)
        {
            Camera camera = mCam ??= new GameObject("temp", typeof(Camera)).GetComponent<Camera>();
            camera.transform.gameObject.SetActive(false);
            RenderTextureDescriptor descriptor =
                new RenderTextureDescriptor(width, height, GraphicsFormat.R8G8B8A8_SRGB, 0, 0);
            RenderTexture outrt = RenderTexture.GetTemporary(descriptor);
            descriptor =
                new RenderTextureDescriptor(camera.scaledPixelWidth, camera.scaledPixelHeight,
                    GraphicsFormat.R8G8B8A8_SRGB, 0, 0);
            RenderTexture rt = RenderTexture.GetTemporary(descriptor);

            var lastLocalPos = Vector3.zero;
            Transform lastParent = null;
            if (target.transform.parent != null)
            {
                lastParent = target.transform.parent;
                lastLocalPos = target.transform.localPosition;
            }

            mCapturePoint ??= new GameObject().transform;
            mCapturePoint.position = new Vector3(-1000, 0, -1000);
            target.transform.SetParent(mCapturePoint);
            target.transform.localPosition = Vector3.zero;
            BoundingBox AABB = GetAABB(target);

            InitCamera(ref camera, AABB, target, width, height, mask, ref rt, rotateAngle, scale);

            InitAdditiveLight(mCapturePoint, target.transform);

            if (GameObject.FindWithTag("Volume") != null)
            {
                mVolume ??= GameObject.FindWithTag("Volume").GetComponent<Volume>();
            }

            InitBoxVolume(false);

            Light[] light = Light.GetLights(LightType.Directional, default);
            Quaternion lightRotation = light[0].transform.rotation;
            light[0].transform.rotation = camera.transform.rotation;
            light[0].transform.Rotate(light[0].transform.forward, -15f);
            camera.Render();
            InitBoxVolume(true);
            Graphics.Blit(rt, outrt);
            camera.targetTexture = null;
            RenderTexture.ReleaseTemporary(rt);
            light[0].transform.rotation = lightRotation;
            target.transform.SetParent(lastParent);
            target.transform.localPosition = lastLocalPos;

            return outrt;
        }

        private void InitBoxVolume(bool isOpen)
        {
            if (mVolume == null) return;

            
        }

        /// <summary>
        /// 初始化所有灯光数据，总共四个灯，排除平行光，额外光一共四个
        /// 轴向 上y 摄像机正方向-x，摄像机正右方向+z
        /// 0下              1上
        ///         go
        /// 2下              3下
        /// 强弱判断，后亮前暗
        /// 颜色判断，后明前淡
        /// </summary>
        /// <param name="parent"></param>
        private void InitAdditiveLight(Transform parent, Transform target)
        {
            addLights ??= new List<Light>();
            if (addLights.Count != 0)
            {
                return;
            }

            for (int i = 0; i < 4; i++)
            {
                Light light = new GameObject("AddLight" + i, typeof(Light)).GetComponent<Light>();
                light.transform.SetParent(parent);
                light.type = LightType.Spot;
                light.shadows = LightShadows.Soft;
                addLights.Add(light);
            }

            addLights[0].transform.localPosition = new Vector3(-2f, -2f, -2f);
            addLights[0].intensity = 6f; 
            addLights[0].color = new Color(1f, 0.996f, 0.7122f);
            addLights[1].transform.localPosition = new Vector3(2f, 2f, -2f);
            addLights[1].intensity = 20f;
            addLights[1].color = new Color(1f, 0.996f, 0.7122f);
            addLights[2].transform.localPosition = new Vector3(-2f, -2f, -2f);
            addLights[2].color = new Color(0.2019f, 0.6833f, 0.8396f);
            addLights[2].intensity = 3f;
            addLights[3].transform.localPosition = new Vector3(-2f, -2f, 2f);
            addLights[3].color = new Color(0.9433962f, 0.6472629f, 0.4850f);
            addLights[3].intensity = 12f;

            for (int i = 0; i < addLights.Count; i++)
            {
                addLights[i].transform.LookAt(target);
            }
        }

        /// <summary>
        /// 初始化所有相机属性
        /// </summary>
        /// <param name="camera"></param>
        /// <param name="AABB"></param>
        /// <param name="target"></param>
        /// <param name="isRect"></param>
        /// <param name="mask"></param>
        /// <param name="rt"></param>
        /// <param name="rotateAngle"></param>
        /// <param name="scale"></param>
        private void InitCamera(ref Camera camera, BoundingBox AABB, GameObject target, int width,
            int height, LayerMask mask,
            ref RenderTexture rt, float rotateAngle, float scale)
        {
            camera.nearClipPlane = 0.001f;
            camera.farClipPlane = 100f;
            camera.transform.SetPositionAndRotation(AABB.center,target.transform.rotation);
            // camera.transform.position = AABB.center;
            // camera.transform.rotation = target.transform.rotation;
            camera.transform.Rotate(new Vector3(0f, 90f, 0f));
            camera.transform.Rotate(camera.transform.right, -rotateAngle);
            camera.cullingMask = mask;
            camera.clearFlags = CameraClearFlags.Color;
            camera.backgroundColor = new Color(0f, 0f, 0f, 0f);
            camera.targetTexture = rt;
            camera.aspect = ((float)width / (float)height);
            camera.TryGetComponent<UniversalAdditionalCameraData>(out var universalAdditionalCameraData);
            if (universalAdditionalCameraData == null)
            {
                universalAdditionalCameraData = camera.gameObject.AddComponent<UniversalAdditionalCameraData>();
            }

            universalAdditionalCameraData.SetRenderer(3);
            universalAdditionalCameraData.renderPostProcessing = true;
            universalAdditionalCameraData.renderShadows = true;


            CameraOBB(AABB, ref camera, camera.aspect, scale);
        }


        /// <summary>
        /// 根据aabb生成相机的obb，因为只有一个物体，不考虑远平面，全部投射到近平面
        /// 问题1：x最长还是z最长还是y最长，三次判断
        /// 问题2：相对于自身的旋转情况下的面朝方向，实则this.rotation * Vector3.forward，也就是四元数的轴向转换
        /// </summary>
        /// <param name="AABB"></param>
        /// <param name="camera"></param>
        private void CameraOBB(BoundingBox AABB, ref Camera camera, float cameraAspect, float scale)
        {
            float cameraRudio = (float)camera.pixelWidth / (float)camera.pixelHeight;
            Vector3 min = camera.worldToCameraMatrix * AABB.min;
            Vector3 max = camera.worldToCameraMatrix * AABB.max;
            float xDirDis = Mathf.Abs(max.x - min.x);
            float yDirDis = Mathf.Abs(max.y - min.y);
            float zDirDis = Mathf.Abs(max.z - min.z);
            float fov = camera.fieldOfView * 0.5f;
            fov = yDirDis < xDirDis ? fov : fov / cameraRudio;
            float lengthOfGO = 0f;
            lengthOfGO = xDirDis > yDirDis ? xDirDis / cameraAspect : yDirDis;
            float offset = (lengthOfGO * 0.5f) / Mathf.Tan(Mathf.Deg2Rad * (fov));
            offset = lengthOfGO > zDirDis ? offset : offset + (zDirDis * 0.5f);
            offset += camera.nearClipPlane;
            offset = Mathf.Max(0.2f, offset * scale);
            Vector3 objRotation = camera.transform.forward;
            camera.transform.position -= objRotation * (offset);
        }


        struct BoundingBox
        {
            public BoundingBox(Vector3 value)
            {
                min = value;
                max = value;
                size = value;
                center = value;
            }

            public Vector3 min;
            public Vector3 max;
            public Vector3 size;
            public Vector3 center;
        }

        private BoundingBox GetAABB(GameObject go)
        {
            Renderer[] renderers = go.GetComponentsInChildren<Renderer>();
            BoundingBox aabb = new BoundingBox(Vector3.zero);
            if (renderers.Length > 0)
            {
                aabb.min += renderers[0].bounds.min;
                aabb.max += renderers[0].bounds.max;
                //aabb.center += renderers[0].bounds.center;
                for (int i = 1; i < renderers.Length; i++)
                {
                    aabb.min.x = aabb.min.x < renderers[i].bounds.min.x ? aabb.min.x : renderers[i].bounds.min.x;
                    aabb.min.y = aabb.min.y < renderers[i].bounds.min.y ? aabb.min.y : renderers[i].bounds.min.y;
                    aabb.min.z = aabb.min.z < renderers[i].bounds.min.z ? aabb.min.z : renderers[i].bounds.min.z;
                    aabb.max.x = aabb.max.x > renderers[i].bounds.max.x ? aabb.max.x : renderers[i].bounds.max.x;
                    aabb.max.y = aabb.max.y > renderers[i].bounds.max.y ? aabb.max.y : renderers[i].bounds.max.y;
                    aabb.max.z = aabb.max.z > renderers[i].bounds.max.z ? aabb.max.z : renderers[i].bounds.max.z;
                }
                
            }

            aabb.size = aabb.max - aabb.min;
            aabb.center = aabb.min + aabb.size / 2.0f;
            return aabb;
        }

        public void ReleaseRenderTexture(ref RenderTexture rt)
        {
            RenderTexture.ReleaseTemporary(rt);
        }

        public void Destory()
        {
            mCam = null;
            addLights = null;
            mVolume = null;
        }
    }
}