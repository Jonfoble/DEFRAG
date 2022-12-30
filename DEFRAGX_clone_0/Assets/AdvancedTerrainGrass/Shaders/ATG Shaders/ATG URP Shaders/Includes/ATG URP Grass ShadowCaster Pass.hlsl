#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

//  Shadow caster specific input
    float3 _LightDirection;
    float3 _LightPosition;


//  Vertex Shader

    VertexOutput ShadowPassVertex(VertexInput input)
    {
        VertexOutput output = (VertexOutput)0;
        UNITY_SETUP_INSTANCE_ID(input);

        float3 positionWS = 0; //TransformObjectToWorld(input.positionOS.xyz);

        #if defined(_NORMAL)
            input.normalOS = terrainNormal;
        #else
            input.normalOS = half3(0,1,0);
        #endif

    //  Calculate world space normal
        half3 normalWS = TransformObjectToWorldNormal(input.normalOS);    

    //  Wind in WorldSpace -------------------------------
    
    //  Do other stuff here
        #if defined(_ALPHATEST_ON)
            output.uv = input.texcoord;
            output.layer = (uint)TextureLayer;
        #endif

    //  Add bending
        half4 dummyInstanceColor = 0;
        bool clipped = false;
        bendGrass (positionWS, input.positionOS, normalWS, input.color, dummyInstanceColor, clipped);
        if (clipped) {
            output.positionCS = input.positionOS.xxxx / (1-clipped);
            return output;
        }

    //  We have to recalculate ClipPos! / see: GetVertexPositionInputs in Core.hlsl
    //  End Wind -------------------------------  

        #if _CASTING_PUNCTUAL_LIGHT_SHADOW
            float3 lightDirectionWS = normalize(_LightPosition - positionWS);
        #else
            float3 lightDirectionWS = _LightDirection;
        #endif

        output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
        #if UNITY_REVERSED_Z
            output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
        #else
            output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
        #endif
        return output;
    }

//  Fragment Shader

    half4 ShadowPassFragment(VertexOutput input) : SV_TARGET
    {
        #if defined(_ALPHATEST_ON)
            #if !defined(_TEXTUREARRAYS)
                Alpha(SampleAlbedoAlpha(input.uv.xy, TEXTURE2D_ARGS(_MainTex, sampler_MainTex)).a, half4(1,1,1,1), _CutoffShadows);
            #else
                half alpha = SAMPLE_TEXTURE2D_ARRAY(_MainTexArray, sampler_MainTexArray, input.uv, input.layer).a;
                clip(alpha - _CutoffShadows);
            #endif
        #endif
        return 0;
    }