Shader "Custom/InstancedIndirectColorTest" {
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

           

            StructuredBuffer<float4> positionBuffer;

            v2f vert(appdata_t i) {
                v2f o;

                i.vertex.xyz += positionBuffer[i.instanceID].xyz;
                o.vertex = TransformObjectToHClip(i.vertex);
                o.color = positionBuffer[i.instanceID].x;

                return o;
            }

            float4 frag(v2f i) : SV_Target {
                return i.color;
            }

            ENDHLSL
        }
    }
}