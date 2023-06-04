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
            blend one zero
            ztest always
            zwrite off
            HLSLPROGRAM
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
            float3 GetPrecomputedScattering(float r,float mu, float nu, float mu_s,bool ray_r_mu_intersects_ground)
            {
                AtmosphereParameter atmosphere = (AtmosphereParameter) 0;
                atmosphere = InitAtmosphereParameter(atmosphere,6420,6360);
                return GetScattering(atmosphere,_MultiScatteringTex,r,mu,mu_s,nu,false);
            }

            float4 frag(v2f i):SV_Target
            {
                float3 lightDir = normalize(_MainLightPosition.xyz);
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                float3 worldPos = GetWorldPositionByDepth(i.uv,depth);
                float3 viewDir = _WorldSpaceCameraPos - worldPos;
                viewDir = normalize(viewDir);
                worldPos /= 1000.0f;
                worldPos += float3(0,6360.0f,0);
                float r = length(worldPos);
                float3 up = float3(0,1.0f,0);
                float mu = dot(-viewDir,up)/1.0f;
                float mu_s = dot(worldPos,lightDir)/r;
                float nu = dot(worldPos,-viewDir)/r;
                bool ray_r_mu_intersects_ground;
                if (depth >0.0001f)
                {
                    ray_r_mu_intersects_ground = true;
                }
                else
                {
                    ray_r_mu_intersects_ground = false;
                }
                float3 res = GetPrecomputedScattering(r,mu,nu,mu_s,ray_r_mu_intersects_ground);
                return float4(res,1);
            }
            ENDHLSL
        }
    }
}