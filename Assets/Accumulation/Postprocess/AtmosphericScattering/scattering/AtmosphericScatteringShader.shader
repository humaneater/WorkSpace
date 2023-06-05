Shader "PostPorcess/AtmosphericScattering"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Alpha("alpha",range(0,1)) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            blend one one
            ztest always
            zwrite off
            HLSLPROGRAM
            #define COMBINED_SCATTERING_TEXTURES 1
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
            #include "Assets/Accumulation/Postprocess/AtmosphericScattering/scattering/Function.hlsl"

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
            float4 _MainTex_ST;


            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = float4(v.vertex.xy, 0, 1);
                #if UNITY_UV_STARTS_AT_TOP
                o.vertex.y = -o.vertex.y;
                #endif

                o.uv = v.uv;

                return o;
            }

            float3 GetPrecomputedScattering(AtmosphereParameter atmosphere, float3 camera, float3 viewDir,
                                            float3 LightDir, out float3 transmittance)
            {
                camera /= 1000.0f;
                camera += float3(0, 6360.0f, 0);

                float3 res = GetSkyRadiance(atmosphere, _TransmittanceLUT, _MultiScatteringTex, _MultiScatteringTex,
                                            camera,
                                            viewDir, LightDir, transmittance);
                return res;
            }

            float3 GetPrecomputedScatteringToPoint(AtmosphereParameter atmosphere, float3 cameraPos, float3 worldPos,
                                                   float3 lightDir, out float3 transmittance)
            {
                cameraPos /= 1000.0f;
                cameraPos += float3(0, 6360.0f, 0);
                worldPos /= 1000.0f;
                worldPos += float3(0, 6360.0f, 0);
                float3 res = GetSkyRadianceToPoint(atmosphere, _TransmittanceLUT, _MultiScatteringTex,
                                                   _MultiScatteringTex, cameraPos, worldPos, 0, lightDir,
                                                   transmittance);
                return res;
            }

            float4 frag(v2f i):SV_Target
            {
                float3 lightDir = normalize(_MainLightPosition.xyz);
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                float3 worldPos = GetWorldPositionByDepth(i.uv, depth);
                float4 shadowcoord = TransformWorldToShadowCoord(worldPos);
                float atten = MainLightRealtimeShadow(shadowcoord);

                float3 viewRay = worldPos - _WorldSpaceCameraPos;
                viewRay = normalize(viewRay);
                float3 transmittance;
                float3 res = 0;
                AtmosphereParameter atmosphere = (AtmosphereParameter)0;
                atmosphere = InitAtmosphereParameter(atmosphere, 6420, 6360);
                if (depth == 0.0f)
                {
                    res = GetPrecomputedScattering(atmosphere, _WorldSpaceCameraPos, viewRay, lightDir, transmittance);
                    res *= transmittance;
                }
                else
                {
                    res = GetPrecomputedScatteringToPoint(atmosphere, _WorldSpaceCameraPos, worldPos, lightDir,
                                                          transmittance);
                    res *= transmittance;
                    res *= 5.0f;
                }


                return float4(res, 1);
            }
            ENDHLSL
        }
    }
}