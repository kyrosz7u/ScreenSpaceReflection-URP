Shader "ScreenSpaceReflectionShader"
{
    HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.universal@12.1.8/ShaderLibrary/DeclareNormalsTexture.hlsl"

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
            
            return float4(color.rgb, 1.0f);
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
