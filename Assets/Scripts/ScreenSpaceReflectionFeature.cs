using DefaultNamespace;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace RendererFeature
{
    public class ScreenSpaceReflectionFeature: ScriptableRendererFeature
    {
        [System.Serializable]
        public class ScreenSpaceReflectionSettings
        {
            public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

            public FilteringSettings filterSettings = new FilteringSettings();
            
            public CompareFunction depthCompareFunction = CompareFunction.LessEqual;

            public StencilStateData stencilSettings = new StencilStateData();
            
        }

        public ScreenSpaceReflectionSettings settings = new ScreenSpaceReflectionSettings();
        public ScreenSpaceReflectionPass m_ScreenSpaceReflectionPass;
        public CopyColorPass m_CopyColorPass;
        
        private RenderTargetHandle m_ScreenSpaceReflectionTexture;
        
        
        public override void Create()
        {
            
        }
        

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            m_ScreenSpaceReflectionPass = new ScreenSpaceReflectionPass();
            m_CopyColorPass = new CopyColorPass();
            
            m_ScreenSpaceReflectionPass.Setup(settings.Event, settings.filterSettings, (UniversalRenderer)renderer, m_ScreenSpaceReflectionTexture);
            m_CopyColorPass.Setup(settings.Event, settings.filterSettings, (UniversalRenderer)renderer, m_ScreenSpaceReflectionTexture);
            
            renderer.EnqueuePass(m_ScreenSpaceReflectionPass);
            renderer.EnqueuePass(m_CopyColorPass);
        }
    }
}