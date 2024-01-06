Shader "HiZGeneraterShader"
{
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 uv : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

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

    TEXTURE2D(_DeepMipMap);
    SAMPLER(sampler_DeepMipMap);

    float4 _HizParams;

    #include "HizGenerater.hlsl"
    
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        Pass
        {
            Name "HizGenerater"
            ZTest Off
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex FullScreenVert
            #pragma fragment HizGenerater
            #pragma enable_d3d11_debug_symbols
            ENDHLSL
        }
    }
}
