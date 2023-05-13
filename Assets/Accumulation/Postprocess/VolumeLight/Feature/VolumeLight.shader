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
            blend one zero
            ztest always
            zwrite off
            HLSLPROGRAM
            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING

            #pragma vertex vert
            #pragma fragment frag

            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"

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
            float4 _MainTex_ST, _MieScatteringFactor;
            float _CameraMaxDistance, _StepCount, _SpeedUp;


            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = float4(v.vertex.xy, 0, 1);
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
                float lightCos = dot(lightDir, rayDir);
                return _MieScatteringFactor.x / pow((_MieScatteringFactor.y - _MieScatteringFactor.z * lightCos), 1.5);
            }

            float4 frag(v2f i) : SV_Target
            {
                float dither = Unity_Dither_float4(i.vertex);
                float depth =
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                float3 worldPos = GetWorldPositionByDepth(i.uv, depth);
                float3 cameraToWorldDir = worldPos - _WorldSpaceCameraPos;
                float totalLength = length(cameraToWorldDir);
                cameraToWorldDir = normalize(cameraToWorldDir);
                //当总距离大于一定值之后，设定一个终点
                if (totalLength > _CameraMaxDistance)
                {
                    worldPos.xyz = _WorldSpaceCameraPos + cameraToWorldDir * _CameraMaxDistance;
                    totalLength = length(worldPos - _WorldSpaceCameraPos);
                }
                float deltaA = totalLength / max(0.001f, _StepCount);
                float deltaB = totalLength / max(0.001f, _StepCount / _SpeedUp);
                float delta = deltaA;
                float3 sum = 0;
                float3 step = cameraToWorldDir * delta;
                float3 curPos = _WorldSpaceCameraPos + step;
                int lightcount = _AdditionalLightsCount.x > 8 ? 7 : _AdditionalLightsCount.x - 1;
                //步进次数
                for (float j = 0; j < totalLength; j += delta)
                {
                    float3 targetWorldPos = curPos + (j+ dither*0.8f) * cameraToWorldDir ;
                    for (int n = 0; n < lightcount; n++)
                    {
                        //TODO：灯可以用自己直传的值，没必要通过unity的收集，因为用到这个的也不太多嘛
                        Light light = GetAdditionalPerObjectLight(n, targetWorldPos);
                        delta = light.distanceAttenuation == 0 ? deltaB : deltaA;
                        float atten = AdditionalLightRealtimeShadow(n, targetWorldPos);
                        float mie = MieScatteringFunc(light.direction, cameraToWorldDir);
                        float3 lightRes = atten > 0 ? light.color * light.distanceAttenuation * mie : 0;
                        sum += lightRes;
                    }
                }

                //sum = saturate(sum);
                return float4(sum, 1);
            }
            ENDHLSL
        }

        //模糊
        pass
        {
            blend one zero
            ztest always
            zwrite off
            HLSLPROGRAM
            #include "../../ShaderLibrary/CommonFunctions.hlsl"
            #pragma vertex vert
            #pragma fragment frag

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

            sampler2D _MainTex, _VolumeLightTex;
            float4 _MainTex_ST, _VolumeLightTex_TexelSize;
            float _BlurValue;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = float4(v.vertex.xy, 0, 1);
                #if UNITY_UV_STARTS_AT_TOP
                o.vertex.y = -o.vertex.y;
                #endif

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            }

            //是下来dither和卷积不太配，不妨试试硬件插值的多次blit，bloom方案
            float4 frag(v2f i):SV_Target
            {
                _VolumeLightTex_TexelSize *= _BlurValue;
                float3 res = tex2D(_VolumeLightTex, i.uv);
                 res += tex2D(_VolumeLightTex, i.uv + _VolumeLightTex_TexelSize.xy);
                 res += tex2D(_VolumeLightTex, i.uv - _VolumeLightTex_TexelSize.xy);
                res += tex2D(_VolumeLightTex, float2(i.uv.x - _VolumeLightTex_TexelSize.x, i.uv.y));
                res += tex2D(_VolumeLightTex, float2(i.uv.x + _VolumeLightTex_TexelSize.x, i.uv.y));
                res += tex2D(_VolumeLightTex, float2(i.uv.x, i.uv.y + _VolumeLightTex_TexelSize.y));
                res += tex2D(_VolumeLightTex, float2(i.uv.x, i.uv.y - _VolumeLightTex_TexelSize.y));
                res += tex2D(_VolumeLightTex,
                             float2(i.uv.x + _VolumeLightTex_TexelSize.x, i.uv.y - _VolumeLightTex_TexelSize.y));
                res += tex2D(_VolumeLightTex,
                             float2(i.uv.x - _VolumeLightTex_TexelSize.x, i.uv.y + _VolumeLightTex_TexelSize.y));
                res /= 9;
                return float4(res, 1);
            }
            ENDHLSL

        }

        //上屏
        pass
        {
            blend one one
            ztest always
            zwrite off
            HLSLPROGRAM
            #include "../../ShaderLibrary/CommonFunctions.hlsl"
            #pragma vertex vert
            #pragma fragment frag

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

            sampler2D _MainTex, _VolumeLightTemp;
            float4 _MainTex_ST, _VolumeLightTex_TexelSize;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = float4(v.vertex.xy, 0, 1);
                #if UNITY_UV_STARTS_AT_TOP
                o.vertex.y = -o.vertex.y;
                #endif

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                float3 res = tex2D(_VolumeLightTemp, i.uv);
                return float4(res, 1);
            }
            ENDHLSL

        }
    }
}