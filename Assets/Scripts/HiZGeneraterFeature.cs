using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class HiZGeneraterFeature: ScriptableRendererFeature
{
    [Reload("Scripts/HizGen.compute")]
    public ComputeShader HiZGeneraterShader; 
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
    private HiZGeneraterPass m_HiZGeneraterPass;
    public override void Create()
    {
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_HiZGeneraterPass = new HiZGeneraterPass();
        
        m_HiZGeneraterPass.Setup(Event, renderer, renderingData, HiZGeneraterShader);
        
        renderer.EnqueuePass(m_HiZGeneraterPass);
    }
}
