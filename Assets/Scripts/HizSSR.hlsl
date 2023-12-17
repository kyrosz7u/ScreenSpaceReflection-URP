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

int2 GetHizMapSize(int mipLevel)
{
    return int2((int)_ScreenParams.x >> mipLevel, (int)_ScreenParams.y >> mipLevel);
}

int2 GetPixelIndexInHizMap(float2 uv, int mipLevel)
{
    return floor(uv * GetHizMapSize(mipLevel));
}

float3 GetRayPosInTS(float3 o, float3 dir, float len)
{
    return o + dir * len;
}

void ComputePosAndReflection(float depth, float2 uv, float3 normal, out float3 outSamplePosInTS,
                             out float3 outReflDirInTS, out float outMaxLength)
{
    float4 ViewPos = float4(uv * 2.0f - 1.0f, depth, 1.0f);
    ViewPos = mul(UNITY_MATRIX_I_P, ViewPos);
    ViewPos /= ViewPos.w;
    float3 viewPos = ViewPos.xyz;

    // In view space
    float3 viewDir = normalize(viewPos);
    // view transform don't have scale, so that V_IT = V
    float3 normalVS = normalize(mul(UNITY_MATRIX_V, normal).xyz);
    float3 reflectDir = normalize(reflect(viewDir, normalVS));

    // Clip to the near plane
    float rayLength = (_ProjectionParams.x * (viewPos.z + reflectDir.z * _MaxDistance) < _ProjectionParams.y)
                          ? (_ProjectionParams.y - _ProjectionParams.x * viewPos.z) / reflectDir.z * _ProjectionParams.x
                          : _MaxDistance;

    float3 endPosInVS = viewPos + reflectDir * rayLength;
    float4 endPosInTS = mul(UNITY_MATRIX_P, float4(endPosInVS, 1.0f));
    endPosInTS /= endPosInTS.w;
    endPosInTS.xy = endPosInTS.xy * 0.5f + 0.5f;

    outSamplePosInTS = float3(uv, depth);
    outReflDirInTS = normalize(endPosInTS.xyz - outSamplePosInTS);

    outMaxLength = outReflDirInTS.x > 0
                       ? (1.0f - outSamplePosInTS.x) / outReflDirInTS.x
                       : -outSamplePosInTS.x / outReflDirInTS.x;
    outMaxLength = min(outMaxLength,
                       outReflDirInTS.y > 0
                           ? (1.0f - outSamplePosInTS.y) / outReflDirInTS.y
                           : -outSamplePosInTS.y / outReflDirInTS.y);
    outMaxLength = min(outMaxLength,
                       outReflDirInTS.z > 0
                           ? (1.0f - outSamplePosInTS.z) / outReflDirInTS.z
                           : -outSamplePosInTS.z / outReflDirInTS.z);
}


// return next pixel position in TS
float3 MoveToNextPixel(float3 startPosInTS, int2 curPixel, float3 reflDirInTS, int mipLevel)
{
    int2 increment;

    increment.x = reflDirInTS.x > 0 ? 1.0f : -1.0f;
    increment.y = reflDirInTS.y > 0 ? 1.0f : -1.0f;

    int2 HizMapSize = GetHizMapSize(mipLevel);
    
    int2 nextPixel = curPixel + increment;
    float2 nextUV = (float2)nextPixel / HizMapSize;
    nextUV += (float2)increment / HizMapSize / 128.0f;

    float2 delta = nextUV - startPosInTS.xy;
    delta /= reflDirInTS.xy;

    float len = min(abs(delta.x), abs(delta.y));
    
    return GetRayPosInTS(startPosInTS, reflDirInTS, len);
}

