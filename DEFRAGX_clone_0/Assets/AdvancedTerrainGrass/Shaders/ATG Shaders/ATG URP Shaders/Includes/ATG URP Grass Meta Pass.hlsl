//  Fragment shader and functions - usually defined in LitInput.hlsl

    inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
    {
        outSurfaceData = (SurfaceData)0;
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
        outSurfaceData.alpha = Alpha(albedoAlpha.a, half4(1.0h, 1.0h, 1.0h, 1.0h), _Cutoff);
        outSurfaceData.albedo = albedoAlpha.rgb;
        outSurfaceData.metallic = 1.0h; // crazy?
        outSurfaceData.specular = _SpecColor;
        outSurfaceData.smoothness = _Smoothness;
        outSurfaceData.normalTS = half3(0,0,1);
        outSurfaceData.occlusion = 1;
        outSurfaceData.emission = 0.5h;
    }