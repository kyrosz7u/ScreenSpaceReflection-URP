using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityTemplateProjects
{
    public class HiZGeneraterPass: ScriptableRenderPass
    {
        private RenderTexture hizMap;
        private UniversalRenderer m_Renderer;
        private RenderTargetIdentifier m_DepthTexture;
        private Material m_Material;
        public void Setup(RenderPassEvent renderPassEvent, ScriptableRenderer renderer, RenderingData renderingData)
        {
            this.renderPassEvent = renderPassEvent;
            m_Renderer = (UniversalRenderer)renderer;
            m_Material = CoreUtils.CreateEngineMaterial("HiZGeneraterShader");
            ConfigureInput(ScriptableRenderPassInput.Depth);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_DepthTexture = m_Renderer.cameraDepthTarget;
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get("HiZGeneraterPass");
            
            int width = renderingData.cameraData.cameraTargetDescriptor.width;
            int height = renderingData.cameraData.cameraTargetDescriptor.height;

            int mipCount = Mathf.FloorToInt(Mathf.Log(Mathf.Min(width, height), 2)) + 1;
            
            RenderTextureDescriptor hizMapDesc = new RenderTextureDescriptor(width, height, RenderTextureFormat.Depth, 0);
            
            hizMapDesc.autoGenerateMips = false;
            hizMapDesc.useMipMap = true;
            hizMapDesc.depthBufferBits = 32;
            hizMapDesc.msaaSamples = 1;
            hizMapDesc.dimension = TextureDimension.Tex2D;
            hizMapDesc.sRGB = false;
            hizMapDesc.bindMS = false;
            hizMapDesc.enableRandomWrite = false;
            hizMapDesc.memoryless = RenderTextureMemoryless.None;
            hizMapDesc.useDynamicScale = false;
            hizMapDesc.volumeDepth = 1;
            hizMapDesc.vrUsage = VRTextureUsage.None;
            hizMapDesc.graphicsFormat = GraphicsFormat.R32_SFloat;
            hizMapDesc.mipCount = mipCount;
            
            hizMap = RenderTexture.GetTemporary(hizMapDesc);
            hizMap.filterMode = FilterMode.Point;
            //
            // cmd.CopyTexture(m_DepthTexture, 0, 0, hizMap, 0, 0);
            
            cmd.Blit(m_DepthTexture, hizMap);
            
            // cmd.SetGlobalTexture("_HiZMap", m_Renderer.cameraDepthTarget);
            
            cmd.SetGlobalTexture("_HiZMap", hizMap);
            for(int i=1; i < mipCount; i++)
            {
                int srcWidth = width >> (i - 1);
                int srcHeight = height >> (i - 1);
                
                // m_Material.SetFloat("_SrcWidthInv", 0.5f / srcWidth);
                // m_Material.SetFloat("_SrcHeightInv", 0.5f / srcHeight);
                // m_Material.SetInt("_MipLevel", i - 1);
                cmd.SetGlobalFloat("_SrcWidthInv", 0.5f / srcWidth);
                cmd.SetGlobalFloat("_SrcHeightInv", 0.5f / srcHeight);
                cmd.SetGlobalInt("_MipLevel", i - 1);
                
                cmd.SetRenderTarget(hizMap, i);
                cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, m_Material, 0, 0);
            }
            
            // cmd.SetGlobalTexture("_HiZMap", hizMap);
            
            Blit(cmd, hizMap, m_Renderer.cameraDepthTarget);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        public override void FrameCleanup(CommandBuffer cmd)
        {
            RenderTexture.ReleaseTemporary(hizMap);
        }
    }
    
}