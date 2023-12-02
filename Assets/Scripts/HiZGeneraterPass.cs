
using System.Collections.Generic;
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
        
        private int m_DeepMipMapID = Shader.PropertyToID("_DeepMipMap");
        private List<RenderTexture> tmpTexList = new List<RenderTexture>();
        
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
            
            RenderTextureDescriptor hizMapDesc = new RenderTextureDescriptor(width, height, RenderTextureFormat.RFloat, 0);
            
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
            hizMapDesc.graphicsFormat = GraphicsFormat.None;
            hizMapDesc.colorFormat = RenderTextureFormat.RFloat;
            hizMapDesc.mipCount = mipCount;
            
            hizMap = RenderTexture.GetTemporary(hizMapDesc);
            hizMap.filterMode = FilterMode.Point;
            hizMap.Create();
            
            cmd.Blit(m_DepthTexture, hizMap);
            
            for(int i=1; i < mipCount; i++)
            {
                int srcWidth = width >> (i - 1);
                int srcHeight = height >> (i - 1);
                
                var tmpTex = RenderTexture.GetTemporary(srcWidth, srcHeight, 32, RenderTextureFormat.RFloat , RenderTextureReadWrite.Linear);
                tmpTex.filterMode = FilterMode.Point;
                tmpTex.Create();
                
                tmpTexList.Add(tmpTex);
                    
                cmd.CopyTexture(hizMap, 0, i - 1, 0,0 , srcWidth,srcHeight,  tmpTex,0, 0, 0, 0);
                
                cmd.SetGlobalTexture(m_DeepMipMapID, tmpTex);
                
                cmd.SetGlobalFloat("_SrcWidthInv", 0.5f / srcWidth);
                cmd.SetGlobalFloat("_SrcHeightInv", 0.5f / srcHeight);
                
                cmd.SetRenderTarget(hizMap, i);
                cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, m_Material, 0, 0);
                
                // RenderTexture.ReleaseTemporary(tmpTex);
            }
            cmd.SetGlobalInt("_HizMapMipCount", mipCount);
            
            cmd.SetRenderTarget(m_Renderer.cameraColorTarget,m_Renderer.cameraDepthTarget);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        public override void FrameCleanup(CommandBuffer cmd)
        {
            RenderTexture.ReleaseTemporary(hizMap);
            
            foreach(var tmpTex in tmpTexList)
            {
                RenderTexture.ReleaseTemporary(tmpTex);
            }
            
            tmpTexList.Clear();
        }
    }
    
}