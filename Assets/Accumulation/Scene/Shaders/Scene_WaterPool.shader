Shader "HRP/Scenes/WaterPool"
{
    Properties
    {
        [Header(the first water texture suit)]
        _Color("color",Color) = (1,1,1,1)
        _Color2("水低颜色",Color) = (1,1,1,1)
        [HDR]_ColorSpecular("高光颜色",Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _BumpMap("法线贴图",2D) = "default"{}
        _DetailNormal("高光细节法线贴图",2D) = "default"{}
        _DetailNormalFarcot("法线缩放",range(0,10)) = 1
        _Glossing("高光取值范围",range(0,15)) = 1
        _GlossingStrength("高光强度",range(1,20)) = 1
        _WaterFactorX("法线扰动X轴方向",Range(-0.999,0.99)) = 0.1
        _WaterFactorY("法线扰动Y轴方向",Range(-0.999,0.99)) = 0.1
        _WaterFactorZ("法线扰动Z轴方向",Range(0.001,0.1)) = 1
        _WaterFactorW("法线扰动整体幅度",Range(0.001,1)) = 1
        _FoamTex("泡沫贴图",2D) = "white"{}
        _FoamDistance("泡沫距离",range(0,1)) = 0.04
        [HDR]_FoamColor("泡沫颜色",Color) = (1,1,1,1)
        [HDR]_DepthFoamColor("深度泡沫颜色",Color) = (1,1,1,1)
        _CutOff("泡沫消除值",range(0,1)) = 1
        _FoamGlossing("泡沫取值范围",range(0,2)) = 1
        _FoamSpeed("泡沫流动速度",range(0,2)) = 1
    }
    SubShader
    {
        Tags
        {
            "Queue" = "Transparent" "RenderType"="Transparent"
        }
        Pass
        {

            Blend SrcAlpha OneMinusSrcAlpha
            // Cull front
            HLSLPROGRAM
            #pragma multi_compile   _SCENE_GRAPHIC_LOW  _SCENE_GRAPHIC_MEDIUM _SCENE_GRAPHIC_SUPREME _SCENE_GRAPHIC_HIGH __
            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"
            #pragma vertex WaterVert
            #pragma fragment WaterFrag

            float _DepthScale, _CutOff, _Glossing, _GlossingStrength, _FlowSpeed, _WaterFactorX, _WaterFactorY,
                  _WaterFactorZ, _WaterFactorW, _VisionArea, _NormalNoise, _FoamGlossing, _DetailNormalFarcot,
                  _FoamSpeed;
            sampler2D _BumpMap, _FoamTex, _CameraOpaqueTexture, _DetailNormal;
            samplerCUBE Skybox;
            sampler2D _MainTex;
            float4 _MainTex_ST, _Color, _Color2, _FoamColor, _DepthFoamColor, _FoamTex_ST, _BumpMap_ST,
                   _DetailNormal_ST, _ColorSpecular;
            float _FoamDistance;
            float _EdgeSoft;

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float4 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
            };

            struct v2f_Water
            {
                float4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
                half2 uv2 : TEXCOORD1;
                half3 normal : TEXCOORD2;
                half3 viewDir : TEXCOORD3;
                half3 ambient : TEXCOORD4;
                float4 tToW[3] : TEXCOORD5;
                float4 color : TEXCOORD8;
                float4 uvadd : TEXCOORD9;
            };

            v2f_Water WaterVert(appdata v)
            {
                v2f_Water o = (v2f_Water)0;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                float3 worldPos = TransformObjectToWorld(v.vertex);
                float3 normal = TransformObjectToWorldNormal(v.normal);
                float3 wTangent = TransformObjectToWorldDir(v.tangent.xyz);
                float sign = unity_WorldTransformParams.w * v.tangent.w;
                float3 wBiNormal = cross(normal, wTangent) * sign;
                o.tToW[0] = float4(wTangent.x, wBiNormal.x, normal.x, worldPos.x);
                o.tToW[1] = float4(wTangent.y, wBiNormal.y, normal.y, worldPos.y);
                o.tToW[2] = float4(wTangent.z, wBiNormal.z, normal.z, worldPos.z);
                o.viewDir = _WorldSpaceCameraPos - worldPos;
                o.uv = v.texcoord * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv2 = v.texcoord * _BumpMap_ST.xy + _BumpMap_ST.zw;
                return o;
            }


            //实时光测试
            half4 WaterFrag(v2f_Water i) : SV_Target
            {
                float sinT = sin(_Time.x * 5.0f);
                float4 albedo = _Color; // tex2D(_MainTex, i.uv);
                float3 worldPos = float3(i.tToW[0].w, i.tToW[1].w, i.tToW[2].w);
                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction.xyz;
                float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);
                float4 offsetColor = tex2D(_BumpMap, i.uv + float2(_Time.x * _WaterFactorX, 0)) + tex2D(
                    _BumpMap, i.uv + float2(0, _Time.y * _WaterFactorY));
                float2 offset = offsetColor.xy * _WaterFactorZ;
                //混合两个法线，blendnormal
                float3 tangentNormal1 = HunpackNormal(tex2D(_BumpMap, i.uv2 + offset));
                float3 tangentNormal2 = HunpackNormal(tex2D(_BumpMap, i.uv2 - offset));
                float3 normalMap = normalize(float3(tangentNormal1.xy + tangentNormal2.xy,
                                                    tangentNormal1.z * tangentNormal2.z));
                normalMap.xy *= _WaterFactorW;
                normalMap.z = sqrt(1 - saturate(dot(normalMap.xy, normalMap.xy)));
                normalMap.xyz = normalize(float3(dot(i.tToW[0].xyz, normalMap), dot(i.tToW[1].xyz, normalMap),
                                                 dot(i.tToW[2].xyz, normalMap)));
                //normalMap = abs(normalMap);
                float ndotL = dot(normalMap, lightDir) * 0.5 + 0.5;
                float3 diffuse;
                diffuse = ndotL * albedo * mainLight.color;
                float3 specular;
                //detail normal作为磷光效果
                float3 detailNormal = tex2D(_DetailNormal,
                                            (i.uv.xy - offset) * _DetailNormal_ST.xy + _DetailNormal_ST.zw);
                detailNormal = detailNormal * 0.5f - 0.5f;
                detailNormal.z = sqrt(1 - saturate(dot(detailNormal.xy, detailNormal.xy))) * _DetailNormalFarcot;
                detailNormal = normalize(detailNormal);
                detailNormal = normalize(float3(normalMap.xy + detailNormal.xy, normalMap.z * detailNormal.z));
                float3 halfDir = normalize(lightDir + viewDir);
                float ndotH = dot(lightDir, detailNormal) * 0.5 + 0.5; //BlinnPhong
                specular = _ColorSpecular * mainLight.color * pow(ndotH, exp2(_Glossing)) * _GlossingStrength;
                //读深度图&颜色贴图
                float2 uv = i.pos.xy / _ScreenParams.xy;
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture,
                                                   uv+ offset.xy * 0.01f);
                float depthtemp = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
                depth = LinearEyeDepth(depth, _ZBufferParams);
                depthtemp = LinearEyeDepth(depthtemp, _ZBufferParams);
                float depthNow = LinearEyeDepth(i.pos.z, _ZBufferParams);


                float4 colorTex = tex2D(_CameraOpaqueTexture, saturate(uv + offset.xy * 0.01f));
                //深度变换着色
                //用深度差值，需要一个最大深度，再往下都是一个颜色
                float depthFactor = clamp(abs(depth - depthNow), 0, 3) / 3.0f;
                //需要取消ghost效果
                if (depth < depthNow)
                {
                    depthFactor = clamp(abs(depthtemp - depthNow), 0, 3) / 3.0f;
                }
                float4 colorByDepthFactor = lerp(_Color * colorTex, _Color2, depthFactor);

                //泡沫
                float cutOff = _CutOff;
                float2 foamUV = (i.uv * _FoamTex_ST.xy + _FoamTex_ST.zw);
                //泡沫贴图，直接取出来就可以作为顶上的泡沫项，自带0.9~1.1的缩放
                float foam = tex2D(_FoamTex, foamUV + float2(0, offset.y + _Time.x * _FoamSpeed));
                int isfoam = 1 - step(foam, cutOff);
                float4 foamColor = _FoamColor * isfoam;
                [branch]
                if (depth < depthNow + _FoamDistance)
                {
                    foamColor = _DepthFoamColor * step(foam, cutOff + (_FoamDistance - abs(depth - depthNow)));
                    //step(depth - depthNow,0.2)? _FoamColor : foamColor;
                }
                ndotH = max(0.001f, dot(halfDir, normalMap)); //BlinnPhong
                float3 res = max(0.001f, colorByDepthFactor) * diffuse + specular + foamColor * pow(
                    1 - ndotH, _FoamGlossing);
                //反射
                return float4(max(0.01f, res.xyz), _Color2.a);
            }
            ENDHLSL
        }



    }
}