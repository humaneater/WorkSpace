using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace PrecomputerScatter
{
    [CreateAssetMenu(fileName = "PrecomputerConfig",menuName = "ScriptableObjects/PrecomputerScatterConfig")]
    class Config : ScriptableObject
    {
        public Material Skybox;
        //计算Transmittance的shader，Transmittance是光穿越一段距离后，在原始方向剩下的比例
        public Shader ComputeTransmittance;
        //计算地面受到的直接光照的shader
        public Shader ComputeDirectIrradiance;

        //计算单次散射的shader
        public Shader ComputeSingleScattering;
        //计算大气密度的shader
        public Shader ComputeScatteringDensity;

        //计算地面受到大气散射的间接光照
        public Shader ComputeIndirectIrradiance;

        //计算高阶散射
        public Shader ComputeMultipleScattering;

        //大气模型参数
        public ModelParams Params = Const.DefaultParam();
    }   
}

