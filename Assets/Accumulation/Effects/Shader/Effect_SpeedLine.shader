Shader "Effect/SpeedLine"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [HDR]_Color ("Tint", Color) = (1,1,1,1)
        //_Color2 ("Tint2", Color) = (1,1,1,1)
        _NoiseTex("噪声图",2D) = "white"{}
        _NoiseRadialScale("弧度缩放",float) = 1
        _NoiseLengthScale("长度速度",float) = 1
        _NoiseSpeed("噪声速度",float) = 1
        _NoiseRatio("噪音缩放比（中间空洞区域）",range(0,1)) = 0
        _Cutoff ("Cutoff", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
        }

        Pass
        {
            blend SrcAlpha OneMinusSrcAlpha 
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local _ _ALPHATEST_ON

            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"

            sampler2D _MainTex,_NoiseTex;
            float4 _MainTex_ST,_Threshold,_Color,_Color2;
            float _NoiseRadialScale,_NoiseLengthScale,_NoiseSpeed,_NoiseRatio;

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


            float2 PolarUV(float2 uv,float radialScale,float lengthScale)
            {
                float2 Puv = uv;
                Puv -= 0.5f;
                float radius  = length(Puv) * 2 * radialScale;
                float angle = atan2(Puv.x,Puv.y)  * 1.0f/6.28f * lengthScale;
                return float2(radius,angle);
            }

            float InverseLerp(float A, float B,float C)
            {
                return (C - A) / max(0.001f,B - A);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                return o;
            }
            float4 frag(v2f i) : SV_Target
            {
                float2 polarUV = PolarUV(i.uv,_NoiseRadialScale,_NoiseLengthScale);
                float4 albedo = tex2D(_MainTex,i.uv);
                float ratio = (length(i.uv - 0.5) * 2 );
                ratio -= _NoiseRatio;
                ratio = saturate(ratio);
                ratio = smoothstep(0,1,ratio);
                float noise = tex2D(_NoiseTex,float2(polarUV.x + _Time.y * _NoiseSpeed,polarUV.y) ).x;
                //return noise;
                return float4(_Color.xyz * saturate(noise),noise * ratio);
            }

          
            ENDHLSL
        }
    }
}