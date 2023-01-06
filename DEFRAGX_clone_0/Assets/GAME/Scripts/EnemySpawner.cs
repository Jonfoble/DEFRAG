using Fusion;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Events;

public class EnemySpawner : Singleton<EnemySpawner>, ISpawned, IDespawned
{
	[SerializeField] private List<NetworkPrefabRef> Enemies;
	private List<NetworkObject> spawnedEnemies;
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
	public void SpawnEnemies()
	{
		NetworkObject spawnedEnemy = Runner.Spawn(Enemies[0], new Vector3(20.459f, 30.971f, 190.49f), Quaternion.identity);
		spawnedEnemies.Append(spawnedEnemy);
	}
	private void StopSpawningEnemies()
	{
		foreach (var enemy in spawnedEnemies)
		{
			Runner.Despawn(enemy);
		}
	}
}
