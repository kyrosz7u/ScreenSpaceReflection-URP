Shader "ScreenSpaceReflectionShader"
{
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "ScreenSpaceReflection.hlsl"
    
    
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
        output.uv = input.uv;
        #endif

        return output;
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
            #pragma fragment RawSSR
            #pragma enable_d3d11_debug_symbols
            ENDHLSL
        }
    }
}