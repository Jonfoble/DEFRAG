#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

//--------------------------------------
//  Vertex shader

    VertexOutput LitGBufferPassVertex(VertexInput input)
    {
        VertexOutput output = (VertexOutput)0;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    //  Wind in ObjectSpace, returns WS -------------------------------
    //  Returns position, normal and tangent in WS!
        half4 instanceColor = 0;
        animateVertex(input.color, input.normalOS.xyz, input.tangentOS.xyz, input.positionOS.xyz, instanceColor);
        output.color = instanceColor;
    //  End Wind -------------------------------

        VertexPositionInputs vertexInput; // = GetVertexPositionInputs(input.positionOS.xyz);
        //vertexInput.positionWS = TransformObjectToWorld(input.positionOS.xyz);
        vertexInput.positionWS = input.positionOS.xyz;
        
        VertexNormalInputs normalInput; // = GetVertexNormalInputs(input.normalOS, input.tangentOS);
        normalInput.normalWS = input.normalOS;
        normalInput.tangentWS = input.tangentOS.xyz;

    //  We have to recalculate ClipPos! / see: GetVertexPositionInputs in Core.hlsl
        vertexInput.positionVS = TransformWorldToView(vertexInput.positionWS);
        vertexInput.positionCS = TransformWorldToHClip(vertexInput.positionWS);
        float4 ndc = vertexInput.positionCS * 0.5f;
        vertexInput.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
        vertexInput.positionNDC.zw = vertexInput.positionCS.zw;

        output.uv.xy = input.texcoord;

        #ifdef _NORMALMAP
            output.normalWS = normalInput.normalWS;
            real sign = input.tangentOS.w * GetOddNegativeScale();
            output.tangentWS = half4(normalInput.tangentWS, sign);
        #else
            output.normalWS = normalInput.normalWS;
        #endif

        OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
        
        #if defined(_NORMALMAP)
            OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
        #else
    //  TODO: When no normal map is applied we have to lookup SH fully per pixel
            #if !defined(LIGHTMAP_ON)
                output.vertexSH = 0;
            #endif
        #endif
        
        #ifdef _ADDITIONAL_LIGHTS_VERTEX
            half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
            output.vertexLighting = vertexLight;
        #endif

        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            output.positionWS = vertexInput.positionWS;
        #endif

        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            output.shadowCoord = GetShadowCoord(vertexInput);
        #endif

        output.positionCS = vertexInput.positionCS;
        return output;
    }

