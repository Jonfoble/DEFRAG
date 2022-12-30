//  Vertex shader
    
    VertexOutput DepthNormalsVertex(VertexInput input)
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
        //VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
        output.normalWS = input.normalOS; //normalInput.normalWS;

        output.uv.xy = input.texcoord;
        output.positionCS = vertexInput.positionCS;
        return output;
    }

//  Fragment shader
    
    half4 DepthNormalsFragment(VertexOutput input, half facing : VFACE) : SV_TARGET
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        #if defined(_ALPHATEST_ON)
            half alpha = SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_MainTex, sampler_MainTex)).a;
            clip(alpha - _Cutoff);
        #endif

    //  We do not output any per pixel normal here!
        #if defined(_GBUFFER_NORMALS_OCT)
            float3 normalWS = normalize(input.normalWS) * facing;
            float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
            float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
            half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
            return half4(packedNormalWS, 0.0);
        #else 
            float3 normalWS = NormalizeNormalPerPixel(input.normalWS) * facing;
            return half4(normalWS, 0.0);
        #endif
    }  