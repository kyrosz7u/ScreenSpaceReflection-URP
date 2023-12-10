#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal@12.1.8/ShaderLibrary/DeclareNormalsTexture.hlsl"

float SamplerHiZDepth(float2 uv, int mipLevel = 0)
{
    return SAMPLE_TEXTURE2D_X_LOD(_HizMap, sampler_HizMap, uv, mipLevel).r;
}

float LoadHiZDepth(uint2 frag, int mipLevel = 0)
{
    return LOAD_TEXTURE2D_X_LOD(_HizMap, frag, mipLevel).r;
}

float2 GetHizMapSize(int mipLevel)
{
    return int2(_ScreenParams.xy) >> mipLevel;
}

float3 GetRayPosInTS(float3 o, float3 dir, float depth)
{
    return o + dir * depth;
}

void ComputePosAndReflection(float depth, float2 uv, float3 normal, out float3 outSamplePosInTS, out float3 outReflDirInTS, out float outMaxLength)
{
    float4 NdcPos = float4(uv * 2.0f - 1.0f, depth, 1.0f);
    NdcPos = mul(UNITY_MATRIX_I_P, NdcPos);
    NdcPos /= NdcPos.w;
    float3 viewPos = NdcPos.xyz;

    // In view space
    float3 viewDir = normalize(viewPos);
    // view transform don't have scale, so that V_IT = V
    float3 normalVS = normalize(mul(UNITY_MATRIX_V, normal).xyz);
    float3 reflectDir = normalize(reflect(viewDir, normalVS));

    // Clip to the near plane
    float rayLength = (_ProjectionParams.x*(viewPos.z + reflectDir.z * _MaxDistance) < _ProjectionParams.y) ? (_ProjectionParams.y - _ProjectionParams.x*viewPos.z) / reflectDir.z*_ProjectionParams.x : _MaxDistance;

    float3 endPosInVS = viewPos + reflectDir * rayLength;
    float4 endPosInTS = mul(UNITY_MATRIX_P, float4(endPosInVS, 1.0f));
    endPosInTS /= endPosInTS.w;
    endPosInTS.xy = endPosInTS.xy * 0.5f + 0.5f;

    

    #if UNITY_REVERSED_Z
    endPosInTS.z = 1.0f - endPosInTS.z;
    outSamplePosInTS = float3(NdcPos.xy*0.5f + 0.5f, 1.0f - NdcPos.z);
    outReflDirInTS  = normalize(endPosInTS.xyz - outSamplePosInTS);
    
    outMaxLength = outReflDirInTS.x>0 ? (1.0f - outSamplePosInTS.x) / outReflDirInTS.x : -outSamplePosInTS.x / outReflDirInTS.x;
    outMaxLength = min(outMaxLength, outReflDirInTS.y>0 ? (1.0f - outSamplePosInTS.y) / outReflDirInTS.y : -outSamplePosInTS.y / outReflDirInTS.y);
    outMaxLength = min(outMaxLength, outReflDirInTS.z>0 ? (1.0f - outSamplePosInTS.z) / outReflDirInTS.z : -outSamplePosInTS.z / outReflDirInTS.z);
    
    #else
    outSamplePosInTS = float3(NdcPos.xy*0.5f + 0.5f, NdcPos.z);
    outReflDirInTS  = normalize(endPosInTS.xyz - outSamplePosInTS);

    outMaxLength = outReflDirInTS.x>0 ? (1.0f - outSamplePosInTS.x) / outReflDirInTS.x : -outSamplePosInTS.x / outReflDirInTS.x;
    outMaxLength = min(outMaxLength, outReflDirInTS.y>0 ? (1.0f - outSamplePosInTS.y) / outReflDirInTS.y : -outSamplePosInTS.y / outReflDirInTS.y);
    outMaxLength = min(outMaxLength, outReflDirInTS.z>0 ? (1.0f - outSamplePosInTS.z) / outReflDirInTS.z : -outSamplePosInTS.z / outReflDirInTS.z);
    #endif
}

float FindIntersection_Linear(float3 startPosInTS,
                             float3 reflDirInTS,
                             float maxTraceDistance,
                             out float3 outHitPosInTS)
{
    float3 endPosInTS = startPosInTS + reflDirInTS * maxTraceDistance;

    float3 dp = endPosInTS - startPosInTS;
    int2 dp2 = int2(dp.xy * GetHizMapSize(0));
    uint maxDist = max(abs(dp2.x), abs(dp2.y));
    dp = dp / max(maxDist, 1);

    float3 curPosInTS = startPosInTS;
    outHitPosInTS = startPosInTS;
    bool isHit = false;
    
    for(int i=0;i<maxDist && i<_MaxSteps;++i)
    {
        curPosInTS += dp;
        float2 sampleUV = curPosInTS.xy;
        #if UNITY_REVERSED_Z
        sampleUV.y = 1.0f - sampleUV.y;
        #endif

        float curDepth = SamplerHiZDepth(sampleUV, 0);
        #if UNITY_REVERSED_Z
        curDepth = 1.0f - curDepth;
        #endif
        if(curPosInTS.z > curDepth && curPosInTS.z - curDepth < _Thickness)
        {
            outHitPosInTS = curPosInTS;
            isHit = true;
            break;
        }
    }

    return isHit ? length(outHitPosInTS - startPosInTS) : 0.0f;
}

float4 HiZSSR(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 sampleUV = input.uv;
    float2 texSize = ceil(_ScreenParams.xy);
    float depth;
    float3 normal;
    float4 color;

    // DX和Metal的Y轴方向相反，Unity中会自动处理统一到与OpenGL一致，但是在采样时需要注意
    if(_ProjectionParams.x < 0)
    {
        sampleUV.y = 1.0 - sampleUV.y;
        color = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, sampleUV);
        depth = SamplerHiZDepth(sampleUV, 0);
        normal = SampleSceneNormals(sampleUV);
        sampleUV.y = 1.0 - sampleUV.y;
    }
    else
    {
        color = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, sampleUV);
        depth = SamplerHiZDepth(sampleUV, 0);
        normal = SampleSceneNormals(sampleUV);
    }


    #if !UNITY_REVERSED_Z
    // Adjust z to match OpenGL's NDC
    depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, depth);
    #endif

    float3 samplePosInTS = float3(sampleUV, depth);
    float3 reflDirInTS;
    float maxDepth;

    ComputePosAndReflection(depth, sampleUV, normal, samplePosInTS, reflDirInTS, maxDepth);

    float pos = FindIntersection_Linear(samplePosInTS, reflDirInTS, maxDepth, samplePosInTS);

    float4 reflColor = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, samplePosInTS.xy);
    reflColor = lerp(float4(0, 0, 0, 0), reflColor, pos > 0 ? 1.0f : 0.0f);
    
    return float4(color.rgb + reflColor.rgb, color.a);
}

