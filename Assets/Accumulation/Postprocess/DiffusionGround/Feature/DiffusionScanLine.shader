Shader "PostProcess/DiffusionScanLine"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Alpha("alpha",range(0,1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            blend SrcAlpha one
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

            sampler2D _MainTex,_GridTexture;
            float4 _MainTex_ST, _DiffusionPosition,_Color;
            float _DiffusionValue,_Alpha;


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
                float2 uv = i.uv;

                if (_DiffusionValue < 0)
                {
                    return 0;
                }
                //通过深度还原世界坐标
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
                float3 worldPos = GetWorldPositionByDepth(uv, depth);
                //得到世界和目标点的距离
                float4 albedo = tex2D(_GridTexture, worldPos.xz);
                float3 targetToWorld = worldPos - _DiffusionPosition;
                float lengthOfWorld = length(targetToWorld);
                float alpha = albedo.a;
                float alphaFactor = 20.0f/max(0.001f, _DiffusionValue);
                
                //针对边缘进行旋转
                float4 res = 0;
                [branch]
                if (lengthOfWorld < _DiffusionValue)
                {
                    alpha =saturate(alpha * alphaFactor);
                    res = float4(pow(_Color.xyz * alpha,2),alpha*_Alpha);
                    float innerCircle =  _DiffusionValue - 0.5f;
                    float outerCircle = _DiffusionValue - innerCircle;
                    if (lengthOfWorld > innerCircle)
                    {
                        float sinA;
                        float cosA;
                        float scale = (lengthOfWorld - innerCircle) / max(0.001, (outerCircle));
                        sincos(_DiffusionPosition.w*scale, sinA, cosA);
                        float2x2 rotation = float2x2(cosA, -sinA, sinA, cosA);
                        float2 worldOffset = mul(rotation, targetToWorld.xz) + _DiffusionPosition.xz;
                        float2 worldUV = worldPos.xz + worldOffset;
                        float lengthWorldUV = length(worldUV);
                        albedo = tex2D(_GridTexture, worldUV);
                        float edgeAlpha = saturate(lengthWorldUV / max(0.001, _DiffusionValue * 30));
                        res = float4(_Color.xyz , albedo.a);
                    }
                   
                }
                return res;

            }


            
            ENDHLSL
        }
    }
}
