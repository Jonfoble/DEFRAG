
#if !defined(_VSPSETUP)

//	StructuredBuffers needed by IndirectInstancing
	#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
		StructuredBuffer<float4x4> GrassMatrixBuffer;
	#endif

//	Vertex to Fragment struct
	#if defined(ISGRASS)
		struct Input {
			#if defined(GRASSUSESTEXTUREARRAYS)
				float2 uv_MainTexArray;
			#else
				float2 uv_MainTex;
			#endif
			//float fade;
			float scale;
			float occ;
			float layer;
			fixed4 color; // : COLOR0;
		};
	#endif

//	Setup function for IndirectInstancing
	#if !defined(DONOTUSE_ATGSETUP)
		void setup() {
			#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
				float4x4 data = GrassMatrixBuffer[unity_InstanceID];
				unity_ObjectToWorld = data;

			//	Handle Floating Origin
				// randPivot does not work out properly when using compute and floating origin for some reason :( - so we use size instead.
				// float usesCompute = 1.0 - _AtgTerrainShiftSurface.w; // 1 if usesCompute, else 0
				// randPivot = float2(unity_ObjectToWorld[0].w + _AtgTerrainShiftSurface.x * usesCompute, unity_ObjectToWorld[2].w + _AtgTerrainShiftSurface.z * usesCompute);
				
				float3 shift = _AtgTerrainShiftSurface.xyz * _AtgTerrainShiftSurface.w; // w = 0 when compute / 1 when no compute
				unity_ObjectToWorld[0].w -= shift.x;
				unity_ObjectToWorld[1].w -= shift.y;
				unity_ObjectToWorld[2].w -= shift.z;

			//	Restore matrix as it could contain layer data here!
				InstanceScale = frac(unity_ObjectToWorld[3].w);
				TextureLayer = unity_ObjectToWorld[3].w - InstanceScale;
				InstanceScale *= 100.0f;
				#if defined(_NORMAL)
					terrainNormal = unity_ObjectToWorld[3].xyz;
				#endif
				unity_ObjectToWorld[3] = float4(0, 0, 0, 1.0f);

			//	Bullshit!
			//	unity_WorldToObject = unity_ObjectToWorld;
			//	unity_WorldToObject._14_24_34 *= -1;
			//	unity_WorldToObject._11_22_33 = 1.0f / unity_WorldToObject._11_22_33;
			
			// 	Not correct but good enough to get the wind direction in object space
				unity_WorldToObject = unity_ObjectToWorld;
				unity_WorldToObject._14_24_34 = 1.0f / unity_WorldToObject._14_24_34;
				unity_WorldToObject._11_22_33 *= -1;
			//	Seems to be rather cheap - on: 34 / off 36fps
				//unity_WorldToObject = inverseMat(unity_ObjectToWorld); //inverspositionBuffer[unity_InstanceID];
			#endif
		}
	#endif

//	VSP Code

#else


	//	Vertex to Fragment struct
	#if defined(ISGRASS)
		struct Input {
			#if defined(GRASSUSESTEXTUREARRAYS)
				float2 uv_MainTexArray;
			#else
				float2 uv_MainTex;
			#endif
			//float fade;
			float scale;
			float occ;
			float layer;
			fixed4 color; // : COLOR0;
		};
	#endif

// ControlData = float4(lodFade, lodFadeQuantified, instanceData.ControlData.z, 3);

	#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
		struct IndirectShaderData
		{
			float4x4 PositionMatrix;
			float4x4 InversePositionMatrix;
			float4 ControlData;
		};
		#if defined(SHADER_API_GLCORE) || defined(SHADER_API_D3D11) || defined(SHADER_API_GLES3) || defined(SHADER_API_METAL) || defined(SHADER_API_VULKAN) || defined(SHADER_API_PSSL) || defined(SHADER_API_XBOXONE)
			uniform StructuredBuffer<IndirectShaderData> VisibleShaderDataBuffer;
		#endif
	#endif
	void setup()
	{
	#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED


InstanceScale = 0; // We grab it later!
TextureLayer = 0;
ControlData = VisibleShaderDataBuffer[unity_InstanceID].ControlData;

unity_LODFade.xy = ControlData.xy;


		#ifdef unity_ObjectToWorld
			#undef unity_ObjectToWorld
		#endif
		#ifdef unity_WorldToObject
			#undef unity_WorldToObject
		#endif
		unity_ObjectToWorld = VisibleShaderDataBuffer[unity_InstanceID].PositionMatrix;
		unity_WorldToObject = VisibleShaderDataBuffer[unity_InstanceID].InversePositionMatrix;
		// Min VSP strange scaling at slopes! So taking y is best here.
		// InstanceScale = rcp(_VSPScaleMultiplier) * length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y));
	#endif
	}


#endif
