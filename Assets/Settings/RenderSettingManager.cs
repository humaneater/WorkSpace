using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEditorInternal;
using UnityEngine;

namespace UnityEngine.Rendering
{
    public class RenderSettingManager
    {
        private static RenderSettingManager _instance;

        public static RenderSettingManager GetInstance()
        {
            if (_instance == null)
            {
                _instance = new RenderSettingManager();
                _instance.Init();
                return _instance;
            }

            return _instance;
        }

        public void Init()
        {
            _diffusionData.Reset();
            _contactShadowData.Reset();
        }

        private void OnDestory()
        {
            _instance = null;
        }


        #region diffusionScanLine

        public struct DiffusionData
        {
            public bool isOpen;
            internal Vector4 DiffusionStartPosition;
            internal float DiffusionValue;
            internal Texture2D GridTexture;
            internal Color Color;
            internal Material Mat;

            public void Reset()
            {
                isOpen = false;
            }
        }

        private DiffusionData _diffusionData = new DiffusionData();

        public DiffusionData GetDiffusionData()
        {
            return _diffusionData;
        }

        public void SetDiffusionData(bool isOpen,float diffusionValue, Vector3 position, Texture2D gridTexture, Color color,
            float angle, Material mat)
        {
            _diffusionData.isOpen = isOpen;
            Vector4 positionA = new Vector4(position.x, position.y, position.z, angle);
            _diffusionData.DiffusionValue = diffusionValue;
            _diffusionData.DiffusionStartPosition = positionA;
            _diffusionData.GridTexture = gridTexture;
            _diffusionData.Color = color;
            _diffusionData.Mat = mat;
        }

        #endregion

        #region ContactShadow

        public struct ContactShadowData
        {
            public bool isOpen;
            internal Vector4 LightsPosition;

            public void Reset()
            {
                isOpen = false;
            }
        }

        private ContactShadowData _contactShadowData = new ContactShadowData();

        public ContactShadowData GetContactShadow()
        {
            return _contactShadowData;
        }

        public void SetContactShadowData(bool isOpen,Vector4 position)
        {
            _contactShadowData.isOpen = isOpen;
            _contactShadowData.LightsPosition = position;
        }



        #endregion
    }
}