//--------------------------------------
//  Fragment shader and functions

    inline void InitializeFoliageLitSurfaceData(float2 uv, out SurfaceData outSurfaceData, out half translucency)
    {
        
    //  Lazy.. as clearcoat etc is missing here.
        outSurfaceData = (SurfaceData)0;

        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
    //  Early out
        outSurfaceData.alpha = Alpha(albedoAlpha.a, 1, _Cutoff);
        
        outSurfaceData.albedo = albedoAlpha.rgb;
        outSurfaceData.metallic = 0;
        outSurfaceData.specular = _SpecColor;
    
    //  Normal Map
        #if defined (_NORMALMAP)
            float4 sampleNormal = SAMPLE_TEXTURE2D(_BumpSpecMap, sampler_BumpSpecMap, uv);
            float3 tangentNormal;
            tangentNormal.xy = sampleNormal.ag * 2 - 1;
            tangentNormal.z = sqrt(1.0 - dot(tangentNormal.xy, tangentNormal.xy));  
            outSurfaceData.normalTS = tangentNormal;
            outSurfaceData.smoothness = sampleNormal.b * _Smoothness;
            translucency = sampleNormal.r;
        #else
            outSurfaceData.normalTS = float3(0, 0, 1);
            outSurfaceData.smoothness = _Smoothness;
            translucency = 1;
        #endif
        outSurfaceData.occlusion = 1;
        outSurfaceData.emission = 0;
    }

    void InitializeInputData(VertexOutput input, half3 normalTS, half facing, out InputData inputData)
    {
        inputData = (InputData)0;
        
        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            inputData.positionWS = input.positionWS;
        #endif

        inputData.positionCS = input.positionCS;
        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
        #ifdef _NORMALMAP
            #if !defined(_GBUFFERLIGHTING_SIMPLE) && !defined(_GBUFFERLIGHTING_VSNORMALS)
                normalTS.z *= facing;
            #endif
            half sgn = input.tangentWS.w;
            half3 bitangentWS = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS.xyz, input.normalWS.xyz));
        #else
            inputData.normalWS = input.normalWS;
            #if !defined(_GBUFFERLIGHTING_SIMPLE) && !defined(_GBUFFERLIGHTING_VSNORMALS)
                inputData.normalWS *= facing;
            #endif
        #endif

        #if defined (_GBUFFERLIGHTING_VSNORMALS)
            // From world to view space
            half3 normalVS = TransformWorldToViewDir(inputData.normalWS, true);
            // Now "flip" the normal
            normalVS.z = abs(normalVS.z);
            // From view to world space again
            inputData.normalWS = normalize( mul((float3x3)UNITY_MATRIX_I_V, normalVS) );
        #endif

        inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
        inputData.viewDirectionWS = viewDirWS;
        
        #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
            inputData.shadowCoord = input.shadowCoord;
        #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
            inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
        #else
            inputData.shadowCoord = float4(0, 0, 0, 0);
        #endif

        inputData.fogCoord = 0.0;

        #ifdef _ADDITIONAL_LIGHTS_VERTEX
            inputData.vertexLighting = input.vertexLighting.xyz;
        #else
            inputData.vertexLighting = half3(0, 0, 0);
        #endif

        #if defined(_NORMALMAP) 
            inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
        #endif

    //  TODO: Using VFACE and vertex normals – so we should sample SH fully per pixel
        #if !defined(_NORMALMAP) && !defined(LIGHTMAP_ON)
            inputData.bakedGI = SampleSH(inputData.normalWS);
        #endif

        inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
        inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
    }

    FragmentOutput LitGBufferPassFragment(VertexOutput input, half facing : VFACE)
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    //  Get the surface description
        //SurfaceDescription surfaceData;
    //  We have to use built in SurfaceData to make decals work.
        SurfaceData surfaceData;
        half translucency;        
        InitializeFoliageLitSurfaceData(input.uv.xy, surfaceData, translucency);

    //  Apply color variation
        surfaceData.albedo *= input.color.rgb;

    //  Prepare surface data (like bring normal into world space) and get missing inputs like gi
        InputData inputData;
        InitializeInputData(input, surfaceData.normalTS, facing, inputData);

        SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _MainTex);

    //  Decals
        #ifdef _DBUFFER
            ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
        #endif

        #if defined(_GBUFFERLIGHTING_TRANSMISSION)
            uint meshRenderingLayers = GetMeshRenderingLightLayer();
        //  Beta 5: must be commented as otherwise screen space shadows bug
            //inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
            half4 shadowMask = CalculateShadowMask(inputData);
            AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
            Light mainLight1 = GetMainLight(inputData, shadowMask, aoFactor);

            #if defined(_LIGHT_LAYERS)
                if (IsMatchingLightLayer(mainLight1.layerMask, meshRenderingLayers))
                {
            #endif
                    half transPower = _TranslucencyPower;
                    half3 transLightDir = mainLight1.direction + inputData.normalWS * _Distortion;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transPower - transPower);

                    #if defined(_SAMPLE_LIGHT_COOKIES)
                        real3 cookieColor = SampleMainLightCookie(inputData.positionWS);
                        mainLight1.color *= float4(cookieColor, 1);
                    #endif

                    surfaceData.emission +=
                        transDot 
                      * (1.0h - saturate(dot(mainLight1.direction, inputData.normalWS)))
                      * mainLight1.color * lerp(1, mainLight1.shadowAttenuation, _ShadowStrength)
                      * translucency * _TranslucencyStrength * 4
                      * surfaceData.albedo;

                    // Light unityLight;
                    // unityLight = GetMainLight();
                    // unityLight.distanceAttenuation = 1.0; //?

                    // #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && Donedefined(_SURFACE_TYPE_TRANSPARENT)
                    //     float4 shadowCoord = float4(screen_uv, 0.0, 1.0);
                    // #else
                    //     float4 shadowCoord = TransformWorldToShadowCoord(posWS.xyz);
                    // #endif
                    // unityLight.shadowAttenuation = MainLightShadow(shadowCoord, posWS.xyz, shadowMask, _MainLightOcclusionProbes);
            #if defined(_LIGHT_LAYERS)
                }
            #endif
        #endif

        BRDFData brdfData;
        InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

        Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
        MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, inputData.shadowMask);
    //  half3 color = GlobalIllumination(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
        half3 color = GlobalIllumination_Lux(brdfData, inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS, _AmbientReflection);

        return BRDFDataToGbuffer(brdfData, inputData, surfaceData.smoothness, surfaceData.emission + color, surfaceData.occlusion);

    }