    
//  Vertex Shader

    VertexOutput DepthOnlyVertex(VertexInput input)
    {
        VertexOutput output = (VertexOutput)0;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

        output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
        return output;
    }


//  Fragment Shader
    
    half4 DepthOnlyFragment(VertexOutput IN) : SV_TARGET
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
        
        return 0;
    }