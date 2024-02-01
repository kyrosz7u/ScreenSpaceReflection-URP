using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public class SSRComputeFeature: ScriptableRendererFeature
{
    [System.Serializable]
    public class SSRComputeFeatureSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

        public float MaxSteps = 32;
        public float MaxDistance = 100;
        [Range(0, 20)]public float Thickness = 0.1f;
        [Range(0, 1)]public float ReflectionStride = 0.5f;
        [Range(0, 3)]public float ReflectionJitter = 1.0f;
        [Range(-0.5f, 0.5f)]public float ReflectionBlurSpread = 0;
        [Range(0, 1)]public float LuminanceCloseOpThreshold = 0.5f;
    }
    
    [Reload("Assets/Scripts/HizSSR.compute")]
    public ComputeShader HizSSRCS; 
    public SSRComputeFeatureSettings settings = new SSRComputeFeatureSettings();
    private SSRComputePass m_SSRComputePass;

    public override void Create()
    {
        
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_SSRComputePass = new SSRComputePass();
        m_SSRComputePass.Setup(settings.Event, settings, (UniversalRenderer)renderer, HizSSRCS);
            
        renderer.EnqueuePass(m_SSRComputePass);
    }
}
