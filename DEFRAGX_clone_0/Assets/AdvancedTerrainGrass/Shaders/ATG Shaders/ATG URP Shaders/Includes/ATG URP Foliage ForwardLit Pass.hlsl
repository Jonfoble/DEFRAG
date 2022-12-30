//--------------------------------------
//  Vertex shader

    VertexOutput LitPassVertex(VertexInput input)
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

        half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
        half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

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
        
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

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
        
        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
        #ifdef _NORMALMAP
            normalTS.z *= facing;
            half sgn = input.tangentWS.w;
            half3 bitangentWS = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangentWS, input.normalWS.xyz));
        #else
            inputData.normalWS = input.normalWS * facing;
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

        inputData.fogCoord = input.fogFactorAndVertexLight.x;
        inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
        
    //  
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

    half4 LitPassFragment(VertexOutput input, half facing : VFACE) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    //  Get the surface description
        SurfaceData surfaceData;
        half translucency;
        InitializeFoliageLitSurfaceData(input.uv.xy, surfaceData, translucency);

    //  Apply color variation
        surfaceData.albedo *= input.color.rgb;

    //  Prepare surface data (like bring normal into world space (incl. VFACE)) and get missing inputs like gi
        InputData inputData;
        InitializeInputData(input, surfaceData.normalTS, facing, inputData);

    //  Decals
        #ifdef _DBUFFER
            ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
        #endif


    //  Apply lighting
        half4 color = ATGURPTranslucentFragmentPBR(
            inputData, 
            surfaceData.albedo, 
            surfaceData.metallic, 
            surfaceData.specular, 
            surfaceData.smoothness, 
            surfaceData.occlusion, 
            surfaceData.emission, 
            surfaceData.alpha,
            half4(_TranslucencyStrength * translucency, _TranslucencyPower, _ShadowStrength, _Distortion),
            _AmbientReflection, //_AmbientReflection
            _SSAOStrength       //_SSAOStrength
        );

    //  Add fog
        color.rgb = MixFog(color.rgb, inputData.fogCoord);
        return color;
    }