float FindIntersection_Hiz(float3 startPosInTS,
                           float3 reflDirInTS,
                           float maxTraceDistance,
                           out float3 outHitPosInTS)
{
    float StartZ = startPosInTS.z;
    float EndZ = StartZ + reflDirInTS.z * maxTraceDistance;
    float DeltaZ = EndZ - StartZ;
    
    int zDirection = EndZ > StartZ ? 1 : -1;

    int endLevel = 0;
    int curLevel = 0;
    int2 startPixel = GetPixelIndexInHizMap(startPosInTS.xy, curLevel);
    float3 curRayPosInTS = MoveToNextPixel(startPosInTS, startPixel, reflDirInTS, curLevel);
    int i = 0;
    
    while(curLevel>=0 && curRayPosInTS.z*zDirection < EndZ*zDirection && i<_MaxSteps)
    {
        int2 curPixel = GetPixelIndexInHizMap(curRayPosInTS.xy, curLevel);
        float2 sampleUV = curRayPosInTS.xy;
        if(sampleUV.x < 0 || sampleUV.x > 1 || sampleUV.y < 0 || sampleUV.y > 1)
        {
            break;
        }
        if (_ProjectionParams.x < 0)
        {
            sampleUV.y = 1.0f - sampleUV.y;
        }
        float minDepth = SamplerHiZDepth(sampleUV, curLevel);

        // 测试是否相交
        float3 tmpRayPosInTS = (minDepth<curRayPosInTS.z)?GetRayPosInTS(curRayPosInTS, reflDirInTS, (minDepth - curRayPosInTS.z)/DeltaZ):curRayPosInTS;
        int2 tmpPixel = GetPixelIndexInHizMap(tmpRayPosInTS.xy, curLevel);

        bool isAcross = false;
        
        if(tmpPixel.x == curPixel.x && tmpPixel.y == curPixel.y)
        {
            isAcross = curLevel == 0 && tmpRayPosInTS.z > _Thickness * minDepth && minDepth - tmpRayPosInTS.z > _Thickness * minDepth;
        }
        else
        {
            #if UNITY_REVERSED_Z
            isAcross = true;
            #else
            if(zDirection > 0)
            {
                isAcross = minDepth > curRayPosInTS.z;
            }
            else
            {
                isAcross = minDepth > curRayPosInTS.z;
            }
            #endif
        }

        if(isAcross)
        {
            curRayPosInTS = MoveToNextPixel(curRayPosInTS, curPixel, reflDirInTS, curLevel);
            curLevel = min(8, curLevel + 1);
        }
        else
        {
            curRayPosInTS = tmpRayPosInTS;
            curLevel--;
        }

        i++;
    }

    bool isHit = curLevel < 0 && curRayPosInTS.z*zDirection < EndZ*zDirection;

    outHitPosInTS = isHit ? curRayPosInTS : startPosInTS;

    return isHit ? length(outHitPosInTS - startPosInTS) : 0.0f;
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

    for (int i = 0; i < maxDist && i < _MaxSteps; ++i)
    {
        // curPosInTS += dp;
        int2 curPixel = GetPixelIndexInHizMap(curPosInTS.xy, 0);
        curPosInTS = MoveToNextPixel(curPosInTS, curPixel, reflDirInTS, 0);

        if(curPosInTS.x < 0 || curPosInTS.x > 1 || curPosInTS.y < 0 || curPosInTS.y > 1)
        {
            break;
        }
        float2 sampleUV = curPosInTS.xy;
        
        if (_ProjectionParams.x < 0)
        {
            sampleUV.y = 1.0f - sampleUV.y;
        }
        #if UNITY_REVERSED_Z
        float curDepth = SamplerHiZDepth(sampleUV, 0);
        #else
        float curDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SamplerHiZDepth(sampleUV, 0));
        #endif

        if (curPosInTS.z < curDepth && curPosInTS.z > _Thickness * curDepth && curDepth - curPosInTS.z < _Thickness *
            curDepth)
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
    float depth;
    float3 normal;
    float4 color;

    // DX和Metal的Y轴方向相反，Unity中会自动处理统一到与OpenGL一致，但是在采样时需要注意
    if (_ProjectionParams.x < 0)
    {
        sampleUV.y = 1.0 - sampleUV.y;
        color = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, sampleUV);
        #if UNITY_REVERSED_Z
        depth = SamplerHiZDepth(sampleUV, 0);
        #else
        depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SamplerHiZDepth(sampleUV, 0));
        #endif
        normal = SampleSceneNormals(sampleUV);
        sampleUV.y = 1.0 - sampleUV.y;
    }
    else
    {
        color = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, sampleUV);
        #if UNITY_REVERSED_Z
        depth = SamplerHiZDepth(sampleUV, 0);
        #else
        depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SamplerHiZDepth(sampleUV, 0));
        #endif
        normal = SampleSceneNormals(sampleUV);
    }

    float3 samplePosInTS;
    float3 reflDirInTS;
    float maxLength;

    ComputePosAndReflection(depth, sampleUV, normal, samplePosInTS, reflDirInTS, maxLength);

    float pos = FindIntersection_Hiz(samplePosInTS, reflDirInTS, maxLength, samplePosInTS);

    samplePosInTS.y = 1.0 - samplePosInTS.y;
    float4 reflColor = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, samplePosInTS.xy);
    reflColor = lerp(float4(0, 0, 0, 0), reflColor, pos > 0 ? 1.0f : 0.0f);

    return float4(color.rgb + reflColor.rgb, color.a);
}
