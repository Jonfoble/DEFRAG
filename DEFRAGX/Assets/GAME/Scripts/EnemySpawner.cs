using Fusion;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.AzureSky;

public class EnemySpawner : Singleton<EnemySpawner>, ISpawned, IDespawned
{
	[SerializeField] private List<NetworkPrefabRef> Enemies;
	private int currentWave;
	private void OnEnable()
	{
		FogInstantiator.Instance.OnFogWeather += SpawnEnemies;
		FogInstantiator.Instance.OnFogWeather += GetWaveNumber;
		FogInstantiator.Instance.OnDefaultWeather += StopSpawningEnemies;
		
	}
	private void OnDisable()
	{
		FogInstantiator.Instance.OnFogWeather -= SpawnEnemies;
		FogInstantiator.Instance.OnFogWeather -= GetWaveNumber;
		FogInstantiator.Instance.OnDefaultWeather -= StopSpawningEnemies;
		
	}
	private void GetWaveNumber() //Get Wave Number According to the Day of the month
	{
		currentWave = AzureTimeController.Instance.GetDay();
		Debug.Log("Current Wave: " + currentWave);
	}
	private void SpawnEnemies()//Start Enemy Spawn Coroutine
	{
		StartCoroutine(SpawnEnemiesRoutine());

	}
	private Vector3 GetRandomSpawnPoint()//Get a Random spawn Around The Player
	{
		Vector3 randomSpawnPoint = new Vector3(Random.Range(10f, 20f), Random.Range(35f, 40f), Random.Range(-190f, 300f));
		return randomSpawnPoint;
	}
	private void StopSpawningEnemies()//Despawn all enemies on sunrise.
	{
		foreach (var enemy in FindObjectsOfType<EnemyAI>())
		{
			Runner.Despawn(enemy.GetComponent<NetworkObject>());
		}
	}
	private IEnumerator SpawnEnemiesRoutine()
	{
		yield return new WaitForSeconds(25);
		for (int i = 0; i < currentWave * 2; i++)
		{
			NetworkObject spawnedEnemy = Runner.Spawn(Enemies[0], GetRandomSpawnPoint(), Quaternion.identity);
			Debug.Log("Enemy Spawned");
		}
	}
}
