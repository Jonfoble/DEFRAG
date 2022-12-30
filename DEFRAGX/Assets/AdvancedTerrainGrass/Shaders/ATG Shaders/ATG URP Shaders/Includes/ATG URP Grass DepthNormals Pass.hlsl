//  Vertex shader
    
    VertexOutput DepthNormalsVertex(VertexInput input)
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

        #if defined(_NORMAL)
            input.normalOS = terrainNormal;
        #else
            input.normalOS = half3(0,1,0);
        #endif
    //  Calculate world space normal
        half3 normalWS = TransformObjectToWorldNormal(input.normalOS); 

    //  Add bending
        half4 dummyInstanceColor = 0;
        bool clipped = false;
        bendGrass (vertexInput.positionWS, input.positionOS, normalWS, input.color, dummyInstanceColor, clipped);            
        if (clipped) {
            output.positionCS = input.positionOS.xxxx / (1-clipped);
            return output;
        }

        output.positionWS = vertexInput.positionWS;

    //  We have to recalculate ClipPos!
        output.positionCS = TransformWorldToHClip(vertexInput.positionWS);
        output.normalWS = NormalizeNormalPerVertex(normalWS);
        return output;
    }

//  Fragment shader
    
    half4 DepthNormalsFragment(VertexOutput input) : SV_TARGET
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

//  Nice try - but does not mitigate the problem regarding ssao...
    //  Create custom per vertex normal // SafeNormalize does not work here on Android?!
//        input.normalWS = half3( normalize( cross(ddy(input.positionWS), ddx(input.positionWS)) ) );
    //  TODO: Vulkan on Android here shows inverted normals?
        #if defined(SHADER_API_VULKAN)
//          input.normalWS *= -1;
        #endif
        
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