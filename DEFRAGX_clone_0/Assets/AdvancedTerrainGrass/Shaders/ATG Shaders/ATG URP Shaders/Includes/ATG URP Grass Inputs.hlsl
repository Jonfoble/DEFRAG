#ifndef INPUT_LUXLWRP_BASE_INCLUDED
#define INPUT_LUXLWRP_BASE_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//  defines a bunch of helper functions (like lerpwhiteto)
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"  
//  defines SurfaceData, textures and the functions Alpha, SampleAlbedoAlpha, SampleNormal, SampleEmission
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
//  defines e.g. "DECLARE_LIGHTMAP_OR_SH"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#include "ATG URP Translucent Lighting.hlsl"

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

//  Material Inputs
    CBUFFER_START(UnityPerMaterial)

        float4  _BaseMap_ST;         // Meta Pass...
        half    _Cutoff;
        half    _CutoffShadows;
        half    _Smoothness;
        half3   _SpecColor;
        half    _Occlusion;
        half4   _WindMultiplier;

        half2   _MinMaxScales;
        half4   _HealthyColor;
        half4   _DryColor;

        half    _NormalBend;

        half    _TranslucencyPower;
        half    _TranslucencyStrength;
        half    _ShadowStrength;
        half    _Distortion;

        half    _AmbientReflection;

        half    _Clip;
        half    _ScaleMode;

        half    _SSAOStrength;

    //  Displacement
        half    _DisplacementSampleSize;
        half    _DisplacementStrength;
        half    _DisplacementStrengthVertical;
        half    _NormalDisplacement;

    //  VSP
        half    _VSPScaleMultiplier;
        float   _VSPCullDist;
        float   _VSPCullFade;

    CBUFFER_END

//  Additional textures
    #if !defined(_TEXTUREARRAYS)
        TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
        TEXTURE2D(_SpecTex); SAMPLER(sampler_SpecTex);
    #else
        TEXTURE2D_ARRAY(_MainTexArray); SAMPLER(sampler_MainTexArray);
        TEXTURE2D_ARRAY(_SpecTexArray); SAMPLER(sampler_SpecTexArray);
    #endif

//  Global Inputs
    TEXTURE2D(_AtgWindRT); SAMPLER(sampler_AtgWindRT);

//  Displacement
    #if defined(_GRASSDISPLACEMENT)
        TEXTURE2D(_Lux_DisplacementRT); SAMPLER(sampler_Lux_DisplacementRT);
        float4 _Lux_DisplacementPosition;
    #endif
    
    CBUFFER_START(AtgGrass)
        float4 _AtgTerrainShiftSurface;
        float4 _AtgWindDirSize;
        float4 _AtgWindStrengthMultipliers;
        float4 _AtgSinTime;
        float4 _AtgGrassFadeProps;
        float4 _AtgGrassShadowFadeProps;
        float3 _AtgSurfaceCameraPosition;
    CBUFFER_END

//  Shared Variables
    float InstanceScale;
    float TextureLayer;
    #if defined(_NORMAL)
        half3 terrainNormal;
    #endif

//  VSP
    float4 ControlData;

