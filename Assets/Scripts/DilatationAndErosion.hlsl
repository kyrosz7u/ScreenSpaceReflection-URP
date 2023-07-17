#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// https://zhuanlan.zhihu.com/p/164619939



float CalculateLuminance(float3 color)
{
    // 将RGB颜色分量加权平均得到灰度值
    return dot(color, float3(0.299, 0.587, 0.114));
}

float4 LuminanceDilatation(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv = input.uv;
    uv.y = 1.0 - uv.y;
    
    float2 texSize = ceil(_ScreenParams.xy);
    
    float4 centalColor = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, uv);
    float centralLuminance = CalculateLuminance(centalColor.rgb); 
    
    const float2 offset[8] = {
        float2(-1, -1),
        float2(0, -1),
        float2(1, -1),

        float2(-1, 0),
        // float2(0, 0),
        float2(1, 0),

        float2(-1, 1),
        float2(0, 1),
        float2(1, 1)
    };

    float maxLuminance = 0;
    for(int i = 0; i < 8; i++)
    {
        float2 sampleUV = uv + offset[i] / texSize;
        float4 sampleColor = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, sampleUV);
        float sampleLuminance = CalculateLuminance(sampleColor.rgb);
        maxLuminance = max(maxLuminance, sampleLuminance);
    }
     float ratio = lerp(1.0f, maxLuminance/centralLuminance, _LuminanceCloseOpThreshold); 
    ratio = clamp(ratio, 0.0f, 1.0f);
    
    return ratio * centalColor;
}

float4 LuminanceErosion(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv = input.uv;
    uv.y = 1.0 - uv.y;
    
    float2 texSize = ceil(_ScreenParams.xy);
    
    float4 centalColor = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, uv);
    float centralLuminance = CalculateLuminance(centalColor.rgb);
    
    const float2 offset[8] = {
        float2(-1, -1),
        float2(0, -1),
        float2(1, -1),

        float2(-1, 0),
        // float2(0, 0),
        float2(1, 0),

        float2(-1, 1),
        float2(0, 1),
        float2(1, 1)
    };

    float minLuminance = 1.0f;
    for(int i = 0; i < 8; i++)
    {
        float2 sampleUV = uv + offset[i] / texSize;
        float4 sampleColor = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, sampleUV);
        float sampleLuminance = CalculateLuminance(sampleColor.rgb);
        minLuminance = min(minLuminance, sampleLuminance);
    }

    float ratio = lerp(1.0f, minLuminance/centralLuminance, _LuminanceCloseOpThreshold);

    ratio = clamp(ratio, 0.0f, 1.0f);
    
    return  ratio * centalColor;;
}
