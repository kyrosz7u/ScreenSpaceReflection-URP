using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityTemplateProjects;

public class HiZComputeFeature : ScriptableRendererFeature
{
    [Reload("Assets/Scripts/HiZGenCS.compute")]
    public ComputeShader HiZGeneraterShader; 
    public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
    private HiZComputePass m_HiZComputePass;
    public override void Create()
    { }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_HiZComputePass = new HiZComputePass();
        m_HiZComputePass.Setup(Event, renderer, renderingData, HiZGeneraterShader);
        
        renderer.EnqueuePass(m_HiZComputePass);
    }
}
