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
    float2 pixelIndex = input.positionCS.xy - 0.5f;
    pixelIndex *=2.0f;

    minDepth.x = LOAD_TEXTURE2D(_DeepMipMap, pixelIndex + float2(0.5f, 0.5f)).r;
    minDepth.y = LOAD_TEXTURE2D(_DeepMipMap, pixelIndex + float2(1.5f, 0.5f)).r;
    minDepth.z = LOAD_TEXTURE2D(_DeepMipMap, pixelIndex + float2(0.5f, 1.5f)).r;
    minDepth.w = LOAD_TEXTURE2D(_DeepMipMap, pixelIndex + float2(1.5f, 1.5f)).r;
    
    minDepth.xy = max(minDepth.xy, minDepth.zw);
    minDepth.x = max(minDepth.x, minDepth.y);

    float4 addDepth = 0.0f;
    if(_isWidthOdd == 1)
    {
        addDepth.x = LOAD_TEXTURE2D(_DeepMipMap, pixelIndex + float2(2.5f, 0.5f)).r;
        addDepth.y = LOAD_TEXTURE2D(_DeepMipMap, pixelIndex + float2(2.5f, 1.5f)).r;
    }
    
    if(_isHeightOdd == 1)
    {
        addDepth.z = LOAD_TEXTURE2D(_DeepMipMap, pixelIndex + float2(0.5f, 2.5f)).r;
        addDepth.w = LOAD_TEXTURE2D(_DeepMipMap, pixelIndex + float2(1.5f, 2.5f)).r;
    }
    
    addDepth.xy = max(addDepth.xy, addDepth.zw);
    addDepth.x = max(addDepth.x, addDepth.y);
    //
    float addDepth2 = 0.0f;
    if(_isWidthOdd == 1 && _isHeightOdd == 1)
    {
        addDepth2 = LOAD_TEXTURE2D(_DeepMipMap, pixelIndex + float2(2.5f, 2.5f)).r;
    }
    
    minDepth.x = max(minDepth.x, addDepth.x);
    minDepth.x = max(minDepth.x, addDepth2);
    //
    // // return 1.0f;
    return minDepth.x;
}

        


