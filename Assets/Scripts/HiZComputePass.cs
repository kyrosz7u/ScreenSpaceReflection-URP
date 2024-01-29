using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public class HiZComputePass : ScriptableRenderPass
{
    private UniversalRenderer m_Renderer;
    private RenderTexture hizMap;
    private RenderTargetIdentifier m_DepthTexture;
    private ComputeShader m_Shader;
    private int m_DeepMipMapID = Shader.PropertyToID("_DeepMipMap");
    
    public void Setup(RenderPassEvent renderPassEvent, ScriptableRenderer renderer, RenderingData renderingData, ComputeShader cs)
    {
        this.renderPassEvent = renderPassEvent;
        m_Renderer = (UniversalRenderer)renderer;
        m_Shader = cs;
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
        
        hizMap = m_Renderer.hizMap;
        RenderTextureDescriptor hizMapDesc = new RenderTextureDescriptor(width, height, RenderTextureFormat.RFloat, 0);
        
        hizMapDesc.autoGenerateMips = false;
        hizMapDesc.useMipMap = true;
        hizMapDesc.depthBufferBits = 32;
        hizMapDesc.msaaSamples = 1;
        hizMapDesc.dimension = TextureDimension.Tex2D;
        hizMapDesc.sRGB = false;
        hizMapDesc.bindMS = false;
        hizMapDesc.enableRandomWrite = true;
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
            
            int halfWidth = srcWidth >> 1;
            int halfHeight = srcHeight >> 1;
            Vector2 count = new Vector2(Mathf.Max(1, halfWidth), Mathf.Max(1, halfHeight));
            count -= new Vector2(0.5f, 0.5f);
            int isOddx = (srcWidth % 2 == 0) ? 0 : 1;
            int isOddy = (srcHeight % 2 == 0) ? 0 : 1;
            
            // cmd.SetComputeTextureParam(m_Shader, 0, "_SourceTex", hizMap, i - 1);
            // cmd.SetComputeTextureParam(m_Shader, 0, "_DestTex", hizMap, i);
            // cmd.SetComputeVectorParam(m_Shader, "_Count", new Vector4(halfWidth, halfHeight, isOddx, isOddy));
            m_Shader.SetTexture(0, "_SourceTex", m_Renderer.hizMap, i - 1);
            m_Shader.SetTexture(0, "_DestTex", m_Renderer.hizMap, i);
            m_Shader.SetVector("_Count", new Vector4(halfWidth, halfHeight, isOddx, isOddy));
            
            int x = Mathf.CeilToInt(count.x / 8f);
            int y = Mathf.CeilToInt(count.y / 8f);
            cmd.DispatchCompute(m_Shader, 0, x, y, 1);
        }
        
        cmd.SetGlobalInt("_HizMapMipCount", mipCount);
        cmd.SetRenderTarget(m_Renderer.cameraColorTarget,m_Renderer.cameraDepthTarget);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
    public override void FrameCleanup(CommandBuffer cmd)
    {
        RenderTexture.ReleaseTemporary(m_Renderer.hizMap);
    }
}
