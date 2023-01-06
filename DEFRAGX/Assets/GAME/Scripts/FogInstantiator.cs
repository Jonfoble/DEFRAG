using Fusion;
using UnityEngine;
using UnityEngine.AzureSky;
using UnityEngine.Events;

public class FogInstantiator : Singleton<FogInstantiator>
{
	public UnityAction OnFogWeather;
	public UnityAction OnDefaultWeather;
	[SerializeField] private AzureWeatherProfile fogWeather;
	[SerializeField] private Vector2 timeToFog = new Vector2(20f, 0f);
	[SerializeField] private Vector2 timeToEraseFog = new Vector2(6f, 0f);
	private Vector2 timeOfDay;
	private void Update()
	{
		timeOfDay = AzureTimeController.Instance.GetTimeOfDay();
		if (timeOfDay == timeToFog)
		{
			InitiateFog(fogWeather);
		}
		else if (timeOfDay == timeToEraseFog)
		{
			EraseFog(AzureWeatherController.Instance.GetDefaultWeatherProfile());
		}
	}
	public void InitiateFog(AzureWeatherProfile weatherProfile)
	{
		AzureWeatherController.Instance.SetNewWeatherProfile(weatherProfile, 25f);
		OnFogWeather?.Invoke();
	}
	public void EraseFog(AzureWeatherProfile weatherProfile)
	{
		AzureWeatherController.Instance.SetNewWeatherProfile(weatherProfile, 25f);
		OnDefaultWeather?.Invoke();
	}
}
