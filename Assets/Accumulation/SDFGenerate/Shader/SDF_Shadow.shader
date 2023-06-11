Shader "Effect/SDF_Shadow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {

            blend SrcAlpha OneMinusSrcAlpha
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
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            TEXTURE2D_ARRAY(_SDFTexture);
            SAMPLER(sampler_SDFTexture);
            //_MapOffset:x:x offset, y: z offset, z: map search unit;
            //_SDFTexture_TexelSize.z : 地图长度 除以单位等于缩放比
            float4 _LightSourcePosition,_MapOffset,_SDFTexture_TexelSize;


            v2f vert(appdata i)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(i.vertex);
                o.worldPos = TransformObjectToWorld(i.vertex);
                o.uv = i.uv;
                return o;
            }


            //sdf阴影
            //原理解释：需要的两个UV都是对于世界空间转换过来的UV，也就是根据世界空间xz根据sdf矫正offset之后的uv，height则决定用array图
            //的那一张，当然也可以用3d图做三线性插值，相对费一点，看需不需要吧
            float GetSDFShadow(float2 StartUV, float2 targetUV, float dither, float size, int height)
            {
                float2 direction = targetUV - StartUV;
                float lengthOfStep = length(direction);
                direction = normalize(direction);
                int count = 12;

                float sdf = 0;
                float totalLength = 0;
                //UNITY_UNROLL有些芯片不能用
                for (int i = 0; i < count; i++)
                {
                    float2 uv = StartUV + direction * totalLength;
                    float dis = SAMPLE_TEXTURE2D_ARRAY_LOD(_SDFTexture, sampler_SDFTexture, uv, height, 0) * 255.0f;
                    if (dis <= 0.0001f)
                    {
                        return 0.0f;
                    }
                    totalLength += dis / (size * (1.0f + dither*0.1));
                    if (totalLength > lengthOfStep)
                    {
                        return 1.0f;
                    }
                    sdf += dis;
                }
                return 0.0;
            }

            float4 frag(v2f input):SV_Target
            {
                float dither = Unity_Dither_float4(input.vertex);
                float unit = _SDFTexture_TexelSize.z * _MapOffset.z;
                unit = max(0.001f,unit);
                float2 sourceUV = float2(input.worldPos.x - _MapOffset.x,input.worldPos.z - _MapOffset.y)/unit;
                float2 targetUV = float2(_LightSourcePosition.x - _MapOffset.x,_LightSourcePosition.z - _MapOffset.y)/unit;
                float height = _LightSourcePosition.y;
                float atten = GetSDFShadow(sourceUV,targetUV,dither,unit,height);
                return atten;
            }
            ENDHLSL
        }
    }
}