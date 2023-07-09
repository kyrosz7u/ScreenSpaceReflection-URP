using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace DefaultNamespace
{
    public class CopyColorPass: ScriptableRenderPass
    {
        private const string CommandBufferTag = "ScreenSpaceReflectionPass";
        private Material m_Material;
        private FilteringSettings m_FilteringSettings;
        private RenderStateBlock m_RenderStateBlock;
        private RenderQueueRange m_renderQueueRange;
        private UniversalRenderer m_Renderer;
        private RenderTargetHandle m_ScreenSpaceReflectionTexture;
        
        private const string k_ShaderName = "CopyColorShader";
        private static readonly int ScreenSpaceReflectionTexture = Shader.PropertyToID("_ScreenSpaceReflectionTexture");
        
        
        public void Setup(
            RenderPassEvent renderPassEvent, 
            FilteringSettings filterSettings,
            UniversalRenderer renderer,
            RenderTargetHandle screenSpaceReflectionTexture)
        {
            this.renderPassEvent = renderPassEvent;
            m_Renderer = renderer;
            
            uint renderingLayerMask = (uint)1 << (int)(filterSettings.renderingLayerMask - 1);
            m_FilteringSettings = new FilteringSettings(m_renderQueueRange, filterSettings.layerMask, renderingLayerMask);
            m_Material = CoreUtils.CreateEngineMaterial(k_ShaderName);
            m_ScreenSpaceReflectionTexture = screenSpaceReflectionTexture;
        }
        
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            ConfigureTarget(m_Renderer.cameraColorTarget);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(CommandBufferTag);
            
            cmd.SetGlobalTexture(ScreenSpaceReflectionTexture, m_ScreenSpaceReflectionTexture.Identifier());
            
            cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, m_Material, 0, 0);
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);

        }
    }
}