    
//  Vertex Shader

    VertexOutput DepthOnlyVertex(VertexInput input)
    {
        VertexOutput output = (VertexOutput)0;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        VertexPositionInputs vertexInput;
        vertexInput.positionWS = TransformObjectToWorld(input.positionOS.xyz);

        #if defined(_ALPHATEST_ON)
            output.uv.xy = input.texcoord;
            output.layer = (uint)TextureLayer;
        #endif

    //  Add bending
        half3 dummyNormal = 1;
        half4 dummyInstanceColor = 0;
        bool clipped = false;

        #if defined(_NORMAL)
            input.normalOS = terrainNormal;
        #else
            input.normalOS = half3(0,1,0);
        #endif
    //  Calculate world space normal
        half3 normalWS = TransformObjectToWorldNormal(input.normalOS);

        bendGrass (vertexInput.positionWS, input.positionOS, normalWS, input.color, dummyInstanceColor, clipped);            
        if (clipped) {
            output.positionCS = input.positionOS.xxxx / (1-clipped);
            return output;
        }

    //  We have to recalculate ClipPos!
        output.positionCS = TransformWorldToHClip(vertexInput.positionWS);
        return output;
    }


//  Fragment Shader
    
    half4 DepthOnlyFragment(VertexOutput input) : SV_TARGET
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        
        #if defined(_ALPHATEST_ON)
            #if !defined(_TEXTUREARRAYS)
                Alpha(SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_MainTex, sampler_MainTex)).a, half4(1,1,1,1), _Cutoff);
            #else
                half alpha = SAMPLE_TEXTURE2D_ARRAY(_MainTexArray, sampler_MainTexArray, input.uv, input.layer).a;
                clip(alpha - _Cutoff);
            #endif
        #endif
        return 0;
    }