using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace UnityTemplateProjects
{
    public class HiZGeneraterFeature: ScriptableRendererFeature
    {
        public RenderTexture hizMap;
        private HiZGeneraterPass m_HiZGeneraterPass;
        public override void Create()
        {
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            m_HiZGeneraterPass = new HiZGeneraterPass();
            
            m_HiZGeneraterPass.Setup(RenderPassEvent.AfterRenderingOpaques, renderer, renderingData);
        }
    }
}