using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace RendererFeature
{
    public class ScreenSpaceReflectionPass : ScriptableRenderPass
    {
        private const string CommandBufferTag = "ScreenSpaceReflectionPass";
        private Material m_Material;
        private FilteringSettings m_FilteringSettings;
        private RenderStateBlock m_RenderStateBlock;
        private RenderQueueRange m_renderQueueRange;
        private RenderTextureDescriptor m_CameraTextureDescriptor;
        private RenderTargetIdentifier m_ColorTexture;
        private RenderTargetIdentifier m_NormalTexture;
        private UniversalRenderer m_Renderer;
        
        private const string k_ShaderName = "ScreenSpaceReflectionShader";
        private static readonly int CameraColorTexture = Shader.PropertyToID("_CameraColorTexture");
        private static readonly int CameraNormalsTex = Shader.PropertyToID("_CameraNormalsTexture");
        
        

        public void Setup(RenderPassEvent renderPassEvent, FilteringSettings filterSettings, UniversalRenderer renderer)
        {
            this.renderPassEvent = renderPassEvent;
            m_Renderer = renderer;
            
            uint renderingLayerMask = (uint)1 << (int)(filterSettings.renderingLayerMask - 1);
            m_FilteringSettings = new FilteringSettings(m_renderQueueRange, filterSettings.layerMask, renderingLayerMask);
            m_Material = CoreUtils.CreateEngineMaterial(k_ShaderName);
            ConfigureInput(ScriptableRenderPassInput.Color);
            // 告诉URP renderer，这个pass需要camera的normal texture，
            // 这样URP renderer就会在执行这个pass之前，
            // 先把normal texture渲染到camera的normal texture上
            ConfigureInput(ScriptableRenderPassInput.Normal);
        }
        
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_ColorTexture = m_Renderer.cameraColorTarget;
            m_NormalTexture = m_Renderer.cameraNormalTarget;
            ConfigureTarget(m_Renderer.cameraColorTarget);
        }
        

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(CommandBufferTag);
            
            cmd.SetGlobalTexture(CameraColorTexture, m_ColorTexture);
            cmd.SetGlobalTexture(CameraNormalsTex, m_NormalTexture);
            // cmd.SetRenderTarget(m_RenderTarget, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            
            cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, m_Material, 0, 0);
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);

        }
    }
}