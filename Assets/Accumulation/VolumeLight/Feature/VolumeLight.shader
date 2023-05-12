Shader "PostProcess/VolumeLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {

        Pass
        {
            blend SrcAlpha zero
            ztest always
            zwrite off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "../../ShaderLibrary/CommonFunctions.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST,_MieScatteringFactor;
            float _CameraMaxDistance,_StepCount,_SpeedUp;
            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = float4(v.vertex.xy,0,1);
                #if UNITY_UV_STARTS_AT_TOP
                o.vertex.y = -o.vertex.y;
                #endif
                
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
               
                return o;
            }

            //只能用于一个包围盒，剔除正面的话，半透明就可以只渲染远端得像素，那么就可以按照盒子里的范围进行步进
            //步进得步长也就决定了好了，不过可能会有一些偏差，因为角度不同得步进长度不同可能会出现错误
            //考虑可以用瑞丽散射和一些噪声优化这个图像 delete
            //由于一个盒子可能有剔除的问题，还是暂时选择用全屏得了
            float MieScatteringFunc(float3 lightDir, float3 rayDir)
            {
                //MieScattering公式
                // (1 - g ^2) / (4 * pi * (1 + g ^2 - 2 * g * cosθ) ^ 1.5 )
                //_MieScatteringFactor.x = (1 - g ^ 2) / 4 * pai
                //_MieScatteringFactor.y =  1 + g ^ 2
                //_MieScatteringFactor.z =  2 * g
                float lightCos = dot(lightDir, -rayDir);
                return _MieScatteringFactor.x / pow((_MieScatteringFactor.y - _MieScatteringFactor.z * lightCos), 1.5);
            }

            float4 frag (v2f i) : SV_Target
            {
                float depth =
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                float3 worldPos = GetWorldPositionByDepth(i.uv,depth);
                float3 cameraToWorldDir = worldPos - _WorldSpaceCameraPos;
                float totalLength = length(cameraToWorldDir);
                cameraToWorldDir = normalize(cameraToWorldDir);
                //当总距离大于一定值之后，设定一个终点
                if (totalLength > _CameraMaxDistance)
                {
                    worldPos.xyz = _WorldSpaceCameraPos + cameraToWorldDir * _CameraMaxDistance;
                    totalLength = length(worldPos - _WorldSpaceCameraPos);
                }
                return float4(totalLength.xxx,1);
                
                float deltaA = totalLength / (_StepCount + 0.001);
                float deltaB = totalLength / (_StepCount/_SpeedUp + 0.001);
                float delta = deltaA;

                float3 sumA = 0;
                float3 step = cameraToWorldDir * delta;
                float3 curPos = _WorldSpaceCameraPos + step;
                int lightcount = _AdditionalLightsCount.y > 8 ? 7 : _AdditionalLightsCount.y-1;
                //[unroll(floor(_StepCount * _AdditionalLightsCount.y))]
                for (float j = 0; j < totalLength; j += delta)
                {
                    float3 targetWorldPos = curPos + j * cameraToWorldDir;
                    //[unroll(floor(_AdditionalLightsCount.y))]
                    for (int n = lightcount; n >= 0; n--)
                    {
                        Light light = GetAdditionalPerObjectLight(n, targetWorldPos);
                        delta = light.distanceAttenuation == 0 ? deltaB : deltaA;
                        float atten = AdditionalLightRealtimeShadow(n, targetWorldPos);
                        float mie = MieScatteringFunc(light.direction, cameraToWorldDir);
                        float3 lightRes = atten < 1 ? 0 : light.distanceAttenuation*(30/(_StepCount+0.001)) *  light.color * mie;
                        sumA += lightRes;
                    }
                }

                
                sumA = saturate(sumA);
                return float4(sumA,1);
            }
            ENDHLSL
        }
    }
}
