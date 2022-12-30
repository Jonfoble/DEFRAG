//  Vertex shader
    
    VertexOutput DepthNormalsVertex(VertexInput input)
    {
        VertexOutput output = (VertexOutput)0;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
        VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
        output.normalWS = normalInput.normalWS;

        return output;
    }

//  Fragment shader
    
    half4 DepthNormalsFragment(VertexOutput input) : SV_TARGET
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        
    //  We do not output any per pixel normal here!
        #if defined(_GBUFFER_NORMALS_OCT)
            float3 normalWS = normalize(input.normalWS);
            float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
            float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
            half3 packedNormalWS = PackFloat2To888(remappedOctNormalWS);
            return half4(packedNormalWS, 0.0);
        #else 
            float3 normalWS = NormalizeNormalPerPixel(input.normalWS);
            return half4(normalWS, 0.0);
        #endif
    }  