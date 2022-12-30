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
	void InitiateFog(AzureWeatherProfile weatherProfile)
	{
		OnFogWeather?.Invoke();
		AzureWeatherController.Instance.SetNewWeatherProfile(weatherProfile, 20f);
	}
	void EraseFog(AzureWeatherProfile weatherProfile)
	{
		OnDefaultWeather?.Invoke();
		AzureWeatherController.Instance.SetNewWeatherProfile(weatherProfile, 20f);
	}
}
