Varyings FullScreenVert(Attributes input)
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
    # if UNITY_UV_STARTS_AT_TOP
    output.positionCS.y = -output.positionCS.y;
    # endif
    
    #endif

    return output;
}


float HizGenerater(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    float4 minDepth;
    float2 uv = input.uv;

    // correct uv
    uv *= _HizParams.xy;
    float2 uv0 = uv + float2(-_HizParams.z, -_HizParams.w);
    float2 uv1 = uv + float2(_HizParams.z, -_HizParams.w);
    float2 uv2 = uv + float2(-_HizParams.z, _HizParams.w);
    float2 uv3 = uv + float2(_HizParams.z, _HizParams.w);
    
    minDepth.x = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv0).r;
    minDepth.y = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv1).r;
    minDepth.z = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv2).r;
    minDepth.w = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv3).r;
    
    minDepth.xy = max(minDepth.xy, minDepth.zw);
    minDepth.x = max(minDepth.x, minDepth.y);

    return minDepth.x;

    // return minDepth.x;

    float4 addDepth = 0.0f;
    if(_isWidthOdd == 1)
    {
        addDepth.x = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv + float2(3.0f*_HizParams.z, -_HizParams.w)).r;
        addDepth.y = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv + float2(3.0f*_HizParams.z, _HizParams.w)).r;
    }

    if(_isHeightOdd == 1)
    {
        addDepth.w = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv + float2(-_HizParams.z, 3.0f*_HizParams.w)).r;
        addDepth.z = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv + float2(_HizParams.z, 3.0f*_HizParams.w)).r;
    }

    addDepth.xy = max(addDepth.xy, addDepth.zw);
    addDepth.x = max(addDepth.x, addDepth.y);

    float addDepth2 = 0.0f;
    if(_isWidthOdd == 1 && _isHeightOdd == 1)
    {
        addDepth2 = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv + float2(3.0f*_HizParams.z, 3.0f*_HizParams.w)).r;
    }

    minDepth.x = max(minDepth.x, addDepth.x);
    minDepth.x = max(minDepth.x, addDepth2);

    // return 1.0f;
    return minDepth.x;
}

        


