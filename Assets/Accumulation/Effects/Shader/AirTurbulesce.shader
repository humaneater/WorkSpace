Shader "Effect/AirTurbulesce"
{
    Properties
    {
        /*_MainTex("粒子贴图",2D) = "white"{}
        [HDR] _Color("Color", Color) = (1, 1, 1, 1)
        _DepthMinus("深度差值",range(100,500)) = 0*/
        _NormalMap("法线扰动图",2D) = "white"{}
        _NoiseFactor("法线扰动幅度",range(0,1)) = 0
        _NoiseSpeed("法线扰动速度",range(-1,1)) = 0
        _Vertical("法线向上限制",range(0,1)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent" "Queue" = "Transparent"
        }
        Blend one OneMinusSrcAlpha
        Cull off

        zwrite off
        ColorMask RGB // colorRT的A通道需要作为实现角色bloom自定义效果的强度值，其他半透明物体避免写入

        Pass
        {
            HLSLPROGRAM
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag

            #include "Assets/Accumulation/ShaderLibrary/CommonFunctions.hlsl"

            struct appdata_particle
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f_particle
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };


            sampler2D _MainTex;
            CBUFFER_START(UnityPerMaterial)
            float4 _Color, _NormalMap_ST;
            float _DepthMinus, _NoiseFactor, _NoiseSpeed, _Vertical;
            sampler2D _CameraOpaqueTexture, _NormalMap;
            CBUFFER_END


            v2f_particle vert(appdata_particle v)
            {
                v2f_particle o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                //把世界空间的相机转到obj空间找到法线
                float3 center = float3(0, 0, 0);
                float3 viewPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                float3 normal = viewPos - center;
                normal.y *= _Vertical;
                normal = normalize(normal);

                //根据法线和上向量找到中心点的正交基,不能让法线和上平行，这样会导致差积无限接近0
                float3 up = normal.y > 0.99 ? float3(0, 0, 1) : float3(0, 1, 0);
                float3 right = normalize(cross(normal, up));
                up = normalize(cross(right, normal));

                //根据offset和正交基找到面朝我的顶点偏移
                float3 offset = v.vertex - center;
                float3 vertex = center + right * offset.x + up * offset.y + normal * offset.z;

                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;

                return o;
            }

            half4 frag(v2f_particle i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float2 uv = i.vertex / _ScreenParams.xy;
                float2 uvNoise = i.uv * _NormalMap_ST.xy + _NormalMap_ST.zw;
                //扰动uv
                float4 normalMap = tex2D(_NormalMap, float2(uvNoise.x, uvNoise.y + _Time.y * _NoiseSpeed));
                float2 normalNoise = dot(normalMap.xz, normalMap.xz) * _NoiseFactor;
                float4 albedo = tex2D(_CameraOpaqueTexture, uv + normalNoise);
                return float4(albedo.xyz, 1);
            }
            ENDHLSL
        }

    }
}