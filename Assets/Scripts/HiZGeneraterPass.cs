using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityTemplateProjects
{
    public class HiZGeneraterPass: ScriptableRenderPass
    {
        public RenderTexture hizMap;
        public void Setup(RenderPassEvent renderPassEvent, RenderTexture hizMap)
        {
            this.renderPassEvent = renderPassEvent;
            this.hizMap = hizMap;
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get("HiZGeneraterPass");
            cmd.Clear();
            cmd.GenerateMips(renderingData.cameraData.cameraColorTarget);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}