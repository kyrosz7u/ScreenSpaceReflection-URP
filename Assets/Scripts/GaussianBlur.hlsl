#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct BlurVaryings
{
	float4 positionCS : SV_POSITION;
	float2 uv[5] : TEXCOORD0;
	UNITY_VERTEX_OUTPUT_STEREO
};

BlurVaryings VerticalBlurVert(Attributes input)
{
	BlurVaryings output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

#if _USE_DRAW_PROCEDURAL
	output.positionCS = GetQuadVertexPosition(input.vertexID);
	output.positionCS.xy = output.positionCS.xy * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f); //convert to -1..1
	output.uv = GetQuadTexCoord(input.vertexID) * _ScaleBias.xy + _ScaleBias.zw;
#else
	output.positionCS = input.positionOS;
#endif
			
    float2 uv = input.uv;
	uv.y = 1.0 - uv.y;
	float2 texelSize = 1.0f / ceil(_ScreenParams.xy);
			
    output.uv[0] = uv;
    output.uv[1] = uv - float2(0.0, texelSize.y * 1.0) * _BlurSize;
    output.uv[2] = uv + float2(0.0, texelSize.y * 1.0) * _BlurSize;
    output.uv[3] = uv - float2(0.0, texelSize.y * 2.0) * _BlurSize;
    output.uv[4] = uv + float2(0.0, texelSize.y * 2.0) * _BlurSize;
					 
    return output;
}

BlurVaryings HorizontalBlurVert(Attributes input)
{
	BlurVaryings output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

	#if _USE_DRAW_PROCEDURAL
	output.positionCS = GetQuadVertexPosition(input.vertexID);
	output.positionCS.xy = output.positionCS.xy * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f); //convert to -1..1
	output.uv = GetQuadTexCoord(input.vertexID) * _ScaleBias.xy + _ScaleBias.zw;
	#else
	output.positionCS = input.positionOS;
	#endif
			
	float2 uv = input.uv;
	uv.y = 1.0 - uv.y;
	float2 texelSize = 1.0f / ceil(_ScreenParams.xy);
			
	output.uv[0] = uv;
	output.uv[1] = uv + float2(texelSize.x * 1.0, 0.0) * _BlurSize;
	output.uv[2] = uv - float2(texelSize.x * 1.0, 0.0) * _BlurSize;
	output.uv[3] = uv + float2(texelSize.x * 2.0, 0.0) * _BlurSize;
	output.uv[4] = uv - float2(texelSize.x * 2.0, 0.0) * _BlurSize;
					 
	return output;
}

float4 FragBlur(BlurVaryings input) : SV_Target
{
	float weight[3] = {0.4026, 0.2442, 0.0545};
			
	float3 sum = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, input.uv[0]).rgb * weight[0];
			
	for (int it = 1; it < 3; it++) {
		sum += SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, input.uv[it*2-1]).rgb * weight[it];
		sum += SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, input.uv[it*2]).rgb * weight[it];
	}
			
	return float4(sum, 1.0);
}