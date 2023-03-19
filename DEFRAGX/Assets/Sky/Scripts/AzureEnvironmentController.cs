using UnityEngine.Rendering;
using Fusion;
using UnityEngine;

namespace UnityEngine.AzureSky
{
    [ExecuteInEditMode]
    [AddComponentMenu("Azure[Sky]/Azure Environment Controller")]
    public class AzureEnvironmentController : Singleton<AzureEnvironmentController>
	{
        public ReflectionProbe reflectionProbe;
        public AzureReflectionProbeState state = AzureReflectionProbeState.Off;
        public ReflectionProbeRefreshMode refreshMode = ReflectionProbeRefreshMode.OnAwake;
        public ReflectionProbeTimeSlicingMode timeSlicingMode = ReflectionProbeTimeSlicingMode.NoTimeSlicing;
        public bool updateAtFirstFrame = true;
        public float refreshInterval = 2.0f;
        private float m_timeSinceLastProbeUpdate = 0;
        public float environmentIntensity = 1.0f;
        public Color environmentAmbientColor = Color.white;
        public Color environmentEquatorColor = Color.white;
        public Color environmentGroundColor = Color.white;
        
        private void Awake()
        {
            if (state != AzureReflectionProbeState.On)
                return;
            if (refreshMode == ReflectionProbeRefreshMode.ViaScripting && updateAtFirstFrame)
            {
                reflectionProbe.RenderProbe();
                //DynamicGI.UpdateEnvironment();
            }
        }
        
        private void Update()
        {
            // Not included in the build
            #if UNITY_EDITOR
            if (reflectionProbe)
            {
                reflectionProbe.mode = ReflectionProbeMode.Realtime;
                reflectionProbe.refreshMode = refreshMode;
                reflectionProbe.timeSlicingMode = timeSlicingMode;
            }
            #endif

            // Environment lighting
            RenderSettings.ambientIntensity = environmentIntensity;
            RenderSettings.ambientLight = environmentAmbientColor;
            RenderSettings.ambientSkyColor = environmentAmbientColor;
            RenderSettings.ambientEquatorColor = environmentEquatorColor;
            RenderSettings.ambientGroundColor = environmentGroundColor;

            if (!Application.isPlaying || state != AzureReflectionProbeState.On) return;
            
            if (refreshMode == ReflectionProbeRefreshMode.EveryFrame)
            {
                RPC_UpdateReflectionProbe();
                return;
            }

            if (refreshMode != ReflectionProbeRefreshMode.ViaScripting) return;
            
            m_timeSinceLastProbeUpdate += Time.deltaTime;

            if (!(m_timeSinceLastProbeUpdate >= refreshInterval)) return;

            RPC_UpdateReflectionProbe();
            
            m_timeSinceLastProbeUpdate = 0;
        }

        [Rpc(RpcSources.StateAuthority, RpcTargets.InputAuthority)]
        public void RPC_UpdateReflectionProbe()
        {
            if (HasStateAuthority)
            {
				reflectionProbe.RenderProbe();
				//DynamicGI.UpdateEnvironment();
			}
		}
    }
}