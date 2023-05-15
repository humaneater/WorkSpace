Shader "PostProcess/ContactShadow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
            blend  SrcAlpha  OneMinusSrcAlpha
            ztest always
            zwrite off
            HLSLPROGRAM
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
            float4 _MainTex_ST, _LightSource;


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

            float GetContactShadow(float3 worldPos, float3 target, float2 uv, float stepOffset,float dither)
            {
                //在clip空间操作
                float4 targetClipPos = mul(GetWorldToHClipMatrix(), float4(target, 1));
                float4 startClipPos = mul(GetWorldToHClipMatrix(), float4(worldPos, 1));
                float3 targetClipScreen = NDCNormalized(targetClipPos);
                float3 StartClipScreen = NDCNormalized(startClipPos);
                float3 rayStepScreen = targetClipScreen - StartClipScreen;
               
                //操作uv步进，在视线空间找到遮挡关系
                float3 rayStartUVW = StartClipScreen;
                float3 rayStepUVW = rayStepScreen;

                float step = 1.0f / 8.0f;
                float sampleStep = step + step * stepOffset * dither;
                float hit = 0;
                //return SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, StartClipScreen.xy)*100
                for (int i = 0; i < 8; i++)
                {
                    float3 sampleUVW = rayStartUVW + rayStepUVW * sampleStep;
                    float sampleDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture,
                                                             sampleUVW.xy);
                    float depthDiff = sampleDepth - sampleUVW.z;
                    hit += depthDiff > 0.001 ? 0.1 : 0;
                    sampleStep += step;
                }
                float res = hit > 0 ? 0.3 : 1;
                return 1 - res;
            }
            

            float4 frag(v2f i) : SV_Target
            {
                float dither = Unity_Dither_float4(i.vertex);
                float2 uv = i.vertex / _ScreenParams.xy;
                
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,uv);
                float3 worldPos = GetWorldPositionByDepth(uv,depth);
                float contactShadow = GetContactShadow(worldPos,_LightSource,uv,1,dither);
                return float4(0,0,0,contactShadow);
            }
            ENDHLSL
        }
    }
}