//  Structs
    struct VertexInput
    {
        float3 positionOS                       : POSITION;
        float3 normalOS                         : NORMAL;
        float4 tangentOS                        : TANGENT;
        float2 texcoord                         : TEXCOORD0;
        float2 lightmapUV                       : TEXCOORD1;
        half4 color                             : COLOR;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };
    
    struct VertexOutput
    {
        float4 positionCS                       : SV_POSITION;
        float2 uv                               : TEXCOORD0;
        half4 instanceColor                     : COLOR;
        uint layer                              : TEXCOORD8;

        #if !defined(ISSHADOWPASS) && !defined(DEPTHONLYPASS) && !defined(DEPTHNORMALPASS)
            DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
            #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                float3 positionWS               : TEXCOORD2;
            #endif
            #ifdef _NORMALMAP
                half3 normalWS                  : TEXCOORD3;
                half4 tangentWS                 : TEXCOORD4;
            #else
                half3 normalWS                  : TEXCOORD3;
            #endif
            #if defined(GBUFFERPASS)
                half3 vertexLighting            : TEXCOORD5;
            #else
                half4 fogFactorAndVertexLight   : TEXCOORD5;
            #endif
            #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord              : TEXCOORD6;
            #endif
        #endif

        #if defined(DEPTHNORMALPASS)
float3 positionWS               : TEXCOORD2;
            half3 normalWS                      : TEXCOORD3;
        #endif

        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    struct SurfaceDescription
    {
        float3 albedo;
        float alpha;
        float3 normalTS;
        float3 emission;
        float metallic;
        float3 specular;
        float smoothness;
        float occlusion;
        float translucency;
    };


//  Simple random function
    inline float nrand(float2 pos) {
        return frac(sin(dot(pos, half2(12.9898f, 78.233f))) * 43758.5453f);
    }

//  This happens in worldspace / To fade grass we need local space, unfortunately.
    void bendGrass (inout float3 positionWS, float3 positionOS, inout float3 normal, half4 incolor, inout half4 instanceColor, inout bool clipped) {

#if defined(_VSPSETUP)
    // Mind VSP strange scaling at slopes! So taking y is best here.
    InstanceScale = rcp(_VSPScaleMultiplier) * length(float3(UNITY_MATRIX_M[0].y, UNITY_MATRIX_M[1].y, UNITY_MATRIX_M[2].y));
#endif


        float scale = InstanceScale;
    //  Get some random value per instance
        float random = nrand(  float2(scale, 1.0 - scale) );
    //  Get pivot
        const float3 pivot = UNITY_MATRIX_M._m03_m13_m23;

#if !defined(_VSPSETUP)

        
        const float3 dist = pivot
            #if defined(DONOTUSE_ATGSETUP)
                    - _WorldSpaceCameraPos.xyz;         // vs shader version
                #elif !defined(UNITY_PROCEDURAL_INSTANCING_ENABLED)
                    - _WorldSpaceCameraPos.xyz;         // for wind setup
                #else
                    - _AtgSurfaceCameraPosition.xyz;    // atg original shader: we have to use a custom cam pos to make it match compute.
                #endif
        const float SqrDist = dot(dist, dist);
    //  Calculate far fade factor
        #if defined (ISSHADOWPASS)
            // TODO: Check why i can't revert this as well? Clip?
            float fade = 1.0f - saturate((SqrDist - _AtgGrassShadowFadeProps.x) * _AtgGrassShadowFadeProps.y);
        #elif defined (ISDEPTHPASS)
            float fade = saturate(( _AtgGrassFadeProps.x - SqrDist) * _AtgGrassFadeProps.y);
        #else
            float fade = saturate(( _AtgGrassFadeProps.x - SqrDist) * _AtgGrassFadeProps.y);
        #endif
    //  Cull based on far culling distance
        if (fade == 0.0f) {
            clipped = true;
            positionWS = 0.0f;
            return;
        }
    //  Calculate near fade factor / reversed!
        const float smallScaleClipping = saturate(( SqrDist - _AtgGrassFadeProps.z) * _AtgGrassFadeProps.w);
        float clip = (random < _Clip)? 1 : 0;
        clip = 1.0f - smallScaleClipping * clip;

        half farNear = (clip < 1) ? 1 : 0;

    //  Cull based on near culling distance
        if (clip == 0.0f) {
            clipped = true;
            positionWS = 0.0f;
            return;
        }
        fade *= clip;
    //  Apply fading
        //positionOS.xyz = lerp(positionOS.xyz, float3(0, 0, 0), 1.0 - fade);
    //  Always use xyz at far distances
        float3 targetPos = (_ScaleMode + farNear == 2) ? float3(0, positionOS.y, 0) : float3(0,0,0);
        positionOS.xyz = lerp(positionOS.xyz, targetPos, (1.0 - fade).xxx);

#else 

        #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
        // LOD0 must use this function with ditherFactor (ControlData.x) 1..0
        // LOD1 must use this function with ditherFactor -1..0
        // float fade = 1 - saturate(ControlData.x);
        // positionOS.xyz = lerp(positionOS.xyz, float3(0, 0, 0), fade);
        #endif

        const float3 dist = pivot - _WorldSpaceCameraPos.xyz; 
        const float SqrDist = dot(dist, dist);
        float fade = saturate(( _VSPCullDist * _VSPCullDist - SqrDist) * _VSPCullFade );
    //  Cull based on far culling distance
        if (fade == 0.0f) {
            clipped = true;
            positionWS = 0.0f;
            return;
        }
        positionOS.xyz = lerp(positionOS.xyz, float3(0, 0, 0), 1 - fade);

#endif

    //  Wind animation - and other stuff
        #if defined(_BENDINGMODE_BLUE)
             #define ibendAmount incolor.b * instanceColor.a
             #define ivocclusion incolor.b
        #else
            #define ibendAmount incolor.a * instanceColor.a
            #define ivocclusion incolor.a
        #endif
        #define iphase incolor.rr
        

    //  Do the texture lookup as soon as possible 
        positionWS = TransformObjectToWorld(positionOS.xyz);
        half4 wind = SAMPLE_TEXTURE2D_LOD(_AtgWindRT, sampler_AtgWindRT, positionWS.xz * _AtgWindDirSize.w + iphase * _WindMultiplier.z, _WindMultiplier.w);

        float3 cachedPositionWS = positionWS;

    //  Set color variation
        float normalizedScale = (scale - _MinMaxScales.x) * _MinMaxScales.y;
        normalizedScale = saturate(normalizedScale);
        #if defined(GRASSUSESTEXTUREARRAYS) && defined(_MIXMODE_RANDOM)
            instanceColor = lerp(_HealthyColor, _DryColor, nrand(pivot.zx));
        #else
            instanceColor = lerp(_HealthyColor, _DryColor, normalizedScale);
        #endif
        half3 windDir = _AtgWindDirSize.xyz;

    //  Frome here on we rely on the wind sample
        half windStrength = ibendAmount * _AtgWindStrengthMultipliers.x * _WindMultiplier.x;
        wind.r = wind.r  *  (wind.g * 2.0h - 0.243h  /* not a "real" normal as we want to keep the base direction */ );
        windStrength *= wind.r;

                //  Add non directional "jitter" – this helps to hide the quantized wind from the texture lookup.
                    //float2 jitter = lerp( float2 (_AtgSinTime.x, 0), _AtgSinTime.yz, float2(random, windStrength) );

                    //positionOS.xz +=
                    //    ((jitter.x + jitter.y) * _WindMultiplier.y)
                    //    * (0.075 + _AtgSinTime.w) * saturate(windStrength)
                    //;
                //  We have to go from object to worldspace again to apply jitter...
                    //positionWS = TransformObjectToWorld(positionOS.xyz);
    
    //  Add wind bending
        positionWS.xz += windDir.xz * windStrength;
    //  Animate normal
        #if !defined(ISSHADOWPASS) && !defined(ISDEPTHPASS)
            normal.xz += _NormalBend * windDir.xz * windStrength;
        #endif

    //  Add small scale jitter (HZD)
        float3 disp = sin( 4.0f * 2.650f * (positionWS.x + positionWS.y + positionWS.z + _Time.y)) * normal * float3(1.0f, 0.35f, 1.0f);
        positionWS += disp * windStrength * _WindMultiplier.y;
    
    //  Displacement
        #if defined(_GRASSDISPLACEMENT)
            #if defined(_BENDINGMODE_BLUE)
                #define bendAmount incolor.b * instanceColor.a
            #else
                #define bendAmount incolor.a * instanceColor.a
            #endif

            float2 samplePos = lerp(pivot.xz, cachedPositionWS.xz, _DisplacementSampleSize) - _Lux_DisplacementPosition.xy; // lower left corner

            samplePos = samplePos * _Lux_DisplacementPosition.z; // _Lux_DisplacementPosition.z = one OverSize

            if(saturate(samplePos.x) == samplePos.x) {
                if(saturate(samplePos.y) == samplePos.y) {
                    half4 displacementSample = SAMPLE_TEXTURE2D_LOD(_Lux_DisplacementRT, sampler_Lux_DisplacementRT, samplePos, 0);
                    
                    half3 bend = ( (displacementSample.rgb * 2 - 1)) * bendAmount;
                //  Blue usually is close to 1 (speaking of a normal). So we use saturate to get only the negative part.
                    bend.z = (saturate(displacementSample.b * 2) - 1) * bendAmount;

                //  Radial fade out of the touch bending
                    half2 radialMask = (samplePos.xy * 2 - 1);
                    half finarm = 1 - dot(radialMask, radialMask);
                    finarm = smoothstep(0,0.5,finarm);
                    bend *= finarm;

                    half3 disp;
                    disp.xz = bend.xy * _DisplacementStrength;
                    disp.y = -(abs(bend.x) + abs(bend.y) - bend.z) * _DisplacementStrengthVertical;

                //  ATG and VSP: We have to invert direction!?
                    disp.xz = -disp.xz;

                    // Normalizing length? Not really worth it...
                    // float vLength = length(cachedPositionWS - pivot);
                    // positionWS = lerp(positionWS, pivot + normalize(cachedPositionWS - pivot + disp) * vLength, saturate(dot(disp, disp)*16) ); // 16
                    positionWS = lerp(positionWS, cachedPositionWS + disp, saturate(dot(disp, disp)*16) ); // 16

                //  Do something to the normal. Sign looks fine.
                    normal = normal + disp * PI * _NormalDisplacement;
                }
            }
        #endif

    //  Store occlusion
        instanceColor.a = saturate( 1 - _Occlusion + ivocclusion);

    }
#endif