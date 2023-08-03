Shader "ScreenSpaceReflectionShader"
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

    TEXTURE2D_X_FLOAT(_CameraColorTexture);
    SAMPLER(sampler_CameraColorTexture);

    TEXTURE2D_X_FLOAT(_MainTex);
    SAMPLER(sampler_MainTex);
    
    float _MaxSteps;
    float _MaxDistance;
    float _Thickness;
    float _ReflectionStride;
    float _ReflectionJitter;
    float _BlurSize;
    float _LuminanceCloseOpThreshold;

    #include "FullScreen.hlsl"
    #include "ScreenSpaceReflection.hlsl"
    #include "GaussianBlur.hlsl"
    #include "CombineColor.hlsl"
    
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        Pass
        {
            Name "SSRPass"
            ZTest Off
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex FullScreenVert
            #pragma fragment EfficentSSR
            #pragma enable_d3d11_debug_symbols
            ENDHLSL
        }
        Pass
        {
            Name "SSRVerticalBlurPass"
            ZTest Off
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex VerticalBlurVert
            #pragma fragment FragBlur
            #pragma enable_d3d11_debug_symbols
            ENDHLSL    
        }
        Pass
        {
            Name "SSRHorizontalBlurPass"
            ZTest Off
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex HorizontalBlurVert
            #pragma fragment FragBlur
            #pragma enable_d3d11_debug_symbols
            ENDHLSL    
        }
        Pass
        {
            Name "CombineColorPass"
            ZTest Off
            ZWrite Off
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex FullScreenVert
            #pragma fragment CombineColor
            #pragma enable_d3d11_debug_symbols
            ENDHLSL    
        }
    }
}
