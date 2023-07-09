Shader "ScreenSpaceReflectionShader"
{
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.universal@12.1.8/ShaderLibrary/DeclareDepthTexture.hlsl"
    #include "Packages/com.unity.render-pipelines.universal@12.1.8/ShaderLibrary/DeclareNormalsTexture.hlsl"
    
    
    float _MaxStep = 128;
    float _StepSize = 0.1;
    float _MaxDistance = 100;
    float _Thickness = 1;
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
        output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
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
        float3 viewPos = ComputeViewSpacePosition(uv, depth, UNITY_MATRIX_I_P);
        
        // 计算反射向量
        float3 viewDir = normalize(-viewPos);
        float3 reflectDir = normalize(reflect(viewDir, normal));

        float4 reflColor = float4(0,0,0,0);
        UNITY_LOOP
        for(int i=0;i<_MaxStep;i++)
        {
            float3 reflPos=viewPos+reflectDir*_StepSize*i;
            
            float4 reflPosCS=mul(unity_CameraProjection,float4(reflPos,1));
            reflPosCS.xy/=reflPosCS.w;
            
            float screenDepth = reflPosCS.z;
            float2 reflUV= reflPosCS.xy*0.5+0.5;
            float reflDepth=SampleSceneDepth(reflUV);
            // 处理平台差异
            #if UNITY_REVERSED_Z
                screenDepth = 1.0 - screenDepth;
                reflDepth = 1.0 - reflDepth;
            #else
                reflDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, reflDepth);
            #endif
            
           if(reflUV.x > 0.0 && reflUV.y > 0.0 && reflUV.x < 1.0 && reflUV.y < 1.0 &&screenDepth<reflDepth)
           {
               // reflColor=SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, reflUV);
               reflColor = float4(reflUV,0.0f,1.0f);
               break;
           }
        } 

        // return float4(reflectDir*0.5+0.5,1.0f);
        return float4(viewPos.z,0.0f,0.0f,1.0f);
        // return float4(normal,1);
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
            ENDHLSL
        }
    }
}
