
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityTemplateProjects
{
    public class HiZGeneraterPass: ScriptableRenderPass
    {
        private UniversalRenderer m_Renderer;
        private RenderTargetIdentifier m_DepthTexture;
        private Material m_Material;
        
        private int m_DeepMipMapID = Shader.PropertyToID("_DeepMipMap");
        private List<RenderTexture> tmpTexList = new List<RenderTexture>();
        
        public void Setup(RenderPassEvent renderPassEvent, ScriptableRenderer renderer, RenderingData renderingData)
        {
            this.renderPassEvent = renderPassEvent;
            m_Renderer = (UniversalRenderer)renderer;
            m_Material = CoreUtils.CreateEngineMaterial("HiZGenerater");
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
            
            m_Renderer.hizMap = RenderTexture.GetTemporary(hizMapDesc);
            m_Renderer.hizMap.filterMode = FilterMode.Point;
            m_Renderer.hizMap.name = "HizMap";
            m_Renderer.hizMap.Create();
            
            cmd.Blit(m_DepthTexture, m_Renderer.hizMap);
            
            for(int i=1; i < mipCount; i++)
            {
                int srcWidth = width >> (i - 1);
                int srcHeight = height >> (i - 1);
                
                var tmpTex = RenderTexture.GetTemporary(srcWidth, srcHeight, 32, RenderTextureFormat.RFloat , RenderTextureReadWrite.Linear);
                tmpTex.name= "HiZGeneraterPass_tmpTex_" + i;
                tmpTex.filterMode = FilterMode.Point;
                tmpTex.Create();
                
                tmpTexList.Add(tmpTex);
                    
                cmd.CopyTexture(m_Renderer.hizMap, 0, i - 1, 0,0 , srcWidth,srcHeight,  tmpTex,0, 0, 0, 0);
                
                cmd.SetGlobalTexture(m_DeepMipMapID, tmpTex);
                
                int halfWidth = srcWidth >> 1;
                int halfHeight = srcHeight >> 1;
                
                cmd.SetGlobalInt("_isWidthOdd", srcWidth % 2 == 1 ? 1 : 0);
                cmd.SetGlobalInt("_isHeightOdd", srcHeight % 2 == 1 ? 1 : 0);
                cmd.SetGlobalVector("_HizParams", new Vector4(2.0f * halfWidth / srcWidth, 2.0f * halfHeight / srcHeight, 0.5f / srcWidth, 0.5f / srcHeight));
                
                cmd.SetRenderTarget(m_Renderer.hizMap, i);
                cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, m_Material, 0, 0);
            }
            cmd.SetGlobalInt("_HizMapMipCount", mipCount);
            cmd.SetGlobalTexture("_HizMap", m_Renderer.hizMap); 
            cmd.SetRenderTarget(m_Renderer.cameraColorTarget,m_Renderer.cameraDepthTarget);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        public override void FrameCleanup(CommandBuffer cmd)
        {
            RenderTexture.ReleaseTemporary(m_Renderer.hizMap);
            
            foreach(var tmpTex in tmpTexList)
            {
                RenderTexture.ReleaseTemporary(tmpTex);
            }
            
            tmpTexList.Clear();
        }
    }
    
}