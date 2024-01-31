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
    return floor(float2(_ScreenParams.x * pow(0.5f, mipLevel), _ScreenParams.y * pow(0.5f, mipLevel)));
}

int2 GetPixelIndex(float2 uv, float2 textureSize)
{
    return floor(uv * textureSize);
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
    float3 reflectDirVS = normalize(reflect(viewDir, normalVS));

    float rayLength = (_ProjectionParams.x * (viewPos.z + reflectDirVS.z * _MaxDistance) < _ProjectionParams.y)
                          ? (_ProjectionParams.y - _ProjectionParams.x * viewPos.z) / reflectDirVS.z * _ProjectionParams.x
                          : _MaxDistance;

    float3 endPosInVS = viewPos + reflectDirVS * rayLength;
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
                           : 0-outSamplePosInTS.z / outReflDirInTS.z);
}


// return next pixel position in TS
float3 MoveToNextPixel(float3 startPosInTS, int2 curPixel, float3 reflDirInTS, int2 increment, float2 textureSize)
{
    int2 nextPixel = curPixel + increment;
    float2 nextUV = nextPixel / textureSize;
    float2 delta = nextUV - startPosInTS.xy;
    // offset太大了会造成形状的畸变
    float2 offset = float2(increment.x == 0? -1.0f : 1.0f, increment.y == 0? -1.0f : 1.0f) * 0.00001f;
    
    delta /= reflDirInTS.xy;
    float len = min(delta.x, delta.y);

    float3 nextPos = startPosInTS + len * reflDirInTS;

    nextPos.xy += (delta.x < delta.y ? float2(offset.x, 0.0f) : float2(0.0f, offset.y));
    
    return nextPos;
}

float FindIntersection_Hiz(float3 startPosInTS,
                           float3 reflDirInTS,
                           float maxTraceDistance,
                           out float3 outHitPosInTS)
{
    int curLevel = 0;
    float2 startTextureSize = GetHizMapSize(curLevel);
    
    int2 increment;
    float3 EndPosInTS = startPosInTS + maxTraceDistance*reflDirInTS;
    float StartZ = startPosInTS.z;
    float EndZ = EndPosInTS.z;
    EndZ = clamp(EndZ, 0.001f, 0.999f);
    float DeltaZ = EndZ - StartZ;

    float3 v = reflDirInTS;
    v /= v.z;
    
    increment.x = reflDirInTS.x >= 0 ? 1.0f : 0.0f;
    increment.y = reflDirInTS.y >= 0 ? 1.0f : 0.0f;
    
    int zDirection = EndZ > StartZ ? 1 : -1;
    
    int2 startPixel = GetPixelIndex(startPosInTS.xy, startTextureSize);
    
    float3 curRayPosInTS = MoveToNextPixel(startPosInTS, startPixel, reflDirInTS, increment, startTextureSize);
    int i = 0;
    
    while(curLevel>=0 && curRayPosInTS.z*zDirection < (EndZ)*zDirection && i<_MaxSteps)
    {
        float2 curTextureSize = GetHizMapSize(curLevel);
        int2 curPixel = GetPixelIndex(curRayPosInTS.xy, curTextureSize);
        float minDepth = SamplerHiZDepth(curRayPosInTS.xy, curLevel);

        // 由近平面到远平面
        if(DeltaZ < 0)
        {
            float3 tmpRay = minDepth < curRayPosInTS.z ? curRayPosInTS + (minDepth - curRayPosInTS.z)*v : curRayPosInTS;
            int2 nextPixel = GetPixelIndex(tmpRay.xy, curTextureSize);

            if(IsPixelIndexEqual(curPixel,nextPixel))
            {
                if(curLevel==0 && LinearEyeDepth(curRayPosInTS.z, _ZBufferParams) - LinearEyeDepth(minDepth, _ZBufferParams) > _Thickness)
                {
                    curRayPosInTS = MoveToNextPixel(curRayPosInTS, curPixel, reflDirInTS, increment, curTextureSize);
                }
                else
                {
                    curLevel--;
                    curRayPosInTS = tmpRay;
                }
            }
            else
            {
                curRayPosInTS = MoveToNextPixel(curRayPosInTS, curPixel, reflDirInTS, increment, curTextureSize);
                curLevel = min(curLevel+1, _HizMapMipCount-1);
            }
        }
        else
        {
            if(curRayPosInTS.z < minDepth)
            {
                if(curLevel==0 && abs(LinearEyeDepth(minDepth, _ZBufferParams) - LinearEyeDepth(curRayPosInTS.z, _ZBufferParams)) > _Thickness)
                {
                    curRayPosInTS = MoveToNextPixel(curRayPosInTS, curPixel, reflDirInTS, increment, curTextureSize);
                }
                else
                {
                    curLevel--;
                }
            }
            else
            {
                curRayPosInTS = MoveToNextPixel(curRayPosInTS, curPixel, reflDirInTS, increment, curTextureSize);
                curLevel = min(curLevel+1, _HizMapMipCount-1);
            }
        }

        i++;
    }

    bool isHit = curLevel < 0;

    outHitPosInTS = isHit ? curRayPosInTS : startPosInTS;

    return isHit ? length(outHitPosInTS - startPosInTS) : 0.0f;
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
    // normal = SampleSceneNormals(input.uv);
    float4 normalAndSmooth = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, UnityStereoTransformScreenSpaceTex(input.uv));
    normal = normalAndSmooth.xyz;
    float smooth = normalAndSmooth.w;

    #if defined(_GBUFFER_NORMALS_OCT)
    float2 remappedOctNormalWS = Unpack888ToFloat2(normal.xyz); // values between [ 0,  1]
    float2 octNormalWS = remappedOctNormalWS.xy * 2.0 - 1.0;    // values between [-1, +1]
    normal = UnpackNormalOctQuadEncode(octNormalWS);
    #endif


    float3 samplePosInTS;
    float3 hitPosInTS;
    float3 reflDirInTS;
    float maxLength;

    ComputePosAndReflection(depth, input.uv, normal, samplePosInTS, reflDirInTS, maxLength);
    float pos = FindIntersection_Hiz(samplePosInTS, reflDirInTS, maxLength, hitPosInTS);

    float2 curTextureSize = GetHizMapSize(0);
    int2 curPixel = GetPixelIndex(hitPosInTS.xy, curTextureSize);
    float4 reflColor = LOAD_TEXTURE2D(_CameraColorTexture, curPixel);
    reflColor = lerp(float4(0, 0, 0, 0), reflColor, pos > 0 ? smooth : 0.0f);

    return float4(color.rgb + reflColor.rgb, color.a);
}
