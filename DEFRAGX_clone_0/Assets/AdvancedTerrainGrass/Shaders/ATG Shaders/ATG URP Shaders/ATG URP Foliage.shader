Shader "ATG URP/Foliage"
{
    Properties
    {
        [Header(Surface Options)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                               ("Culling", Float) = 0
        [Toggle(_ALPHATEST_ON)]
        _AlphaClip                          ("Alpha Clipping", Float) = 1.0
        _Cutoff                             ("    Threshold", Range(0.0, 1.0)) = 0.5
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows                     ("Receive Shadows", Float) = 1.0
        [Toggle(_RECEIVESSAO)]
        _SSAO                               ("Receive SSAO", Float) = 1.0
        _SSAOStrength                       ("    Strength", Range(0.0, 1.0)) = 1.0


        [Space(8)]
        [KeywordEnum(Standard, Simple, VsNormals, Transmission)]
        _GbufferLighting ("Gbuffer Lighting", Float) = 1
        [Toggle(_SAMPLE_LIGHT_COOKIES)]
        _ApplyCookiesForTransmission    ("    Enable Cookies for Transmission", Float) = 0.0

        [Space(8)]
        [Toggle(_VSPSETUP)]
        _VSP                                ("Enable VSP Support", Float) = 0.0
        _VSPScaleMultiplier                 ("    VSP Scale Multiplier", Float) = 1.0
        _VSPCullDist                        ("    VSP Cull Distance", Float) = 80.0
        _VSPCullFade                        ("    VSP Cull Fade", Float) = 0.001

        [Header(Surface Inputs)]
        [Space(8)]
        [NoScaleOffset][MainTexture]
        _MainTex                            ("Albedo (RGB) Alpha (A)", 2D) = "white" {}

        [Space(5)]
        [HideInInspector]_MinMaxScales      ("MinMaxScale Factors", Vector) = (1,1,1,1)
        _HealthyColor                       ("Healthy Color", Color) = (1,1,1,1)
        _DryColor                           ("Dry Color", Color) = (1,1,1,1)

        [Space(5)]
        _Smoothness                         ("Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecColor                          ("Specular", Color) = (0.2, 0.2, 0.2)

        [Space(5)]
        _AmbientReflection                  ("Ambient Reflection", Range(0.0, 1.0)) = 1

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                        ("Enable Normal Smoothness Trans Map", Float) = 0.0
        [NoScaleOffset] _BumpSpecMap
                                            ("    Normal (AG) Smoothness (B) Trans (R)", 2D) = "white" {}

        [Header(Transmission)]
        [Space(8)]
        _TranslucencyPower                  ("Power", Range(0.0, 10.0)) = 7.0
        _TranslucencyStrength               ("Strength", Range(0.0, 1.0)) = 1.0
        _ShadowStrength                     ("Shadow Strength", Range(0.0, 1.0)) = 0.7
        _Distortion                         ("Distortion", Range(0.0, 0.1)) = 0.01

        [Header(Wind)]
        [Space(8)]
        [KeywordEnum(Math, Texture)]
        _Wind                               ("Wind Input", Float) = 0
        [ATGWindFoliageDrawer]
        _WindMultiplier                     ("Wind Strength (X) Secondary Strength (Y) Edge Flutter (Z) Lod Level (W)", Vector) = (1, 2, 1, 0)
        _SampleSize                         ("Sample Size", Range(0.0, 2.0)) = 0.5


        [Header(Touch Bending)]
        [Space(8)]
        [Toggle(_GRASSDISPLACEMENT)]
        _EnableDisplacement                 ("Enable Touch Bending", Float) = 0
        _DisplacementSampleSize             ("    Sample Size", Range(0.0, 1)) = .5
        _DisplacementStrength               ("    Displacement Strength", Range(0.0, 3)) = 1


        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights                 ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections             ("Environment Reflections", Float) = 1.0

    //  Needed by Meta pass
        [HideInInspector] _BaseMap          ("Base Map", 2D) = "white" {}
    //  Needed by the inspector
        [HideInInspector] _Culling          ("Culling", Float) = 0.0
    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff
        [HideInInspector] _Color            ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags{
            "RenderType" = "TransparentCutout"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "Queue"="AlphaTest"
            "ShaderModel"="4.5"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _VSPSETUP
            #pragma shader_feature_local _GRASSDISPLACEMENT
            #pragma shader_feature_local _ALPHATEST_ON
            #define _SPECULAR_SETUP 1
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local_fragment _RECEIVESSAO
            #pragma shader_feature_local _WIND_MATH

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma instancing_options assumeuniformscaling procedural:setup

        //  Include base inputs and all other needed "base" includes
            #include "Includes/ATG URP Foliage Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass  
            #include "Includes/ATG URP Foliage ForwardLit Pass.hlsl"

            ENDHLSL
        }


    //  Shadows -----------------------------------------------------
        
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _VSPSETUP
            #pragma shader_feature_local _GRASSDISPLACEMENT
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _WIND_MATH

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

        //  Include base inputs and all other needed "base" includes
            #define ISSHADOWPASS
            #include "Includes/ATG URP Foliage Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP Foliage ShadowCaster Pass.hlsl"
            
            ENDHLSL
        }

    //  GBuffer ---------------------------------------------------

        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex LitGBufferPassVertex
            #pragma fragment LitGBufferPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _VSPSETUP
            #pragma shader_feature_local _GRASSDISPLACEMENT
            #pragma shader_feature_local _ALPHATEST_ON
            #define _SPECULAR_SETUP 1
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local_fragment _RECEIVESSAO
            #pragma shader_feature_local _WIND_MATH

        //  Deferred specific
            #pragma shader_feature_local_fragment _ _GBUFFERLIGHTING_SIMPLE _GBUFFERLIGHTING_VSNORMALS _GBUFFERLIGHTING_TRANSMISSION
        //  Needed in case Transmission is used
        //  Built in keyword mifght fail once cookies were activated...
            #pragma shader_feature_local_fragment _SAMPLE_LIGHT_COOKIES

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma instancing_options assumeuniformscaling procedural:setup          

            #define GBUFFERPASS
            #include "Includes/ATG URP Foliage Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
            #include "Includes/ATG URP Foliage GBuffer Pass.hlsl"
            ENDHLSL
        }    

    //  Depth -----------------------------------------------------
        
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _VSPSETUP
            #pragma shader_feature_local _GRASSDISPLACEMENT
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _WIND_MATH

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            #define DEPTHONLYPASS
            #include "Includes/ATG URP Foliage Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP Foliage DepthOnly Pass.hlsl"

            ENDHLSL
        }


    //  DeptNormals -----------------------------------------------------
        
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _VSPSETUP
            #pragma shader_feature_local _GRASSDISPLACEMENT
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _WIND_MATH

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            #define DEPTHNORMALPASS
            #include "Includes/ATG URP Foliage Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP Foliage DepthNormals Pass.hlsl"
            
            ENDHLSL
        }

    //  Meta -----------------------------------------------------
        
        Pass
        {
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #define _SPECULAR_SETUP
            #define _ALPHATEST_ON 1

        //  First include all our custom stuff
            #include "Includes/ATG URP Foliage Inputs.hlsl"
        //  Include custom function
            #include "Includes/ATG URP Foliage Meta Pass.hlsl"
        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    }

