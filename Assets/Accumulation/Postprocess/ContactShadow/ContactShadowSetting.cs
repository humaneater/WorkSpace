using System;
using UnityEngine;

namespace UnityEngine.Rendering
{
    [ExecuteAlways]
    public class ContactShadowSetting : MonoBehaviour
    {
        public bool isOpen;
        public Transform light;

        private void Update()
        {
            RenderSettingManager.GetInstance().SetContactShadowData(isOpen,light.position);
        }
    }
}