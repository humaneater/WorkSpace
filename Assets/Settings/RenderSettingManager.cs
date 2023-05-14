using System.Collections.Generic;
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
                return _instance;
            }

            return _instance;
        }


        public struct DiffusionData
        {
            internal Vector4 DiffusionStartPosition;
            internal float DiffusionValue;
            internal Texture2D GridTexture;
            internal Color Color;
            internal Material Mat;
        }

        private DiffusionData _diffusionData = new DiffusionData();

        public DiffusionData GetDiffusionData()
        {
            return _diffusionData;
        }

        public void SetDiffusionData(float diffusionValue,Vector3 position,Texture2D gridTexture,Color color,float angle)
        {
            Vector4 positionA = new Vector4(position.x, position.y, position.z, angle);
            _diffusionData.DiffusionValue = diffusionValue;
            _diffusionData.DiffusionStartPosition = positionA;
            _diffusionData.GridTexture = gridTexture;
            _diffusionData.Color = color;
        }
    }
}