Shader "PostPorcess/LightShaft"
{
    Properties
    {
        _Alpha("alpha",range(0,1)) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        HLSLINCLUDE
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

        float GetLuminance(float3 color)
        {
            // color = pow(color,2.2f);
            return max(dot(color, half3(.3f, .59f, .11f)), 6.10352e-5);;
        }

        TEXTURE2D_X(_MainTex) ;
        SAMPLER(sampler_MainTex);
        float4 _MainTex_ST, _MainTex_TexelSize;
        float _Radius;

        v2f vert(appdata v)
        {
            v2f o;
            o.vertex = float4(v.vertex.xy, 0, 1);
            #if UNITY_UV_STARTS_AT_TOP
            o.vertex.y = -o.vertex.y;
            #endif
            o.uv = v.uv;
            return o;
        }

        float4 fragBlit(v2f i):SV_Target
        {
            float3 col = SAMPLE_TEXTURE2D_LOD(_MainTex,sampler_MainTex, i.uv,0);
            return float4(col, 1);
        }

        float4 fragLuminance(v2f i):SV_Target
        {
            Light mainLight = GetMainLight();
            float3 farplaneSunPos = _WorldSpaceCameraPos + (-mainLight.direction * _ProjectionParams.z);
            float4 uvw = TransformObjectToHClip(farplaneSunPos);
            uvw.xyz = NDCNormalized(uvw);
            float3 col = SAMPLE_TEXTURE2D_LOD(_MainTex,sampler_MainTex, i.uv,0);
            float luminance = GetLuminance(col);
            col = lerp(0, col, luminance);
            float ratio = _ScreenParams.x / _ScreenParams.y;
            float2 uv = float2(i.uv.x, i.uv.y / ratio);
            uv -= 0.5;
            ratio = length(uv);
            col = lerp(col,0,ratio);
            return float4(col, 1);
        }

        float4 fragRadialBlur(v2f i):SV_Target
        {
            Light mainLight = GetMainLight();
            float3 farplaneSunPos = _WorldSpaceCameraPos + (-mainLight.direction * _ProjectionParams.z);
            float4 uvw = TransformObjectToHClip(farplaneSunPos);
            uvw.xyz = NDCNormalized(uvw);
            if (uvw.z > 0)
            {
                return 0;
            }
            float2 direction =   uvw.xy - i.uv;
            direction /=12;
           
            float3 res = 0;
            for (int j = 0; j < 12; j++)
            {
                i.uv += direction  * _Radius;
                res += SAMPLE_TEXTURE2D_LOD(_MainTex,sampler_MainTex,i.uv ,0);
            }
            res /= 12;
            uvw.xy -= 0.5;
            float lerpValue = length(uvw.xy);
            if (lerpValue > 1.0f)
            {
                return lerp(float4(res,1),0,lerpValue-1.0f);
            }

            return float4(res, 1);
        }
        
        ENDHLSL

        Pass
        {
            //0
            Name "blit"
            blend one zero
            //blend SrcAlpha OneMinusSrcAlpha
            ztest always
            zwrite off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragBlit
            ENDHLSL
        }
        Pass
        {
            //1
            Name "Luminance"
            blend one zero
            //blend SrcAlpha OneMinusSrcAlpha
            ztest always
            zwrite off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragLuminance
            ENDHLSL
        }
        Pass
        {
            //2
            Name "RadialBlur"
            blend one zero
            //blend SrcAlpha OneMinusSrcAlpha
            ztest always
            zwrite off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragRadialBlur
            ENDHLSL
        }
        Pass
        {
            //3
            Name "ScreenBlur"
            blend one zero
            //blend SrcAlpha OneMinusSrcAlpha
            ztest always
            zwrite off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragBlit
            ENDHLSL
        }
        
        Pass
        {
            //4
            Name "Screen"
            blend one one
            //blend SrcAlpha OneMinusSrcAlpha
            ztest always
            zwrite off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragBlit
            ENDHLSL
        }
    }
}