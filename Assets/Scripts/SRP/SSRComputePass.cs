
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.XR;

public class SSRComputePass : ScriptableRenderPass
{
    private UniversalRenderer m_Renderer;
    private Material m_Material;
    private ComputeShader shader;
    
    private RenderTexture m_BackBuffer;
    
    public void Setup(
        RenderPassEvent renderPassEvent,
        SSRComputeFeature.SSRComputeFeatureSettings settings,
        UniversalRenderer renderer, 
        ComputeShader cs)
    {
        this.renderPassEvent = renderPassEvent;
        m_Renderer = renderer;
        shader = cs;
        
        ConfigureInput(ScriptableRenderPassInput.Color);
        ConfigureInput(ScriptableRenderPassInput.Normal);

        shader.SetFloat("_MaxSteps", settings.MaxSteps);
        shader.SetFloat("_MaxDistance", settings.MaxDistance);
        shader.SetFloat("_Thickness", settings.Thickness);
        shader.SetFloat("_ReflectionStride", settings.ReflectionStride);
        shader.SetFloat("_ReflectionJitter", settings.ReflectionJitter);
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        int width = renderingData.cameraData.cameraTargetDescriptor.width;
        int height = renderingData.cameraData.cameraTargetDescriptor.height;
        
        m_BackBuffer = RenderTexture.GetTemporary(width, height, 0, renderingData.cameraData.cameraTargetDescriptor.graphicsFormat);
        m_BackBuffer.enableRandomWrite = true;
    }
    
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get("SSRComputePass");
        
        // cmd.SetComputeTextureParam(shader, 0, "_CameraColorTexture", m_Renderer.cameraColorTarget);
        // cmd.SetComputeTextureParam(shader, 0, "_CameraNormalsTexture", m_Renderer.cameraNormalTarget);
        // cmd.SetComputeTextureParam(shader, 0, "_HiZDepthTexture", m_Renderer.hizMap);
        
        shader.SetTexture(0, "_DestTex", m_BackBuffer);
        cmd.SetComputeVectorParam(shader, "_Count", new Vector4(m_BackBuffer.width, m_BackBuffer.height, 0, 0));
        
        cmd.DispatchCompute(shader, 0, m_BackBuffer.width / 8, m_BackBuffer.height / 8, 1);
        cmd.Blit(m_BackBuffer, m_Renderer.cameraColorTarget);
        cmd.SetRenderTarget(m_Renderer.cameraColorTarget, m_Renderer.cameraDepthTarget);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        m_BackBuffer.Release();
    }
}
