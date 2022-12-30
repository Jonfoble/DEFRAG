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

        output.uv = input.texcoord;

    //  Wind in Object Space, returns WS -------------------------------
        half4 instanceColor = 0;
        half3 tangent = half3(0,0,0);
        animateVertex(input.color, input.normalOS.xyz, tangent, input.positionOS.xyz, instanceColor);
    //  End Wind -------------------------------

        float3 positionWS = input.positionOS.xyz; //TransformObjectToWorld(input.positionOS.xyz);
        float3 normalWS = input.normalOS; //TransformObjectToWorldDir(input.normalOS);

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

//  Fragment shader

    half4 ShadowPassFragment(VertexOutput IN) : SV_TARGET
    {
        #if defined(_ALPHATEST_ON)
            half alpha = SampleAlbedoAlpha(IN.uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex)).a;
            clip(alpha - _Cutoff);
        #endif
        return 0;
    }