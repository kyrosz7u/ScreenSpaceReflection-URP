Shader "ScreenSpaceReflectionShader"
{
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.universal@12.1.8/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal@12.1.8/ShaderLibrary/DeclareNormalsTexture.hlsl"


    float _MaxSteps;
    float _StepSize;
    float _MaxDistance;
    float _Thickness;
    float _ResolutionScale;

    TEXTURE2D_X_FLOAT(_CameraColorTexture);
    SAMPLER(sampler_CameraColorTexture);

    struct Attributes
    {
        #if _USE_DRAW_PROCEDURAL
        uint vertexID     : SV_VertexID;
        #else
        float4 positionOS : POSITION;
        float2 uv : TEXCOORD0;
        #endif
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 uv : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings FullscreenVert(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        #if _USE_DRAW_PROCEDURAL
        output.positionCS = GetQuadVertexPosition(input.vertexID);
        output.positionCS.xy = output.positionCS.xy * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f); //convert to -1..1
        output.uv = GetQuadTexCoord(input.vertexID) * _ScaleBias.xy + _ScaleBias.zw;
        #else
        output.positionCS = input.positionOS;
        output.positionCS.y = -output.positionCS.y;
        output.uv = input.uv;
        #endif

        return output;
    }


    float4 Fragment(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.uv;

        float4 color = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, uv);
        float3 normal = SampleSceneNormals(uv);

        // 获取相机空间坐标
        #if UNITY_REVERSED_Z
        float depth = SampleSceneDepth(uv);
        #else
            // 调整 z 以匹配 OpenGL 的 NDC
            float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
        #endif

        uv.y = 1.0 - uv.y;
        float4 NdcPos = float4(uv * 2.0f - 1.0f, depth, 1.0f);
        NdcPos = mul(UNITY_MATRIX_I_VP, NdcPos);
        NdcPos /= NdcPos.w;
        float3 worldPos = NdcPos.xyz;

        // 计算反射向量
        float3 viewDir = normalize(worldPos - _WorldSpaceCameraPos);
        float3 normalWS = normalize(normal);
        float3 reflectDir = reflect(viewDir, normalWS);
        reflectDir = normalize(reflectDir);

        float4 reflColor = float4(0, 0, 0, 0);
        UNITY_LOOP
        for (int i = 0; i <= 128; i++)
        {
            float3 reflPos = worldPos.xyz + reflectDir * 0.01 * i;

            float4 reflPosCS = mul(UNITY_MATRIX_VP, float4(reflPos, 1.0f));
            float reflDepth = reflPosCS.w;

            reflPosCS /= reflPosCS.w;
            float2 reflUV = reflPosCS.xy * 0.5 + 0.5;
            reflUV.y = 1.0 - reflUV.y;

            if (reflUV.x < 0.0 || reflUV.y < 0.0 || reflUV.x > 1.0 || reflUV.y > 1.0) break;

            float screenDepth = SampleSceneDepth(reflUV);
            float ViewDepth = LinearEyeDepth(screenDepth, _ZBufferParams);

            if (reflDepth > ViewDepth && abs(reflDepth - ViewDepth) < 0.01)
            {
                reflColor = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, reflUV);
                break;
            }
        }
        return color + reflColor;
    }

    float4 EfficentSSR(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.uv;
        float4 color = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, uv);
        float3 normal = SampleSceneNormals(uv);
        float2 texSize = _ScreenParams.xy;

        // Get camera space position
        #if UNITY_REVERSED_Z
        float depth = SampleSceneDepth(uv);
        #else
            // Adjust z to match OpenGL's NDC
            float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
        #endif

        uv.y = 1.0 - uv.y;
        float4 NdcPos = float4(uv * 2.0f - 1.0f, depth, 1.0f);
        NdcPos = mul(UNITY_MATRIX_I_P, NdcPos);
        NdcPos /= NdcPos.w;
        float3 viewPos = NdcPos.xyz;
        
        // In view space
        float3 viewDir = normalize(viewPos);
        // view transform don't have scale, so that V_IT = V
        float3 normalVS = normalize(mul((float3x3)UNITY_MATRIX_V, normal));
        float3 reflectDir = normalize(reflect(viewDir, normalVS));

        // Clip to the near plane
        float rayLength = ((viewPos.z + reflectDir.z * _MaxDistance) < _ProjectionParams.y)
                              ? (_ProjectionParams.y - viewPos.z) / reflectDir.z
                              : _MaxDistance;

        float4 startView = float4(viewPos, 1.0);
        float4 endView = float4(viewPos + (reflectDir * rayLength), 1.0);

        float4 startFrag = mul(UNITY_MATRIX_P, startView);
        startFrag = startFrag / startFrag.w;
        startFrag.xy = startFrag.xy * 0.5 + 0.5;
        startFrag.y = 1.0 - startFrag.y;
        startFrag.xy = startFrag.xy * texSize;

        float4 endFrag = mul(UNITY_MATRIX_P, endView);
        endFrag = endFrag / endFrag.w;
        endFrag.xy = endFrag.xy * 0.5 + 0.5;
        endFrag.y = 1.0 - endFrag.y;
        endFrag.xy = endFrag.xy * texSize;

        float deltaX = endFrag.x - startFrag.x;
        float deltaY = endFrag.y - startFrag.y;

        float useX = abs(deltaX) > abs(deltaY) ? 1.0 : 0.0;
        float delta = smoothstep(abs(deltaX), abs(deltaY), useX);
        float2 increment = float2(deltaX, deltaY) / max(delta, 0.001);
        
        float i = 0;
        float search0 = 0;
        float search1 = 0;

        int hit0 = 0;
        int hit1 = 0;
        
        float2 frag = startFrag;

        // UNITY_LOOP
        // for (i = 0; i < int(delta); ++i)
        // {
            // frag += increment;
            float2 fragUV = frag / texSize;
            fragUV.y = 1.0 - fragUV.y;
            
            float fragDepth = LinearEyeDepth(SampleSceneDepth(fragUV), _ZBufferParams);
            
            search1 = smoothstep((frag.y - startFrag.y) / deltaY, (frag.x - startFrag.x) / deltaX, useX);

            search1 = clamp(search1, 0.0, 1.0);

            // unity's view space depth is negative
            float viewDepth = - (startView.z * endView.z) / smoothstep(endView.z, startView.z, search1);
            float deltaDepth = viewDepth - fragDepth;

            if (deltaDepth > 0 && deltaDepth < _Thickness)
            {
                hit0 = 1;
                // break;
            }
            search0 = search1;
        // }

        // search1 = search0 + ((search1 - search0) / 2.0);
        //
        // float steps = _MaxSteps * hit0;
        // UNITY_LOOP
        // for (i = 0; i < steps; ++i)
        // {
        //     frag = smoothstep(startFrag.xy, endFrag.xy, search1);
        //     float2 fragUV = frag / texSize;
        //     float fragDepth = LinearEyeDepth(SampleSceneDepth(fragUV), _ZBufferParams);
        //
        //     float viewDepth = (startView.z * endView.z) / smoothstep(endView.z, startView.z, search1);
        //     float deltaDepth = viewDepth - fragDepth;
        //
        //     if (depth > 0 && depth < _Thickness)
        //     {
        //         hit1 = 1;
        //         search1 = search0 + ((search1 - search0) / 2);
        //     }
        //     else
        //     {
        //         float temp = search1;
        //         search1 = search1 + ((search1 - search0) / 2);
        //         search0 = temp;
        //     }
        // }

        return float4(delta,0, 0, 1.0);
    }
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        Pass
        {
            Name "NewUnlitShader"
            ZTest Off
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex FullscreenVert
            #pragma fragment EfficentSSR
            #pragma enable_d3d11_debug_symbols
            ENDHLSL
        }
    }
}