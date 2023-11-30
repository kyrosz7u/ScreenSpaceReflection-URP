using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace UnityTemplateProjects
{
    public class HiZGeneraterFeature: ScriptableRendererFeature
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        private HiZGeneraterPass m_HiZGeneraterPass;
        public override void Create()
        {
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            m_HiZGeneraterPass = new HiZGeneraterPass();
            
            m_HiZGeneraterPass.Setup(Event, renderer, renderingData);
            
            renderer.EnqueuePass(m_HiZGeneraterPass);
        }
    }
}