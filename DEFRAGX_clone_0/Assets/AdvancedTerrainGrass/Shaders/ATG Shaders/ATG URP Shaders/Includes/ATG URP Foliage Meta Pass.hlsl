//  Fragment shader and functions - usually defined in LitInput.hlsl

    inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
    {
        outSurfaceData = (SurfaceData)0;
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, 1, _Cutoff);
        outSurfaceData.albedo = albedoAlpha.rgb;
        outSurfaceData.metallic = 0;
        outSurfaceData.specular = _SpecColor;
        outSurfaceData.smoothness = _Smoothness;
        outSurfaceData.normalTS = half3(0,0,1); //SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap));
        outSurfaceData.occlusion = 1;
        outSurfaceData.emission = 0;
    }