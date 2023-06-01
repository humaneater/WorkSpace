using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace PrecomputerScatter
{
    [ExecuteAlways]
    class PrecomputerScatter : MonoBehaviour
    {
        //配置文件
        public Config Config;

        //大气计算模型
        static Model model;

        public bool UpdateRealTime;

        [Range(1, 40)] public uint ScatteringOrder;

        public Material[] debugMat;

        private void Awake()
        {
            Init();
        }

        /*private void OnValidate()
        {
            model?.Init(debugMat);
        }*/

        private void Update()
        {
            if (UpdateRealTime)
            {
                model?.Init(debugMat,ScatteringOrder);
                
            }
        }

        void Init()
        {
            model = new Model(Config);
            model.Init(debugMat,ScatteringOrder);
            Config.Skybox.SetTexture("transmittance_texture", model.Transmittance);
            Config.Skybox.SetTexture("scattering_texture", model.Scattering);
            Config.Skybox.SetTexture("irradiance_texture", model.Irradiance);

            /*if (debugMat != null)
            {
                debugMat.SetTexture("debug_transmittance",model.Transmittance);
            }*/
        }
        
        [ContextMenu("GenHeader")]
        void GetHeader()
        {
            //生成全局Atmosphere实例
            var path = Path.Combine(Application.dataPath, "Accumulation/Postprocess/AtmosphericScattering/scattering/header.hlsl");
            var header = Model.Header(Config.Params, Const.Lambdas);
            File.WriteAllText(path, header);
        }
        
        public (RenderTexture, RenderTexture, RenderTexture) GetTextures() {
            return (model.Transmittance, model.Irradiance, model.Scattering);
        }
    }
}