//  -----------------------------------------------------

    SubShader
    {
        Tags{
            "RenderType" = "TransparentCutout"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
            "Queue"="AlphaTest"
            "ShaderModel"="2.0"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _VSPSETUP
            #pragma shader_feature_local _GRASSDISPLACEMENT
            #pragma shader_feature_local _ALPHATEST_ON
            #define _SPECULAR_SETUP 1
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local_fragment _RECEIVESSAO
            #pragma shader_feature_local _WIND_MATH

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma instancing_options assumeuniformscaling procedural:setup

        //  Include base inputs and all other needed "base" includes
            #include "Includes/ATG URP Foliage Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass  
            #include "Includes/ATG URP Foliage ForwardLit Pass.hlsl"

            ENDHLSL
        }


    //  Shadows -----------------------------------------------------
        
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _VSPSETUP
            #pragma shader_feature_local _GRASSDISPLACEMENT
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _WIND_MATH

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

        //  Include base inputs and all other needed "base" includes
            #define ISSHADOWPASS
            #include "Includes/ATG URP Foliage Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP Foliage ShadowCaster Pass.hlsl"
            
            ENDHLSL
        }

    //  Depth -----------------------------------------------------
        
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _VSPSETUP
            #pragma shader_feature_local _GRASSDISPLACEMENT
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _WIND_MATH

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            #define DEPTHONLYPASS
            #include "Includes/ATG URP Foliage Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP Foliage DepthOnly Pass.hlsl"

            ENDHLSL
        }


    //  DeptNormals -----------------------------------------------------
        
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _VSPSETUP
            #pragma shader_feature_local _GRASSDISPLACEMENT
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _WIND_MATH

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            #define DEPTHNORMALPASS
            #include "Includes/ATG URP Foliage Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP Foliage DepthNormals Pass.hlsl"
            
            ENDHLSL
        }

    //  Meta -----------------------------------------------------
        
        Pass
        {
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit

            #define _SPECULAR_SETUP
            #define _ALPHATEST_ON 1

        //  First include all our custom stuff
            #include "Includes/ATG URP Foliage Inputs.hlsl"
        //  Include custom function
            #include "Includes/ATG URP Foliage Meta Pass.hlsl"
        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
