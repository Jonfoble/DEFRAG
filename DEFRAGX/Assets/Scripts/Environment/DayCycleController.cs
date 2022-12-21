using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DayCycleController : MonoBehaviour
{
    [Range(0, 24)]
    [SerializeField]private float timeOfDay;
    [SerializeField]private Light sun;
    [SerializeField]private Light moon;
    [SerializeField]private float orbitSpeed = 1.0f;
    private bool isNight;

    void Update()
    {
        timeOfDay += Time.deltaTime * orbitSpeed;
		if (timeOfDay > 24)
		{
            timeOfDay = 0;
		}
        UpdateTime();
    }


	private void OnValidate()
	{
        UpdateTime();
	}

	private void UpdateTime()
	{
        float alpha = timeOfDay / 24.0f;
        float sunRotation = Mathf.Lerp(-90, 270, alpha);
        float moonRotation = sunRotation - 180;

        sun.transform.rotation = Quaternion.Euler(sunRotation, -150.0f, 0);
		moon.transform.rotation = Quaternion.Euler(moonRotation, -150.0f, 0);

		CheckNightDayTransition();
	}
    private void CheckNightDayTransition()
	{
		if (isNight)
		{
			if (moon.transform.rotation.eulerAngles.x > 180)
			{
                StartDay();
			}
		}
		else
		{

			if (sun.transform.rotation.eulerAngles.x > 180)
			{
				StartNight();
			}
		}
	}

    private void StartDay()
	{

		isNight = false;
		sun.shadows = LightShadows.Soft;
		moon.shadows = LightShadows.None;
	}
    private void StartNight()
	{

		isNight = true;
		sun.shadows = LightShadows.None;
		moon.shadows = LightShadows.Soft;
	}


}
