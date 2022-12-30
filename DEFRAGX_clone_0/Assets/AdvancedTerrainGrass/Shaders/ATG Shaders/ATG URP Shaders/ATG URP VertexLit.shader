Shader "ATG URP/VertexLit"
{
    Properties
    {
        [Header(Surface Options)]
        [Space(8)]
        [Space(8)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _Cull                               ("Culling", Float) = 2
        [ToggleOff(_RECEIVE_SHADOWS_OFF)]
        _ReceiveShadows                     ("Receive Shadows", Float) = 1.0

        [Header(Surface Inputs)]
        [Space(8)]
        [NoScaleOffset][MainTexture]
        _MainTex                            ("Albedo (RGB) Smoothness (A)", 2D) = "white" {}
    //  To quiet compiler
        [HideInInspector] _BaseMap          ("BaseMap", 2D) = "white" {}

        [Space(5)]
        [HideInInspector]_MinMaxScales      ("MinMaxScale Factors", Vector) = (1,1,1,1)
        _HealthyColor                       ("Healthy Color", Color) = (1,1,1,1)
        _DryColor                           ("Dry Color", Color) = (1,1,1,1)

        [Space(5)]
        _Smoothness                         ("Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecColor                          ("Specular", Color) = (0.2, 0.2, 0.2)

        [Space(5)]
        [Toggle(_NORMALMAP)]
        _ApplyNormal                        ("Enable Normal Map", Float) = 0.0
        [NoScaleOffset] _BumpSpecMap
                                            ("    Normal", 2D) = "bump" {}
        [Header(Advanced)]
        [Space(8)]
        [ToggleOff]
        _SpecularHighlights                 ("Enable Specular Highlights", Float) = 1.0
        [ToggleOff]
        _EnvironmentReflections             ("Environment Reflections", Float) = 1.0

    //  Needed by the inspector
        [HideInInspector] _Culling          ("Culling", Float) = 0.0

    //  Lightmapper and outline selection shader need _MainTex, _Color and _Cutoff
        [HideInInspector] _Color            ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
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
            #define _SPECULAR_SETUP 1
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
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
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP VertexLit ForwardLit Pass.hlsl"
        
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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

        //  Include base inputs and all other needed "base" includes
            #define ISSHADOWPASS
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP VertexLit ShadowCaster Pass.hlsl"

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
            #define _SPECULAR_SETUP 1
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

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
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
            #include "Includes/ATG URP VertexLit GBuffer Pass.hlsl"
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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            #define DEPTHONLYPASS
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP VertexLit DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  DepthNormals -----------------------------------------------------
        
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #define ISDEPTHPASS

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            #define DEPTHNORMALPASS
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP VertexLit DepthNormals Pass.hlsl"

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

            #define _SPECULAR_SETUP 1

        //  First include all our custom stuff
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
        //  Include custom function
            #include "Includes/ATG URP VertexLit Meta Pass.hlsl"
        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    }

//  -----------------------------------------------------

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
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
            #define _SPECULAR_SETUP 1
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

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
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP VertexLit ForwardLit Pass.hlsl"
        
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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

        //  Include base inputs and all other needed "base" includes
            #define ISSHADOWPASS
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP VertexLit ShadowCaster Pass.hlsl"

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

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            #define DEPTHONLYPASS
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP VertexLit DepthOnly Pass.hlsl"
            
            ENDHLSL
        }

    //  DepthNormals -----------------------------------------------------
        
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling procedural:setup

            #define DEPTHNORMALPASS
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
            #include "Includes/ATG Instanced Indirect Inputs.hlsl"
        //  Include pass
            #include "Includes/ATG URP VertexLit DepthNormals Pass.hlsl"

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

            #define _SPECULAR_SETUP 1

        //  First include all our custom stuff
            #include "Includes/ATG URP VertexLit Inputs.hlsl"
        //  Include custom function
            #include "Includes/ATG URP VertexLit Meta Pass.hlsl"
        //  Finally include the meta pass related stuff  
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"

            ENDHLSL
        }

    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}