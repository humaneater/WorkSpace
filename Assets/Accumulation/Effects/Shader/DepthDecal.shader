Shader "Effect/DepthDecal"
{
    Properties
    {
        _MainTex("maintex",2D) = "white"{}
        [HDR] _Color("Color", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline"
        }
        Pass
        {
            zwrite off
            blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "../../ShaderLibrary/CommonFunctions.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 color : TEXCOORD2;
                
            };

            sampler2D _MainTex;
            float4 _MainTex_ST,_Color;
            float _DepthMinus;

            v2f vert(appdata i)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(i.vertex);
                o.uv = TRANSFORM_TEX(i.uv, _MainTex);
                o.color = i.color;
                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                float2 screenPos = i.vertex.xy / _ScreenParams.xy;
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenPos);
                float3 worldPos = GetWorldPositionByDepth(screenPos, depth);
                float3 objectPos = TransformWorldToObject(worldPos);
                clip(float3(0.5, 0.5, 0.5) - abs(objectPos));
                float2 uv = float2(objectPos.x, objectPos.z);
                uv = uv + float2(0.5, 0.5);
                float4 res = tex2D(_MainTex, uv).xyzw ;
                return half4(_Color.xyz * res.xyz, res.w);
            }
            ENDHLSL
        }
    }
}