#ifndef INPUT_LUXLWRP_BASE_INCLUDED
#define INPUT_LUXLWRP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
 
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half _Smoothness;
        half3 _SpecColor;

        half2 _MinMaxScales;
        half4 _HealthyColor;
        half4 _DryColor;  

    CBUFFER_END

//  Additional textures
    TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
    TEXTURE2D(_BumpSpecMap); SAMPLER(sampler_BumpSpecMap); float4 _BumpSpecMap_TexelSize;

//  Global Inputs
    TEXTURE2D(_AtgWindRT); SAMPLER(sampler_AtgWindRT);
    float4 _AtgTerrainShiftSurface;
    float4 _AtgWindDirSize;
    float4 _AtgWindStrengthMultipliers;
    float4 _AtgSinTime;
    float4 _AtgGrassFadeProps;
    float4 _AtgGrassShadowFadeProps;
    float3 _AtgSurfaceCameraPosition;

//  Shared Variables
    float InstanceScale;
    float TextureLayer;
    #if defined(_NORMAL)
        half3 terrainNormal;
    #endif

//  Structs
    struct VertexInput
    {
        float3 positionOS                   : POSITION;
        float3 normalOS                     : NORMAL;
        float4 tangentOS                    : TANGENT;
        float2 texcoord                     : TEXCOORD0;
        float2 lightmapUV                   : TEXCOORD1;
        half4 color                         : COLOR;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    
    struct VertexOutput
    {
        float4 positionCS                   : SV_POSITION;
        
        #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(DEPTHONLYPASS)
            float2 uv                       : TEXCOORD0;
            DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
            #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                float3 positionWS           : TEXCOORD2;
            #endif
            #ifdef _NORMALMAP
                half3 normalWS              : TEXCOORD3;
                half4 tangentWS             : TEXCOORD4;
            #else
                half3 normalWS              : TEXCOORD3;
            #endif
            half4 fogFactorAndVertexLight   : TEXCOORD6;
            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord          : TEXCOORD7;
            #endif
            half4 color                     : COLOR;
        #endif
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

#endif