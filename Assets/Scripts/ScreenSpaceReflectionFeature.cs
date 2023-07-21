using UnityEngine;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceReflectionFeature: ScriptableRendererFeature
{
    [System.Serializable]
    public class ScreenSpaceReflectionSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

        public float MaxSteps = 32;
        public float MaxDistance = 10;
        [Range(0, 1)]public float Thickness = 0.1f;
        [Range(0, 1)]public float ReflectionStride = 0.5f;
        [Range(0, 1)]public float ReflectionJitter = 1.0f;
        [Range(-0.5f, 0.5f)]public float ReflectionBlurSpread = 0;
        [Range(0, 1)]public float LuminanceCloseOpThreshold = 0.5f;
    }

    public ScreenSpaceReflectionSettings settings = new ScreenSpaceReflectionSettings();
    private ScreenSpaceReflectionPass m_ScreenSpaceReflectionPass;

    private RenderTargetHandle m_ScreenSpaceReflectionTexture;
        
    public override void Create()
    {
            
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScreenSpaceReflectionPass = new ScreenSpaceReflectionPass();
        m_ScreenSpaceReflectionPass.Setup(settings.Event, settings, (UniversalRenderer)renderer);
            
        renderer.EnqueuePass(m_ScreenSpaceReflectionPass);
    }
}