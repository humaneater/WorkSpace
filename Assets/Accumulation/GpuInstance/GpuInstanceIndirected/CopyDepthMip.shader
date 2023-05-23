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
            name "CopyDepth"
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
        //copy mip
        pass
        {
            name "CopyDepthMip"
            blend one zero
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
            float4 _MainTex_ST,_MainTex_TelexSize;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                
                return o;
            }

            float SampleDepthMip(float2 uv)
            {
                float3 offset = float3(_MainTex_TelexSize.xy,0.0f);
                float4 depth = 1;
                depth.x = tex2D(_MainTex,uv);
                depth.y = tex2D(_MainTex,uv + offset.zy);
                depth.z = tex2D(_MainTex,uv + offset.xz);
                depth.w = tex2D(_MainTex,uv + offset.xy);
                #ifdef UNITY_REVERSED_Z
                return min(min(depth.x,depth.y),min(depth.z,depth.w));
                #else
                return max(max(depth.x,depth.y),max(depth.z,depth.w));
                #endif
                
                
                
            }

            float4 frag(v2f i):SV_Target
            {
                float res = SampleDepthMip(i.uv);
                return res;
            }
            ENDHLSL

        }
    }
}
