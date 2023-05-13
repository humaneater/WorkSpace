using System.Collections.Generic;
using UnityEngine;

namespace Game
{
    [ExecuteAlways]
    public class WaterSkillController : MonoBehaviour
    {
        [Range(0f, 1f)] public float mTime = 0f;
        public bool isLighting;
        private float lightningTime = 0f;
        [Header("帧数")] public float spriptTimes = 4f;
        [Header("速度")] public float speed = 1f;
        [Header("偏移")] public float offset = 0f;

        private static List<Vector4> _lightningUVs = new List<Vector4>()
        {
            new Vector4(0.5f, 0.5f, 0f, 0.5f),
            new Vector4(0.5f, 0.5f, 0.5f, 0.5f),
            new Vector4(0.5f, 0.5f, 0f, 0f),
            new Vector4(0.5f, 0.5f, 0.5f, 0)
        };


        private void Update()
        {
            transform.TryGetComponent(out Renderer renderer);
            if (renderer != null)
            {
                lightningTime = lightningTime > 1f ? 0f : lightningTime;
                renderer.sharedMaterial.SetFloat("_GradientTime", mTime);
                if (isLighting)
                {
                    lightningTime += Time.deltaTime * speed;
                    int temp = Mathf.FloorToInt(lightningTime * (spriptTimes));
                    temp = temp > 3 ? 3 : temp;
                    Vector4 random = new Vector4(0f, 0f, Random.Range(-offset, offset), Random.Range(-offset, offset));
                    renderer.sharedMaterial.EnableKeyword("_UseUpperEffect");
                    renderer.sharedMaterial
                        .SetVector("_UpperEffectUV", _lightningUVs[temp] + random);
                }
                else
                {
                    lightningTime = 0f;
                    renderer.sharedMaterial.DisableKeyword("_UseUpperEffect");
                }
            }
        }
    }
}