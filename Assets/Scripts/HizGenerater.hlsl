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

    float2 uv = input.uv;

    // correct uv
    uv *= _HizParams.xy;
    float2 uv0 = uv + float2(-_HizParams.z, -_HizParams.w);
    float2 uv1 = uv + float2(_HizParams.z, -_HizParams.w);
    float2 uv2 = uv + float2(-_HizParams.z, _HizParams.w);
    float2 uv3 = uv + float2(_HizParams.z, _HizParams.w);
    
    float depth0 = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv0).r;
    float depth1 = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv1).r;
    float depth2 = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv2).r;
    float depth3 = SAMPLE_TEXTURE2D(_DeepMipMap, sampler_DeepMipMap, uv3).r;

    return max(max(max(depth0, depth1), depth2), depth3);
}

        


