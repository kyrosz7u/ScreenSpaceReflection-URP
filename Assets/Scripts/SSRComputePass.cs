
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.XR;

public class SSRComputePass : ScriptableRenderPass
{
    private UniversalRenderer m_Renderer;
    private Material m_Material;
    private ComputeShader shader;
    
    private RenderTexture m_OddBuffer;
    private RenderTexture m_EvenBuffer;
    
    public void Setup(
        RenderPassEvent renderPassEvent,
        SSRComputeFeature.SSRComputeFeatureSettings settings,
        UniversalRenderer renderer, 
        ComputeShader cs)
    {
        this.renderPassEvent = renderPassEvent;
        m_Renderer = renderer;
        shader = cs;

        shader.SetFloat("_MaxSteps", settings.MaxSteps);
        shader.SetFloat("_MaxDistance", settings.MaxDistance);
        shader.SetFloat("_Thickness", settings.Thickness);
        shader.SetFloat("_ReflectionStride", settings.ReflectionStride);
        shader.SetFloat("_ReflectionJitter", settings.ReflectionJitter);
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
    }
    
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get("SSRComputePass");
        
        cmd.SetComputeTextureParam(shader, 0, "_CameraColorTexture", m_Renderer.cameraColorTarget);
        cmd.SetComputeTextureParam(shader, 0, "_CameraNormalsTexture", m_Renderer.cameraNormalTarget);
        cmd.SetComputeTextureParam(shader, 0, "_CameraDepthTexture", m_Renderer.cameraDepthTarget);
    }
}
