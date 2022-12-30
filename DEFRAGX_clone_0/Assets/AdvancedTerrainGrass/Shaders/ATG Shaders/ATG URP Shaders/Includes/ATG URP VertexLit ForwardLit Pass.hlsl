//--------------------------------------
//  Vertex shader

    VertexOutput LitPassVertex(VertexInput input)
    {
        VertexOutput output = (VertexOutput)0;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    //  Lerp instanceColor according to scale (which has to be normalized)
        output.color = lerp(_HealthyColor, _DryColor, (InstanceScale - _MinMaxScales.x) * _MinMaxScales.y);

        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

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
        OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
       
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

    inline void InitializeLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
    {
        outSurfaceData = (SurfaceData)0;
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex));
        outSurfaceData.alpha = 1;
        
        outSurfaceData.albedo = albedoAlpha.rgb;
        outSurfaceData.metallic = 0;
        outSurfaceData.specular = _SpecColor;
    
    //  Normal Map
        #if defined (_NORMALMAP)
            float4 sampleNormal = SAMPLE_TEXTURE2D(_BumpSpecMap, sampler_BumpSpecMap, uv);
            outSurfaceData.normalTS = UnpackNormal(sampleNormal);
        #else
            outSurfaceData.normalTS = float3(0, 0, 1);
        #endif
        outSurfaceData.smoothness = albedoAlpha.a * _Smoothness;
        outSurfaceData.occlusion = 1;
        outSurfaceData.emission = 0;
    }

    void InitializeInputData(VertexOutput input, half3 normalTS, out InputData inputData)
    {
        inputData = (InputData)0;
        #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
            inputData.positionWS = input.positionWS;
        #endif
        
        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
        #ifdef _NORMALMAP
            float sgn = input.tangentWS.w;      // should be either +1 or -1
            float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
            inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
        #else
            inputData.normalWS = input.normalWS;
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
        
        inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
        
        inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
        inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
    }

    half4 LitPassFragment(VertexOutput input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    //  Get the surface description
        SurfaceData surfaceData;
        InitializeLitSurfaceData(input.uv.xy, surfaceData);

    //  Apply color variation
        surfaceData.albedo *= input.color.rgb;

    //  Prepare surface data (like bring normal into world space (incl. VFACE)) and get missing inputs like gi
        InputData inputData;
        InitializeInputData(input, surfaceData.normalTS, inputData);

    //  Apply lighting
        half4 color = UniversalFragmentPBR(inputData, surfaceData);

    //  Add fog
        color.rgb = MixFog(color.rgb, inputData.fogCoord);
        return color;
    }