#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal@12.1.8/ShaderLibrary/DeclareNormalsTexture.hlsl"

struct StepState
{
    // InPixelSpace
    float3 curRayPos;
    int curLevel;
    int2 curPixelSize;
    int2 curPixelIndex;
};

float SamplerHiZDepth(float2 uv, int mipLevel = 0)
{
    if(uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1)
    {
        return 0.0f;
    }
    return SAMPLE_TEXTURE2D_X_LOD(_HizMap, sampler_HizMap, uv, mipLevel).r;
}

float LoadHiZDepth(uint2 frag, int mipLevel = 0)
{
    return LOAD_TEXTURE2D_X_LOD(_HizMap, frag, mipLevel).r;
}

float2 GetHizMapSize(int mipLevel)
{
    return floor(float2(_ScreenParams.x * pow(0.5f, mipLevel), _ScreenParams.y * pow(0.5f, mipLevel)));
}

int2 GetPixelIndex(float2 pixelPos, int mipLevel)
{
    return floor(pixelPos / pow(2, mipLevel));
}

int2 GetPixelIndexInHizMap(float2 uv, int mipLevel)
{
    return floor(uv * GetHizMapSize(mipLevel));
}

float3 GetRayPosInTS(float3 o, float3 dir, float len)
{
    return o + dir * len;
}

bool IsPixelIndexEqual(int2 pixel1, int2 pixel2)
{
    return (pixel1.x == pixel2.x) && (pixel1.y == pixel2.y);
}

