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

    output.positionCS = float4(input.positionOS.xyz, 1.0f);
    output.uv = input.uv;
    #endif

    #if UNITY_UV_STARTS_AT_TOP
    // output.positionCS.y *= _ScaleBiasRt.x;
    #endif
    
    return output;
}
