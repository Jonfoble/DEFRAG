using Fusion;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class EnemySpawner : Singleton<EnemySpawner>, ISpawned, IDespawned
{
	[SerializeField] private List<NetworkPrefabRef> Enemies;
	private List<NetworkObject> spawnedEnemies;
	private int currentWave = 1;
	private void OnEnable()
	{
		FogInstantiator.Instance.OnFogWeather += SpawnEnemies;
		FogInstantiator.Instance.OnDefaultWeather += StopSpawningEnemies;
	}
	private void OnDisable()
	{
		FogInstantiator.Instance.OnFogWeather -= SpawnEnemies;
		FogInstantiator.Instance.OnDefaultWeather -= StopSpawningEnemies;
	}
	private void SpawnEnemies()
	{
		for (int i = 0; i < currentWave * 5; i++)
		{
			NetworkObject spawnedEnemy = Runner.Spawn(Enemies[0], GetRandomSpawnPoint(), Quaternion.identity);
		}
	}
	private void StopSpawningEnemies()
	{
		foreach (var enemy in FindObjectsOfType<EnemyAI>())
		{
			Runner.Despawn(enemy.GetComponent<NetworkObject>());
		}
	}
	private Vector3 GetRandomSpawnPoint()
	{
		Vector3 randomSpawnPoint = new Vector3(Random.Range(10f, 20f), Random.Range(35f, 40f), Random.Range(-190f, 300f));
		return randomSpawnPoint;
	}

}
