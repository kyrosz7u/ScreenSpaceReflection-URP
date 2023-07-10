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
        // output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
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
        // float z = LinearEyeDepth(depth, _ZBufferParams);
        // float4 viewPos = float4(uv * 2.0f - 1.0f, z, 1.0f);
        // float4 worldPos = mul(UNITY_MATRIX_I_VP, viewPos);
        // 1
        float3 worldPos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
        // viewPos.z = -viewPos.z;

        float4 clipPos = mul(UNITY_MATRIX_VP,float4(worldPos,1.0f));
        clipPos/=clipPos.w;
        clipPos.xy = clipPos.xy*0.5+0.5;
        clipPos.y = 1.0 - clipPos.y;
        float clipDepth = SampleSceneDepth(clipPos.xy);

        // return float4(abs(clipPos.x-uv.x)<0.01f? 1.0f:0.0f,abs(clipPos.y-uv.y)<0.01f? 1.0f:0.0f, abs(clipDepth-clipPos.z)<0.01f? 1.0f:0.0f? 1.0f:0.0f ,1.0f);
        
        // 计算反射向量
        float3 viewDir = normalize( worldPos - _WorldSpaceCameraPos);
        float3 normalWS = normalize(normal);
        float3 reflectDir = reflect(viewDir,normalWS);
        reflectDir = normalize(reflectDir);

        float4 reflColor = float4(0,0,0,0);
        UNITY_LOOP
        for(int i=2;i<=_MaxSteps;i++)
        {
            float3 reflPos=worldPos.xyz+reflectDir*_StepSize*i;
            
            float4 reflPosCS=mul(UNITY_MATRIX_VP,float4(reflPos,1.0f));
            reflPosCS/=reflPosCS.w;
            float2 reflUV= reflPosCS.xy*0.5+0.5;
            reflUV.y = 1.0 - reflUV.y;
            float reflDepth = reflPosCS.z;
            
            if(reflUV.x <0.0 || reflUV.y < 0.0 || reflUV.x > 1.0 || reflUV.y > 1.0 ) break;
            
            float screenDepth=SampleSceneDepth(reflUV);

            // screenDepth = Linear01Depth(screenDepth, _ZBufferParams);
            // reflDepth = Linear01Depth(reflDepth, _ZBufferParams);
            // if (screenDepth <0.5 || reflDepth <0.5) break;
            // reflColor = float4(i*0.01,0,0,1);
            if(reflDepth < screenDepth && abs(screenDepth-reflDepth)<0.1)
            {
                reflColor = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, reflUV);
                // reflColor = float4(1.0f,0.0f,0.0f,1);
                break;
            }
            
        } 

        // return float4(clipPos.w,0.0f,0.0f,1.0f);
        // return float4(reflectDir,1.0f);
        // return float4(uv,0.0f,1.0f);
        // return float4(depth,0.0f,0.0f,1.0f);
        // return float4(normal,1);
        // return float4(depth,Linear01Depth(clipDepth,_ZBufferParams),clipPos.z,1.0f);
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