void ComputePosAndReflection(float depth, float2 uv, float3 normal, out float3 outSamplePosInTS,
                             out float3 outReflDirInTS, out float outMaxLength)
{
    float4 ClipPos = float4(uv * 2.0f - 1.0f, depth, 1.0f);
    #if UNITY_UV_STARTS_AT_TOP
    float y = 1.0f - uv.y;
    ClipPos.y = 2.0f*y - 1.0f;
    #endif
    ClipPos = mul(UNITY_MATRIX_I_P, ClipPos);
    ClipPos /= ClipPos.w;
    float3 viewPos = ClipPos.xyz;

    // In view space
    float3 viewDir = normalize(viewPos.xyz);
    // view transform don't have scale, so that V_IT = V
    float3 normalVS = normalize(mul(UNITY_MATRIX_V, normal).xyz);
    float3 reflectDir = normalize(reflect(viewDir, normalVS));

    float rayLength = (_ProjectionParams.x * (viewPos.z + reflectDir.z * _MaxDistance) < _ProjectionParams.y)
                          ? (_ProjectionParams.y - _ProjectionParams.x * viewPos.z) / reflectDir.z * _ProjectionParams.x
                          : _MaxDistance;

    float3 endPosInVS = viewPos + reflectDir * rayLength;
    float4 endPosInTS = mul(UNITY_MATRIX_P, float4(endPosInVS, 1.0f));
    endPosInTS /= endPosInTS.w;
    #if UNITY_UV_STARTS_AT_TOP
    endPosInTS.y = -endPosInTS.y;
    #endif
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
StepState MoveToNextPixel(float3 startPos, float3 reflDir, float2 mip0Size, int2 increment, StepState curState)
{
    StepState nextState;
    const int2 nextPixel = curState.curPixelIndex + increment;
    const float2 nextPosInMip0 = (float2)nextPixel / curState.curPixelSize * mip0Size;
    float2 delta = nextPosInMip0 - startPos.xy;
    
    delta /= reflDir.xy;
    float len = min(delta.x, delta.y);
    nextState.curRayPos = startPos + len * reflDir;
    nextState.curLevel = curState.curLevel;
    nextState.curPixelSize = curState.curPixelSize;
    nextState.curPixelIndex = curState.curPixelIndex + (delta.x < delta.y ? int2(increment.x, 0) : int2(0, increment.y));

    return nextState;
}

float FindIntersection_Hiz(float3 startPos,
                           float3 reflDirInTS,
                           float maxTraceDistance,
                           out float3 outHitPosInTS)
{
    float3 v = maxTraceDistance*reflDirInTS;
    float3 EndPos = startPos + v;
    const float EndZ = EndPos.z;
    const float DeltaZ = EndZ - startPos.z;
    
    int2 increment;
    increment.x = v.x >= 0 ? 1.0f : -1.0f;
    increment.y = v.y >= 0 ? 1.0f : -1.0f;

    const float2 mip0Size = GetHizMapSize(0);
    startPos.xy *= mip0Size;
    EndPos.xy *= mip0Size;
    v.xy = EndPos.xy - startPos.xy;
    
    StepState curState;
    curState.curRayPos.xy = startPos.xy;
    curState.curRayPos.z = startPos.z;
    curState.curLevel = 2;
    curState.curPixelSize = GetHizMapSize(curState.curLevel);
    curState.curPixelIndex = GetPixelIndex(startPos.xy, curState.curLevel);
    
    curState = MoveToNextPixel(startPos, v, mip0Size, increment, curState);
    int i = 0;
    
    while(curState.curLevel>=0 && curState.curRayPos.z > EndZ && i<_MaxSteps)
    {
        float minDepth = LoadHiZDepth(curState.curPixelIndex, curState.curLevel);
        
        // 由近平面到远平面
        if(DeltaZ < 0)
        {
            curState.curPixelSize = GetHizMapSize(curState.curLevel);
            curState.curPixelIndex = GetPixelIndex(curState.curRayPos.xy, curState.curLevel);
            float3 tmpRay = minDepth < curState.curRayPos.z ? startPos + (minDepth - startPos.z)*v : curState.curRayPos;
            int2 nextPixel = GetPixelIndex(tmpRay.xy, curState.curLevel);

            if(IsPixelIndexEqual(curState.curPixelIndex, nextPixel))
            {
                if(curState.curLevel==0 && abs(minDepth - curState.curRayPos.z) > _Thickness)
                {
                    curState = MoveToNextPixel(startPos, v, mip0Size, increment, curState);
                }
                else
                {
                    curState.curLevel--;
                    curState.curRayPos = tmpRay;
                }
            }
            else
            {
                curState = MoveToNextPixel(startPos, v, mip0Size, increment, curState);
                curState.curLevel = min(curState.curLevel+1, _HizMapMipCount-1);
            }
        }

        i++;
    }

    bool isHit = curState.curLevel < 0;

    outHitPosInTS = isHit ? curState.curRayPos : startPos;

    return isHit ? length(outHitPosInTS - startPos) : 0.0f;
}


// float FindIntersection_Linear(float3 startPosInTS,
//                               float3 reflDirInTS,
//                               float maxTraceDistance,
//                               out float3 outHitPosInTS)
// {
//     float3 endPosInTS = startPosInTS + reflDirInTS * maxTraceDistance;
//
//     float3 dp = endPosInTS - startPosInTS;
//     int2 dp2 = int2(dp.xy * GetHizMapSize(0));
//     uint maxDist = max(abs(dp2.x), abs(dp2.y));
//     dp = dp / max(maxDist, 1);
//
//     float3 curPosInTS = startPosInTS;
//     outHitPosInTS = startPosInTS;
//     bool isHit = false;
//
//     for (int i = 0; i < maxDist && i < _MaxSteps; ++i)
//     {
//         // curPosInTS += dp;
//         int2 curPixel = GetPixelIndexInHizMap(curPosInTS.xy, 0);
//         curPosInTS = MoveToNextPixel(curPosInTS, curPixel, reflDirInTS, 0);
//
//         if(curPosInTS.x < 0 || curPosInTS.x > 1 || curPosInTS.y < 0 || curPosInTS.y > 1)
//         {
//             break;
//         }
//         
//         #if UNITY_REVERSED_Z
//         float curDepth = SamplerHiZDepth(curPosInTS.xy, 0);
//         #else
//         float curDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SamplerHiZDepth(sampleUV, 0));
//         #endif
//
//         if (curPosInTS.z < curDepth && curPosInTS.z > _Thickness * curDepth && curDepth - curPosInTS.z < _Thickness *
//             curDepth)
//         {
//             outHitPosInTS = curPosInTS;
//             isHit = true;
//             break;
//         }
//     }
//
//     return isHit ? length(outHitPosInTS - startPosInTS) : 0.0f;
// }


float4 HiZSSR(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float depth;
    float3 normal;
    float4 color;
    
    color = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, input.uv);
    #if UNITY_REVERSED_Z
    depth = SamplerHiZDepth(input.uv, 0);
    #else
    depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SamplerHiZDepth(input.uv, 0));
    #endif
    normal = SampleSceneNormals(input.uv);


    float3 samplePosInTS;
    float3 hitPosInTS;
    float3 reflDirInTS;
    float maxLength;

    ComputePosAndReflection(depth, input.uv, normal, samplePosInTS, reflDirInTS, maxLength);

    float pos = FindIntersection_Hiz(samplePosInTS, reflDirInTS, maxLength, hitPosInTS);

    float4 reflColor = LOAD_TEXTURE2D_X(_CameraColorTexture, floor(hitPosInTS.xy));
    reflColor = lerp(float4(0, 0, 0, 0), reflColor, pos > 0 ? 1.0f : 0.0f);

    return float4(color.rgb + reflColor.rgb, color.a);
}
