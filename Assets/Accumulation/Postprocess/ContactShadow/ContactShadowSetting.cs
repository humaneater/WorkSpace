using System;
using UnityEngine;

namespace UnityEngine.Rendering
{
    [ExecuteAlways]
    public class ContactShadowSetting : MonoBehaviour
    {
        public Transform light;

        private void Update()
        {
            RenderSettingManager.GetInstance().SetContactShadowData(light.position);
        }
    }
}