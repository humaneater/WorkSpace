Shader "Custom/GrassInstanceIndirect" {
     Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader {
        Tags { "RenderType" = "Opaque" }

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"

            struct appdata_t {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float3 normal : NORMAL;
                uint instanceID : SV_InstanceID;
            };

            struct v2f {
                float4 vertex   : SV_POSITION;
                float4 color    : COLOR;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            }; 

            struct MeshProperties {
                float4x4 mat;
                float4x4 mat_I_M;
                float4 color;
            };

            StructuredBuffer<MeshProperties> _PropertisMatrix;

            v2f vert(appdata_t i) {
                v2f o;

                float4 pos = mul(_PropertisMatrix[i.instanceID].mat, i.vertex);
                o.vertex = TransformWorldToHClip(pos);
                o.color = _PropertisMatrix[i.instanceID].color * i.vertex.y;
                o.worldPos = pos;
                o.normal = mul(i.normal,_PropertisMatrix[i.instanceID].mat_I_M);

                return o;
            }

            float4 frag(v2f i) : SV_Target {
                float NOL = dot(i.normal,_MainLightPosition) * 0.5f + 0.5f;
                return i.color ;
            }

            ENDHLSL
        }
    }
}