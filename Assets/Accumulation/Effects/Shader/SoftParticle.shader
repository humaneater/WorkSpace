Shader "Effect/SoftParticle"
{
    Properties
    {
        _MainTex("粒子贴图",2D) = "white"{}
        [HDR] _Color("Color", Color) = (1, 1, 1, 1)
        _DepthMinus("深度差值",range(0,1)) = 1
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
            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"

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
            float4 _MainTex_ST, _Color;
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
                float4 albedo = tex2D(_MainTex, i.uv);
                float2 depthUV = i.vertex.xy / _ScreenParams.xy;
                float viewDirZ = LinearEyeDepth(i.vertex.z, _ZBufferParams);
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, depthUV);
                depth = LinearEyeDepth(depth, _ZBufferParams);
                float alpha = saturate(abs(depth - viewDirZ) * _DepthMinus);
                return float4(albedo.xyz * i.color * _Color, albedo.a * alpha);
            }
            ENDHLSL
        }
    }
}