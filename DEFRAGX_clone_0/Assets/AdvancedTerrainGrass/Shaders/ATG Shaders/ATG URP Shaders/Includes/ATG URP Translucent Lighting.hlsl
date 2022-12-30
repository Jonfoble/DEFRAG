#ifndef ATGURP_TRANSLUCENTLIGHTING_INCLUDED
#define ATGURP_TRANSLUCENTLIGHTING_INCLUDED


half3 GlobalIllumination_Lux(BRDFData brdfData, half3 bakedGI, half occlusion, float3 positionWS, half3 normalWS, half3 viewDirectionWS, 
    half specOccluison)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half NoV = saturate(dot(normalWS, viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);


//  As we use different AO factors here we do not really support debug lighting
    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, positionWS, brdfData.perceptualRoughness, occlusion) * specOccluison;

    return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}


half3 LightingPhysicallyBasedWrapped(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, half NdotL)
{
    half3 radiance = lightColor * (lightAttenuation * NdotL);
    //return DirectBDRF_Lux(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
    return DirectBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
}

half3 LightingPhysicallyBasedWrapped(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS, half NdotL)
{
    return LightingPhysicallyBasedWrapped(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS, NdotL);
}



half4 ATGURPTranslucentFragmentPBR(InputData inputData, half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha, half4 translucency, half AmbientReflection, half SSAOStrength
    #if defined(_CUSTOMWRAP)
        , half wrap
    #endif
    #if defined(_STANDARDLIGHTING)
        , half mask
    #endif
)
{
    
    SurfaceData surfaceData = (SurfaceData)0;
    {
        surfaceData.alpha = alpha;
        surfaceData.albedo = albedo;
        surfaceData.metallic = metallic;
        surfaceData.specular = specular;
        surfaceData.smoothness = smoothness;
        surfaceData.occlusion = occlusion;   
    }

    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);

//  Debugging
    #if defined(DEBUG_DISPLAY)
        half4 debugColor;
        if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
        {
            return debugColor;
        }
    #endif

    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor; 
    #if defined(_RECEIVESSAO)
        aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
        aoFactor.directAmbientOcclusion = lerp(1, aoFactor.directAmbientOcclusion, SSAOStrength);
        aoFactor.indirectAmbientOcclusion = lerp(1, aoFactor.indirectAmbientOcclusion, SSAOStrength);
    #else 
        aoFactor.directAmbientOcclusion = 1;
        aoFactor.indirectAmbientOcclusion = 1;
    #endif
    uint meshRenderingLayers = GetMeshRenderingLightLayer();

    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);
    half3 mainLightColor = mainLight.color;

    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData(inputData, surfaceData);

//  In order to use probe blending and proper AO we have to use the new GlobalIllumination function
    lightingData.giColor = GlobalIllumination_Lux(
        brdfData,
        //brdfData,   // brdfDataClearCoat,
        //0,          // surfaceData.clearCoatMask
        inputData.bakedGI,
        aoFactor.indirectAmbientOcclusion,
        inputData.positionWS,
        inputData.normalWS,
        inputData.viewDirectionWS,
        AmbientReflection
    );


//  Wrapped Diffuse
    #if defined(_CUSTOMWRAP)
        half w = wrap;
        #if defined(_STANDARDLIGHTING)
             w *= mask;
        #endif
    #else
        half w = 0.4;
    #endif
    half WrappedNormalization = rcp((1.0h + w) * (1.0h + w));
    half NdotL;

    #if defined(_LIGHT_LAYERS)
        if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
        {
    #endif
        //  Wrapped Diffuse   
            NdotL = saturate((dot(inputData.normalWS, mainLight.direction) + w) * WrappedNormalization );
            lightingData.mainLightColor = LightingPhysicallyBasedWrapped(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS, NdotL);
        
        //  Translucency
            half transPower = translucency.y;
            half3 transLightDir = mainLight.direction + inputData.normalWS * translucency.w;
            half transDot = dot( transLightDir, -inputData.viewDirectionWS );
            transDot = exp2(saturate(transDot) * transPower - transPower);
            lightingData.mainLightColor +=
                #if defined(_STANDARDLIGHTING)
                    mask *
                #endif
                transDot * (1.0 - NdotL) * mainLight.color * lerp(1.0h, mainLight.shadowAttenuation, translucency.z) * brdfData.diffuse * translucency.x * 4
                #if defined(_STANDARDLIGHTING)
                    * mask
                #endif
                ;

    #if defined(_LIGHT_LAYERS)
        }
    #endif

    #ifdef _ADDITIONAL_LIGHTS
        uint pixelLightCount = GetAdditionalLightsCount();
        LIGHT_LOOP_BEGIN(pixelLightCount) 
            Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
            #if defined(_LIGHT_LAYERS)
                if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
                {
            #endif
                //  Wrapped Diffuse
                    NdotL = saturate((dot(inputData.normalWS, light.direction) + w) * WrappedNormalization );
                    lightingData.additionalLightsColor += LightingPhysicallyBasedWrapped(brdfData, light, inputData.normalWS, inputData.viewDirectionWS, NdotL);
                //  Translucency
                    half3 lightColor = light.color;
                    int index = GetPerObjectLightIndex(lightIndex);
                    half4 shadowParams = GetAdditionalLightShadowParams(index);
                    #if !defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS)
                        lightColor *= lerp(1, 0, translucency.z);
                    #else
                    //  half isPointLight = shadowParams.z;
                        lightColor *= lerp(1, shadowParams.x, translucency.z);
                    #endif
                //  Apply Translucency
                    half transPower = translucency.y;
                    half3 transLightDir = light.direction + inputData.normalWS * translucency.w;
                    half transDot = dot( transLightDir, -inputData.viewDirectionWS );
                    transDot = exp2(saturate(transDot) * transPower - transPower);
                    lightingData.additionalLightsColor += brdfData.diffuse * transDot * (1.0h - NdotL) * lightColor * lerp(1.0h, light.shadowAttenuation, translucency.z) * light.distanceAttenuation  * translucency.x * 4
                    #if defined(_STANDARDLIGHTING)
                        * mask
                    #endif
                    ;

            #if defined(_LIGHT_LAYERS)
                }
            #endif
        LIGHT_LOOP_END
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif
    return CalculateFinalColor(lightingData, surfaceData.alpha);
}
#endif