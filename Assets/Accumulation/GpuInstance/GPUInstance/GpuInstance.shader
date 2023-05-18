Shader "Unlit/GpuInstance"
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
            
            HLSLPROGRAM
            #pragma multi_compile_local _ _ALPHATEST_ON
            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag
            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 color : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

             UNITY_INSTANCING_BUFFER_START(Props)                    // 定义多实例变量数组
                UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
            UNITY_INSTANCING_BUFFER_END(Props)

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert(appdata i)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_TRANSFER_INSTANCE_ID(i,o);
                o.vertex = TransformObjectToHClip(i.vertex);
                o.uv = TRANSFORM_TEX(i.uv, _MainTex);
                return o;
            }

            float4 frag(v2f i):SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                float4 col = UNITY_ACCESS_INSTANCED_PROP(Props,_Color);
                col *= tex2D(_MainTex,i.uv);
                return col;
            }
            ENDHLSL
        }
    }
}