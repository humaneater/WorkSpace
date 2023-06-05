Shader "PostProcess/Scene_MultiLit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalTex("法线贴图",2D) = "bump"{}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            cull off
            HLSLPROGRAM
            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag

            sampler2D _NormalTex;

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD00;
                half3 normal : TEXCOORD1;
                half3 viewDir : TEXCOORD2;
                half3 ambient : TEXCOORD3;
                half4 tbn[3] : TEXCOORD4;
                
            };
            v2f vert(appdata input)
            {
                v2f o = (v2f) 0;
                float3 worldPos = TransformObjectToWorld(input.vertex);
                float3 wNormal = TransformObjectToWorldNormal(input.normal);
                float3 wTangent = TransformObjectToWorldDir(input.tangent);
                float sign = unity_WorldTransformParams.w * input.tangent.w;
                float3 wBiNormal = cross(wNormal,wTangent) * sign;
                o.tbn[0] = float4(wTangent.xyz,worldPos.x);
                o.tbn[1] = float4(wBiNormal.xyz,worldPos.y);
                o.tbn[2] = float4(wNormal.xyz,worldPos.z);
                o.pos = TransformWorldToHClip(worldPos);
                o.uv = input.texcoord;
                o.viewDir = _WorldSpaceCameraPos - worldPos;
                o.ambient = SampleSH(wNormal);
                return o;
            }

            float4 frag(v2f input) : SV_Target
            {
                float3 worldPos = HGetWorldPosTBN(input);
                float3 normalMap = tex2D(_NormalTex,input.uv);
                normalMap = HunpackNormal(normalMap);
                float3x3 tbn = {input.tbn[0].xyz,input.tbn[1].xyz,input.tbn[2].xyz};
                normalMap = normalize(mul(normalMap,tbn));
                InputData data = InitInputData(worldPos,normalMap,input.viewDir,input.ambient);
                
                return float4(normalMap,1);
            }
            // make fog work
            
            ENDHLSL
        }
         Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
         Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }
    }
}
