Shader "Custom/InstancedIndirectColor" {
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
                uint instanceID : SV_InstanceID;
            };

            struct v2f {
                float4 vertex   : SV_POSITION;
                float4 color    : COLOR;
            }; 

            struct MeshProperties {
                float4x4 mat;
                float4 color;
            };

            StructuredBuffer<MeshProperties> _Properties;

            v2f vert(appdata_t i) {
                v2f o;

                float4 pos = mul(_Properties[i.instanceID].mat, i.vertex);
                o.vertex = TransformObjectToHClip(pos);
                o.color = _Properties[i.instanceID].color;

                return o;
            }

            float4 frag(v2f i) : SV_Target {
                return i.color;
            }

            ENDHLSL
        }
    }
}