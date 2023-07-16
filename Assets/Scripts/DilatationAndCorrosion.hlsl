#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

TEXTURE2D_X_FLOAT(_CameraColorTexture);
SAMPLER(sampler_CameraColorTexture);

// https://zhuanlan.zhihu.com/p/164619939

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_OUTPUT_STEREO
};

float4 Corrosion(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv = input.uv;
    uv.y = 1.0 - uv.y;

    float4 OutColor = 0;

    return OutColor;
}


