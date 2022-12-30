    
//  Vertex Shader

    VertexOutput DepthOnlyVertex(VertexInput input)
    {
        VertexOutput output = (VertexOutput)0;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    //  Wind in Object Space, returns WS -------------------------------
        half4 instanceColor = 0;
        half3 tangent = half3(0,0,0);
        animateVertex(input.color, input.normalOS.xyz, tangent, input.positionOS.xyz, instanceColor);
    //  End Wind -------------------------------

        VertexPositionInputs vertexInput;
        vertexInput.positionWS = input.positionOS.xyz; //TransformObjectToWorld(input.positionOS.xyz);
        vertexInput.positionCS = TransformWorldToHClip(vertexInput.positionWS);

    //  End Wind -------------------------------                

        output.uv.xy = input.texcoord;
        output.positionCS = vertexInput.positionCS;
        return output;
    }


//  Fragment Shader
    
    half4 DepthOnlyFragment(VertexOutput IN) : SV_TARGET
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
        #if defined(_ALPHATEST_ON)
            half alpha = SampleAlbedoAlpha(IN.uv.xy, TEXTURE2D_ARGS(_MainTex, sampler_MainTex)).a;
            clip(alpha - _Cutoff);
        #endif
        return 0;
    }