Shader "Character/PlayerNPR"
{
    Properties
    {
        [Header(Main Texture)]
        _SkinColor("皮肤颜色",Color) = (1,1,1,1)
        _Color("总体颜色",Color) = (1,1,1,1)
        _HUEColor("HueShift Color",color) = (1,1,1,1)
        [NoScaleOffset]_BaseMap ("albedo 贴图", 2D) = "white" {}
        [NoScaleOffset]_NormalMap("法线，粗糙度，ID ", 2D) = "bump"{}
        [NoScaleOffset]_EmissiveTex("自发光贴图",2D) = "black"{}
        _DesolveTex("消融贴图",2D) = "white"{}
        [HDR]_DesolveColor("消融高亮颜色",color) = (1,1,1,1)
        _DesolveValue("消融值",range(0,1)) = 1
        [Header(Rendering Factor)]
        _Roughness("粗糙度", range(-0.96,0.96)) = 0.5
        _Gloss("glossing系数（只对非金属生效）",range(0.01,10)) = 2
        _GlossSkin("皮肤Gloss削弱比",range(0,1)) = 1
        _GlossFabric("布料Gloss削弱比",range(0,1)) = 1
        _GlossFur("皮革Gloss削弱比",range(0,1)) = 1
        _Metallic("金属度(只对金属生效)", range(0.04,0.96)) = 0.5
        [Header(Ramp Texture)]
        [NoScaleOffset]_RampTex("ramp图",2D) = "white"{}
        [Header(Edge Rim Emisive)]
        [HDR]_RimColor("边缘自发光颜色",color) = (1,1,1,1)
        _RimRange("边缘自发光范围",range(0.2,1)) = 0.9
        _RimIntensity("自发光强度",range(1,10)) = 1
        [Header(EX factor)]
        _NoticeColor("notice color",color) = (1,1,0,0.5)
        _HighLight("notice color2",color) = (1,0,0,0.5)
        [Header(Shadow Range)]
        [Header(OutLine)]
        [HDR]_OutLineColor("outLine color",Color) = (1,1,1,1)
        _OutLineRange("outLine range", range(0, 1)) = 0.1
        _StencilRef ("Stencil Reference Value", float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTestRef("z test ref",Float) = 4
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("stencil ref",Float) = 5
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        Pass
        {
            cull back
            zwrite on
            stencil
            {
                Ref 8
                comp always
                pass replace
                fail keep
                ZFail keep
            }
            HLSLPROGRAM
            
            #pragma multi_compile _ _HighLight
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_local _ _DesolveEffect

            #include "../../ShaderLibrary/CommonFunctions.hlsl"
            #pragma vertex vert
            #pragma fragment CharacterFrag
            CBUFFER_START(UnityPerMaterial)
            sampler2D _BaseMap, _SSSTex, _SSSTex2, _SSSLutTex, _NormalMap, _EmissiveTex, _RampTex, _DesolveTex;
            float4 _BaseMap_ST, _SkinColor, _RimColor, _CameraLightColor, _Color, _HUEColor, _DesolveColor;
            float _Metalness, _RampPowerFactor, _Roughness, _Metallic, _Gloss, _CameraLightIntensity, _RimRange,
                  _RimIntensity, _HUEFactor, _ShadowEdge, _GlossSkin, _GlossFabric, _GlossFur, _DesolveValue;
            float4x4 _LightColor, _LightPosition;
            float4 _ShadowLightPosition[4];
            CBUFFER_END

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
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 color : TEXCOORD2;
                float3 normal : TEXCOORD3;
                float4 tToW[3] : TEXCOORD4;
                float3 viewDir : TEXCOORD7;
                float3 ambient : TEXCOORD8;
            };

            float3 GetAdditiveLight(Light light, float3 albedo, float3 normal)
            {
                float nDotL = dot(normal, light.direction) * 0.5 + 0.5;
                return nDotL * light.color * light.distanceAttenuation;
            }

            v2f vert(appdata v)
            {
                v2f o = (v2f)0;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                float3 worldPos = mul(GetObjectToWorldMatrix(), v.vertex);
                o.normal = TransformObjectToWorldNormal(v.normal);
                float3 wTangent = TransformObjectToWorldDir(v.tangent.xyz);
                float sign = unity_WorldTransformParams.w * v.tangent.w;
                float3 wBiNormal = cross(o.normal, wTangent) * sign;
                o.tToW[0] = float4(wTangent.x, wBiNormal.x, o.normal.x, worldPos.x);
                o.tToW[1] = float4(wTangent.y, wBiNormal.y, o.normal.y, worldPos.y);
                o.tToW[2] = float4(wTangent.z, wBiNormal.z, o.normal.z, worldPos.z);
                o.viewDir = _WorldSpaceCameraPos - worldPos;
                o.uv = v.texcoord * _BaseMap_ST.xy + _BaseMap_ST.zw;
                o.ambient = SampleSHVertex(o.normal);
                o.color = v.color;
                return o;
            }

            float3 GetLowAddLightResult()
            {
                return 0;
            }

            float3 GetMediumAddLightResult(float3 albedo, InputData data, Light mainlight,
                                           int isOutShadow, int isSkin)
            {
                //额外光源光照,UGC方案以及普通方案
                //PBSSurfaceParam surface = ExtractPBRSurfaceParam(roughnessMask, specularFactor, 1, 1, albedo);
                float3 AdditionalColor = 0;
                [unroll(_AdditionalLightsCount.y)]
                for (int j = 0; j <= _AdditionalLightsCount.y; j++)
                {
                    Light light = GetAdditionalLight(j, data.positionWS);
                    AdditionalColor += GetAdditiveLight(light, albedo, data.normalWS);
                }
                //ibl项
                float3 res = (AdditionalColor) * albedo;

                return res;
            }

            float3 GetHighAddLightResult(float roughness, float3 albedo, InputData data, Light mainlight,
                                         int isOutShadow, int isSkin)
            {
                //边缘光项，通过view方向和法线的菲尼尔
                float3 rim = 0;
                float3 rimLightDir = reflect(-mainlight.direction, float3(0, 1, 0));
                float rimrange = max(0, dot(rimLightDir, data.normalWS));
                float nDotV = pow(1 - saturate(dot(data.normalWS, data.viewDirectionWS)), 5);
                rimrange = rimrange > _RimRange ? nDotV : 0;
                float fresnel = saturate(pow(rimrange, _RimIntensity));
                float3 colors = 1 - (1 - albedo) * (1 - _RimColor);
                rim = fresnel * colors * nDotV;
                rim = saturate(max(0, isOutShadow || isSkin ? 0 : rim));

                float3 AdditionalColor = 0;
                //额外光源光照,UGC方案以及普通方案
                //PBSSurfaceParam surface = ExtractPBRSurfaceParam(roughnessMask, specularFactor, 1, 1, albedo);
                /*for (int j = 0; j < 4; j++)
                {
                    Light addLight = (Light)1;
                    float3 lightLength = worldPos - _ShadowLightPosition[j].xyz;
                    addLight.direction = normalize(lightLength);
                    addLight.color = ambient;
                    addLight.distanceAttenuation = saturate(1 - length(lightLength) / 8) * 0.2;
                    //Light light = GetPerObjectLight(worldPos, _LightColor[j], _LightPosition[j]);
                    AdditionalColor += GetAdditiveLight(addLight, albedo, normalDir);
                }*/
                [unroll(_AdditionalLightsCount.y)]
                for (int j = _AdditionalLightsCount.y - 1; j >= 0; j--)
                {
                    Light light = GetAdditionalPerObjectLight(j, data.positionWS);
                    AdditionalColor += GetAdditiveLight(light, albedo, data.normalWS);
                }
                //ibl项
                float3 iblTerm = SampleEnviroment(data.viewDirectionWS, data.normalWS, roughness, data.positionWS);
                float3 res = (rim + iblTerm + AdditionalColor) * albedo;
                return res;
            }


            float3 HueShift(float4 c, float4 Hue)
            {
                c.xyz = RgbToHsv(c);
                c.x += Hue.x;
                c.x = frac(c.x);
                return HsvToRgb(c);
            }

            half4 CharacterFrag(v2f i) : SV_Target
            {
                //采集贴图数据
                float3 worldPos = HGetWorldPos(i);
                float4 albedo = tex2D(_BaseMap, i.uv);
                float3 emission = tex2D(_EmissiveTex, i.uv);
                float3 SSS = tex2D(_SSSTex, i.uv);

                //HUEshift
                _HUEColor.xyz = RgbToHsv(_HUEColor);
                albedo.xyz = albedo.a > 0.1 ? HueShift(albedo.xyzw, _HUEColor) : albedo.xyz;


                float4 normalMap = tex2D(_NormalMap, i.uv);
                float materialID = normalMap.w + 0.1;
                float roughnessMask = saturate(normalMap.z + _Roughness);
                normalMap.xy = normalMap.xy * 2.0 - 1.0;
                normalMap.z = sqrt(1.0 - saturate(dot(normalMap.xy, normalMap.xy)));
                float3 normalDir = normalize(half3(dot(i.tToW[0].xyz, normalMap), dot(i.tToW[1].xyz, normalMap),
                                                   dot(i.tToW[2].xyz, normalMap)));
                //ambient项
                float3 ambient = i.ambient;
                float ambientFactor = dot(ambient, 0.3);
                ambient = ambientFactor > 1 ? ambient : ambientFactor * ambient;
                ambient = ambient * 0.2f;

                //材质区分
                int isSkin = materialID > 0.8f;
                int isHair = materialID < 0.2f && materialID >= 0.0f;
                int isFabric = materialID > 0.2f && materialID < 0.4f;
                int isFur = materialID > 0.4f && materialID < 0.6f;
                int isMatel = materialID > 0.6f && materialID < 0.8f;

                //初始化灯光信息
                Light mainLight = GetMainLight();
                //float4 shadowPos = worldPos;//mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
                float4 bias = TransformWorldToShadowCoord(worldPos.xyz);
                bias.z += (1 - dot(mainLight.direction, normalDir)) * 0.005;
                bias.z += 0.005;
                mainLight.shadowAttenuation =   MainLightRealtimeShadow(bias);
                int isShadow = mainLight.shadowAttenuation < 1;
                InputData data = InitInputData(worldPos, normalDir, i.viewDir, i.ambient);
                float3 wNormal = float3(i.tToW[0].z, i.tToW[1].z, i.tToW[2].z);
                //diffuse项 NPR 第一个灯，主光
                float3 lightDir = mainLight.direction;
                float ndotL = max(0.01, dot(normalDir, lightDir));
                
                //覆盖阴影 Ramp
                float3 ramp = tex2D(_RampTex, float2(ndotL * mainLight.shadowAttenuation, materialID)).rgb;
                float3 diffuse = albedo * ramp;
                //specular项
                float3 halfDir = normalize(data.viewDirectionWS + mainLight.direction);
                float nDotH = dot(normalDir, halfDir) * 0.5 + 0.5;

                float3 specularFactor = saturate(BlinnPhoneSpecular(albedo, nDotH, _Gloss));
                float3 specular = specularFactor;

                float3 sssTerm = 0;
                [branch]
                if (isSkin)
                {
                    specular *= _GlossSkin * _SkinColor;
                    //   ndotL = ndotL * tex2D(_SSSTex2, i.uvadd).x;
                    //   sssTerm = tex2D(_SSSLutTex, float2(ndotL, SSS.y));
                }
                [branch]
                if (isFabric)
                {
                    specular *= _GlossFabric;
                }
                [branch]
                if (isFur)
                {
                    specular *= _GlossFur;
                }
                [branch]
                if (isHair)
                {
                    specular *= 0.1;
                }
                [branch]
                if (isMatel)
                {
                    specularFactor = albedo;
                    specular = 1;
                }


                //iblterm + sssTerm + ambientTerm + addlight
                float3 addTerm = 0;
                
                addTerm = GetHighAddLightResult(roughnessMask,albedo, data, mainLight, isShadow,isSkin);
                
                float3 res = (specular + diffuse) * mainLight.color + emission*0.1f + addTerm;
               

                //消融效果，需要消融的边缘有一个高亮的bloom效果，最好是呼吸的？
                #if _DesolveEffect
                res = DesolveColor(_DesolveTex,i.uv,_DesolveValue,_DesolveColor,float4(res.xyz,1));
                #endif

                return float4(res * _Color, 1);
            }
            ENDHLSL
        }
        Pass
        {
            Name "Outline"
            Tags
            {
                "LightMode" = "Outline"
            }
            Cull front
            Ztest On


            /*Stencil
            {
                Ref 8
                Comp NotEqual
                Pass Keep
                ZFail Keep
            }*/

            HLSLPROGRAM
            #pragma multi_compile_local _ _DesolveEffect
            #pragma vertex vert
            #pragma fragment frag
            #include "../../ShaderLibrary/CommonFunctions.hlsl"

            sampler2D _DesolveTex;
            float4 _OutLineColor, _DesolveColor;
            float _OutLineRange, _DesolveValue;

            struct a2vv
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                //float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;
            };

            struct v2ff
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2ff vert(a2vv v)
            {
                v2ff o;

                float z = sqrt(1 - saturate(dot(v.uv2.xy, v.uv2.xy)));
                float3 normalOutline = normalize(float3(v.uv2.xy, z));
                float3 wNormalDir = TransformObjectToWorldNormal(v.normal);
                float3 wTangentDir = TransformObjectToWorldDir(v.tangent.xyz);
                float sign = unity_WorldTransformParams.w * v.tangent.w;
                float3 biTangent = cross(wNormalDir, wTangentDir) * sign;
                float3x3 tbn = {wTangentDir, biTangent, wNormalDir};
                normalOutline = mul(normalOutline, tbn) * 0.1f * _OutLineRange;
                float3 worldPos = TransformObjectToWorld(v.vertex) + normalOutline;
                o.pos = TransformWorldToHClip(worldPos);
                o.uv = v.uv2;
                return o;
            }

            float4 frag(v2ff i) : SV_Target
            {
                float4 res = _OutLineColor;
                #if _DesolveEffect
                res = DesolveColor(_DesolveTex,i.uv,_DesolveValue,_DesolveColor,res);
                #endif
                return res;
            }
            ENDHLSL
        }
        //遮挡
        Pass
        {
            Tags
            {
                "LightMode" = "HRPBlock"
            }
            blend SrcAlpha OneMinusSrcAlpha
            //SrcAlpha OneMinusSrcAlpha
            cull off
            zwrite off
            ztest [_ZTestRef]
            stencil
            {
                Ref [_StencilRef]
                comp [_StencilComp]
                pass keep
                fail keep
                ZFail keep
            }
            HLSLPROGRAM
            #include "../../ShaderLibrary/CommonFunctions.hlsl"
            #pragma multi_compile_local _ _DesolveEffect
            #pragma vertex vert
            #pragma fragment RedNoticeFrag

            CBUFFER_START(UnityPerMaterial)
            float4 _HighLight;
            int _StencilRef;
            float4 _NoticeColor, _DesolveColor;
            float _OutLineRange, _DesolveValue;
            sampler2D _DesolveTex;
            CBUFFER_END

            struct appdataa
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
                float4 texcoord2 : TEXCOORD1;
            };

            struct v2ff
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 worldPos : TEXCOORD2;
            };

            v2ff vert(appdataa v)
            {
                v2ff o = (v2ff)0;

                [branch]
                if (_StencilRef == 8)
                {
                    float4 pos = TransformObjectToHClip(v.vertex);
                    float3 viewNormal = mul(UNITY_MATRIX_V, TransformObjectToWorldNormal(v.normal.xyz));
                    float3 ndcNormal = normalize(TransformWViewToHClip(viewNormal.xyz));
                    float timeScale = sin(_Time.z) * 0.5 + 1.5;
                    pos.xy += 0.1f * 0.1f * ndcNormal.xy * timeScale;
                    o.pos = pos;
                }
                else
                {
                    o.pos = TransformObjectToHClip(v.vertex.xyz);
                }

                o.uv = v.texcoord;
                return o;
            }

            float4 RedNoticeFrag(v2ff i) : SV_Target
            {
                if (_StencilRef == 8)
                {
                    return _HighLight * abs(sin(_Time.y));
                }
                if (i.pos.y % 10 < 5)
                {
                    discard;
                }
                float4 res = _NoticeColor;
                #if _DesolveEffect
                res = DesolveColor(_DesolveTex,i.uv,_DesolveValue,_DesolveColor,float4(res.xyz,1));
                #endif
                return _NoticeColor;
            }
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
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

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
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

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
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

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

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }

    }
}