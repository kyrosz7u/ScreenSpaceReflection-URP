using DefaultNamespace;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

namespace RendererFeature
{
    public class ScreenSpaceReflectionFeature: ScriptableRendererFeature
    {
        [System.Serializable]
        public class ScreenSpaceReflectionSettings
        {
            public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

            public float MaxSteps = 32;
            public float StepSize = 0.5f;
            public float MaxDistance = 10;
            public float Thickness = 0.1f;
            [Range(0, 1)]public float ResolutionScale = 0.5f;
            [Range(-0.5f, 0.5f)]public float ReflectionBlurSpread = 0;
            [Range(0, 1)]public float LuminanceCloseOpThreshold = 0.5f;
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
            
            m_ScreenSpaceReflectionPass.Setup(settings.Event, settings, (UniversalRenderer)renderer);
            // m_CopyColorPass.Setup(settings.Event, settings, (UniversalRenderer)renderer, m_ScreenSpaceReflectionTexture);
            
            renderer.EnqueuePass(m_ScreenSpaceReflectionPass);
            // renderer.EnqueuePass(m_CopyColorPass);
        }
    }
}