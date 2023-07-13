Shader "ScreenSpaceReflectionShader"
{
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.universal@12.1.8/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal@12.1.8/ShaderLibrary/DeclareNormalsTexture.hlsl"
    
    
    float _MaxSteps = 128;
    float _StepSize = 0.1;
    float _MaxDistance = 100;
    float _Thickness = 0.1;
    TEXTURE2D_X_FLOAT(_CameraColorTexture);
    SAMPLER(sampler_CameraColorTexture);

    struct Attributes
    {
    #if _USE_DRAW_PROCEDURAL
        uint vertexID     : SV_VertexID;
    #else
        float4 positionOS : POSITION;
        float2 uv         : TEXCOORD0;
    #endif
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4  positionCS  : SV_POSITION;
        float2  uv          : TEXCOORD0;
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

    // bool checkRayCollision(float3 rayDir, float3 rayOrigin, float3 rayEnd)
    // {
    //     float3 invRayDir = 1.0f / rayDir;
    //     float3 t0s = (boxMin - rayOrigin) * invRayDir;
    //     float3 t1s = (boxMax - rayOrigin) * invRayDir;
    //     float3 tsmaller = min(t0s, t1s);
    //     float3 tbigger = max(t0s, t1s);
    //     tmin = max(max(tsmaller.x, tsmaller.y), tsmaller.z);
    //     tmax = min(min(tbigger.x, tbigger.y), tbigger.z);
    //     return tmax > max(tmin, 0.0f);
    // }
    
    
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
        NdcPos/=NdcPos.w;
        float3 worldPos = NdcPos.xyz;
        
        // 计算反射向量
        float3 viewDir = normalize( worldPos - _WorldSpaceCameraPos);
        float3 normalWS = normalize(normal);
        float3 reflectDir = reflect(viewDir,normalWS);
        reflectDir = normalize(reflectDir);
        
        float4 reflColor = float4(0,0,0,0);
        UNITY_LOOP
        for(int i=0;i<=128;i++)
        {
            float3 reflPos=worldPos.xyz+reflectDir*0.01*i;
             
            float4 reflPosCS=mul(UNITY_MATRIX_VP,float4(reflPos,1.0f));
            float reflDepth = reflPosCS.w;
            
            reflPosCS/=reflPosCS.w;
            float2 reflUV= reflPosCS.xy*0.5+0.5;
            reflUV.y = 1.0 - reflUV.y;
            
            if(reflUV.x <0.0 || reflUV.y < 0.0 || reflUV.x > 1.0 || reflUV.y > 1.0 ) break;
            
            float screenDepth = SampleSceneDepth(reflUV);
            float ViewDepth = LinearEyeDepth(screenDepth, _ZBufferParams);
            
            if(reflDepth > ViewDepth && abs(reflDepth-ViewDepth)<0.01)
            {
                reflColor = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, reflUV);
                break;
            }
            
        } 
        return reflColor;
    }
    
    
    ENDHLSL

    SubShader
    {
        Tags{ "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        Pass
        {
            Name "NewUnlitShader"
            ZTest Off
            ZWrite Off
            Cull Off

            HLSLPROGRAM
                #pragma vertex FullscreenVert
                #pragma fragment Fragment
                #pragma enable_d3d11_debug_symbols
            ENDHLSL
        }
    }
}
