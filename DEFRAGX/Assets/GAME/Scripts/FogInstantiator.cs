using Fusion;
using UnityEngine;
using UnityEngine.AzureSky;
using UnityEngine.Events;

public class FogInstantiator : SimulationSingleton<FogInstantiator>
{
	[SerializeField] private AzureWeatherProfile fogWeather;
	[SerializeField] private AzureWeatherProfile defaultWeather;
	[SerializeField] private Vector2 timeToFog = new Vector2(20f, 0f);
	[SerializeField] private Vector2 timeToEraseFog = new Vector2(7f, 0f);
	public UnityAction OnFogWeather;
	public UnityAction OnDefaultWeather;
	
	private void OnEnable()
	{
		if (Runner.IsServer)
			AzureTimeController.Instance.OnTimeTick += InvokeFogState;
	}
	private void OnDisable()
	{
		if (Runner.IsServer)
			AzureTimeController.Instance.OnTimeTick -= InvokeFogState;
		
	}
	private void InvokeFogState(Vector2 timeOfDay)
	{
		Debug.Log(timeOfDay);
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
