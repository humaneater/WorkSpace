Shader "Scene/MultiLit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalTex("法线贴图",2D) = "bump"{}
        _RoughnessTex("粗糙度贴图",2D) = "white"{}
        _Roughness("粗糙度",range(0,1)) = 0
        _Metallic("金属都",range(0,1)) = 0
        _MetallicTex("金属都贴图",2D) = "white"{}
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
            cull off
            HLSLPROGRAM
            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _OCCLUSIONMAP
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP

            // -------------------------------------
            // Universal Pipeline keywords
            // #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            // #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ DOTS_INSTANCING_ON
            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"

            #pragma vertex vert
            #pragma fragment frag

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


            sampler2D _NormalTex, _MainTex, _MetallicTex, _RoughnessTex;
            float _Roughness, _Metallic;
            float4 _MapOffset, _LightIndexTex_Size;
            Texture3D<float4> _LightIndexTex;
            SamplerState sampler_clamp_point_LightIndexTex;
            StructuredBuffer<LightsInfo> _LightsInfo;

            v2f vert(appdata input)
            {
                v2f o = (v2f)0;
                float3 worldPos = TransformObjectToWorld(input.vertex);
                float3 wNormal = TransformObjectToWorldNormal(input.normal);
                float3 wTangent = TransformObjectToWorldDir(input.tangent);
                float sign = unity_WorldTransformParams.w * input.tangent.w;
                float3 wBiNormal = cross(wNormal, wTangent) * sign;
                o.tbn[0] = float4(wTangent.xyz, worldPos.x);
                o.tbn[1] = float4(wBiNormal.xyz, worldPos.y);
                o.tbn[2] = float4(wNormal.xyz, worldPos.z);
                o.pos = TransformWorldToHClip(worldPos);
                o.uv = input.texcoord;
                o.viewDir = _WorldSpaceCameraPos - worldPos;
                o.ambient = SampleSH(wNormal);
                return o;
            }

            float4 frag(v2f input) : SV_Target
            {
                float3 albedo = tex2D(_MainTex, input.uv);
                float metallic = tex2D(_MetallicTex, input.uv);
                float roughness = tex2D(_RoughnessTex, input.uv);
                float3 worldPos = HGetWorldPosTBN(input);
                float3 normalDir = tex2D(_NormalTex, input.uv);
                float3 normalMap = HunpackNormal(normalDir);
                float3x3 tbn = {input.tbn[0].xyz, input.tbn[1].xyz, input.tbn[2].xyz};
                normalMap = normalize(mul(normalMap, tbn));
                InputData data = InitInputData(worldPos, normalMap, input.viewDir, input.ambient);
                SurfaceData surface = InitSurfaceData(albedo, _Metallic, _Roughness, normalDir);
                float3 res = UniversalFragmentPBR(data, surface);

                //自定义的额外光源光照，先读图
                float3 uvw = worldPos - _MapOffset.xyz;
                uvw = float3(floor(uvw.x) / _LightIndexTex_Size.x, floor(uvw.z) / _LightIndexTex_Size.y,
                             floor(uvw.y) / _LightIndexTex_Size.z);
                float4 index = _LightIndexTex.SampleLevel(sampler_clamp_point_LightIndexTex, uvw, 0);
                float3 addLightRes = 0;
                //可能要分开处理光源，不能让无关光源干扰结果
                if (index.x != -1)
                {
                    Light light01 = InitCustomLight(_LightsInfo[(uint)index.x].color,
                                                    _LightsInfo[(uint)index.x].position,
                                                    _LightsInfo[(uint)index.x].direction, data.positionWS,
                                                    _LightsInfo[(uint)index.x].attenuation);
                    addLightRes += GetCustomAdditionalLighting(light01, data);
                }
                if (index.y != -1)
                {
                    Light light02 = InitCustomLight(_LightsInfo[(uint)index.y].color,
                                                    _LightsInfo[(uint)index.y].position,
                                                    _LightsInfo[(uint)index.y].direction, data.positionWS,
                                                    _LightsInfo[(uint)index.y].attenuation);
                    addLightRes += GetCustomAdditionalLighting(light02, data);
                }
                if (index.z != -1)
                {
                    Light light03 = InitCustomLight(_LightsInfo[(uint)index.z].color,
                                                    _LightsInfo[(uint)index.z].position,
                                                    _LightsInfo[(uint)index.z].direction, data.positionWS,
                                                    _LightsInfo[(uint)index.z].attenuation);
                    addLightRes += GetCustomAdditionalLighting(light03, data);
                }
                if (index.w != -1)
                {
                    Light light04 = InitCustomLight(_LightsInfo[(uint)index.w].color,
                                                    _LightsInfo[(uint)index.w].position,
                                                    _LightsInfo[(uint)index.w].direction, data.positionWS,
                                                    _LightsInfo[(uint)index.w].attenuation);
                    addLightRes += GetCustomAdditionalLighting(light04, data);
                }


                return float4(res + addLightRes, 1);
            }

            // make fog work
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

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
            Tags
            {
                "LightMode" = "DepthOnly"
            }

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
            Tags
            {
                "LightMode" = "DepthNormals"
            }

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