using Fusion;
using UnityEngine;
using UnityEngine.AzureSky;
using UnityEngine.Events;

public class FogInstantiator : Singleton<FogInstantiator>
{
	[SerializeField] private AzureWeatherProfile fogWeather;
	[SerializeField] private AzureWeatherProfile defaultWeather;
	[SerializeField] private Vector2 timeToFog = new Vector2(20f, 0f);
	[SerializeField] private Vector2 timeToEraseFog = new Vector2(7f, 0f);
	public UnityAction OnFogWeather;
	public UnityAction OnDefaultWeather;

	private Vector2 timeOfDay;

	private void Update()
	{
		timeOfDay = AzureTimeController.Instance.GetTimeOfDay();
		if (HasStateAuthority)
		{
			RPC_InvokeFogState();
		}
	}

	[Rpc(RpcSources.StateAuthority, RpcTargets.All)]
	private void RPC_InvokeFogState()
	{
		if (timeOfDay == timeToFog)
		{
			RPC_InitiateFog();
		}
		else if (timeOfDay == timeToEraseFog)
		{
			RPC_EraseFog();
		}
	}
	[Rpc(RpcSources.StateAuthority, RpcTargets.All)]
	private void RPC_InitiateFog()
	{
		AzureWeatherController.Instance.SetNewWeatherProfile(fogWeather, 25f);
		OnFogWeather?.Invoke();
	}
	[Rpc(RpcSources.StateAuthority, RpcTargets.All)]
	private void RPC_EraseFog()
	{
		AzureWeatherController.Instance.SetNewWeatherProfile(defaultWeather, 25f);
		OnDefaultWeather?.Invoke();
	}
}
