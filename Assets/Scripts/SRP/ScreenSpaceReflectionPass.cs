using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceReflectionPass : ScriptableRenderPass
{
    private enum ScreenSpacePass
    {
        Reflection
    }

    private const string CommandBufferTag = "ScreenSpaceReflectionPass";
    private Material m_Material;
    private RenderStateBlock m_RenderStateBlock;
    private RenderQueueRange m_RenderQueueRange;

    private RenderTextureDescriptor m_CameraTextureDescriptor;
    private RenderTargetIdentifier m_ColorTexture;
    private RenderTargetIdentifier m_NormalTexture;
    private RenderTargetIdentifier m_RenderTarget;

    private RenderTargetIdentifier m_OddBuffer;
    private RenderTargetIdentifier m_EvenBuffer;

    private UniversalRenderer m_Renderer;

    private const string KShaderName = "ScreenSpaceReflectionShader";
    private static readonly int CameraColorTexture = Shader.PropertyToID("_CameraColorTexture");
    private static readonly int CameraNormalsTex = Shader.PropertyToID("_CameraNormalsTexture");


    public void Setup(
        RenderPassEvent renderPassEvent,
        ScreenSpaceReflectionFeature.ScreenSpaceReflectionSettings settings,
        UniversalRenderer renderer)
    {
        this.renderPassEvent = renderPassEvent;
        m_Renderer = renderer;

        m_Material = CoreUtils.CreateEngineMaterial(KShaderName);
        ConfigureInput(ScriptableRenderPassInput.Color);
        // 告诉URP renderer，这个pass需要camera的normal texture，
        // 这样URP renderer就会在执行这个pass之前，
        // 先把normal texture渲染到camera的normal texture上
        ConfigureInput(ScriptableRenderPassInput.Depth);
        ConfigureInput(ScriptableRenderPassInput.Normal);

        m_Material.SetFloat("_MaxSteps", settings.MaxSteps);
        m_Material.SetFloat("_MaxDistance", settings.MaxDistance);
        m_Material.SetFloat("_Thickness", settings.Thickness);
        m_Material.SetFloat("_ReflectionStride", settings.ReflectionStride);
        m_Material.SetFloat("_ReflectionJitter", settings.ReflectionJitter);
        m_Material.SetFloat("_BlurSize", 1.0f + settings.ReflectionBlurSpread);
        m_Material.SetFloat("_LuminanceCloseOpThreshold", settings.LuminanceCloseOpThreshold);
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        m_ColorTexture = m_Renderer.cameraColorTarget;
        m_NormalTexture = m_Renderer.cameraNormalTarget;
        m_RenderTarget = m_Renderer.cameraColorTarget;
        
        m_CameraTextureDescriptor = renderingData.cameraData.cameraTargetDescriptor;

        cmd.GetTemporaryRT(Shader.PropertyToID("_OddBuffer"), renderingData.cameraData.cameraTargetDescriptor,
            FilterMode.Point);
        cmd.GetTemporaryRT(Shader.PropertyToID("_EvenBuffer"), renderingData.cameraData.cameraTargetDescriptor,
            FilterMode.Point);
            
        m_OddBuffer = new RenderTargetIdentifier(Shader.PropertyToID("_OddBuffer"));
        m_EvenBuffer = new RenderTargetIdentifier(Shader.PropertyToID("_EvenBuffer"));

    }
    
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get(CommandBufferTag);

        cmd.SetGlobalTexture(CameraColorTexture, m_ColorTexture);
        cmd.SetGlobalTexture(CameraNormalsTex, m_NormalTexture);
        m_Material.SetTexture("_HizMap", m_Renderer.hizMap);
        
        cmd.SetRenderTarget(m_OddBuffer, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, m_Material, 0,
            (int)ScreenSpacePass.Reflection);
            
        cmd.Blit(m_OddBuffer, m_RenderTarget);
        cmd.SetRenderTarget(m_Renderer.cameraColorTarget, m_Renderer.cameraDepthTarget);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        cmd.ReleaseTemporaryRT(Shader.PropertyToID("_OddBuffer"));
        cmd.ReleaseTemporaryRT(Shader.PropertyToID("_EvenBuffer"));
    }
}