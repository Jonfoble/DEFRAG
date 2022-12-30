#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

//  Shadow caster specific input
    float3 _LightDirection;
    float3 _LightPosition;


//  Vertex Shader

    VertexOutput ShadowPassVertex(VertexInput input)
    {
        VertexOutput output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_TRANSFER_INSTANCE_ID(input, output);

        float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
        float3 normalWS = TransformObjectToWorldDir(input.normalOS);

        #if _CASTING_PUNCTUAL_LIGHT_SHADOW
            float3 lightDirectionWS = normalize(_LightPosition - positionWS);
        #else
            float3 lightDirectionWS = _LightDirection;
        #endif

        output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
        #if UNITY_REVERSED_Z
            output.positionCS.z = min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
        #else
            output.positionCS.z = max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
        #endif
        return output;
    }

//  Fragment Shader

    half4 ShadowPassFragment(VertexOutput IN) : SV_TARGET
    {
        return 0;
    }