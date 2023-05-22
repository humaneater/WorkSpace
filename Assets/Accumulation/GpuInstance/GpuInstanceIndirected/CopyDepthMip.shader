Shader "Util/CopyDepthMip"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

       //上屏
        pass
        {
            blend one one
            ztest always
            zwrite off
            HLSLPROGRAM
            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"
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

            sampler2D _MainTex;
            float4 _MainTex_ST;

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
                float3 res = tex2D(_MainTex, i.uv);
                return float4(res, 1);
            }
            ENDHLSL

        }
    }
}
