float4 CombineColor(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    float2 uv = input.uv;
    uv.y = 1.0 - uv.y;
        
    float4 camera_color = SAMPLE_TEXTURE2D_X(_CameraColorTexture, sampler_CameraColorTexture, uv);
    float4 maintex_color = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, uv);

    return float4(camera_color.rgb+maintex_color.rgb, 1.0f);
}