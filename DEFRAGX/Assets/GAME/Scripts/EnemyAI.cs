using Fusion;
using Projectiles;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.AI;

public class EnemyAI : NetworkBehaviour ,ISpawned ,IDespawned
{
    public static EnemyAI LocalEnemy { get; set;}

    private NavMeshAgent Agent;
    private NetworkObject targetPlayer;
    private NetworkTransform nTransform;
    private NetworkTransform nTargetTransform;

    //Attacking
    [SerializeField] private float timeBetweenAttacks;
    private bool alreadyAttacked;

    //States
    [SerializeField] private float attackRange;
    private bool playerInAttackRange;
    public override void Spawned()
    {
        LocalEnemy = this;
        nTransform = gameObject.GetComponent<NetworkTransform>();
        Agent = gameObject.GetComponent<NavMeshAgent>();
        FindTargetOnSpawn();
    }

    private void Update()
    {
        if (!playerInAttackRange) ChasePlayer();
        if (playerInAttackRange) AttackPlayer();
        
    }
	private void ChasePlayer()
    {
		if (nTargetTransform != null)
        Agent.SetDestination(nTargetTransform.Transform.position);
    }
    private void AttackPlayer()
    {

        transform.LookAt(nTargetTransform.Transform.position);

        if (!alreadyAttacked)
        {
            ///Attack code here
            


            ///End of attack code

            alreadyAttacked = true;
            Invoke(nameof(ResetAttack), timeBetweenAttacks);
        }
    }
    private void ResetAttack()
    {
        alreadyAttacked = false;
    }
    private void FindTargetOnSpawn()
	{
        targetPlayer = FindTarget();
        nTargetTransform = targetPlayer.gameObject.GetComponent<NetworkTransform>();
	}
    private NetworkObject FindTarget()
	{
        List<GameObject> players = GameObject.FindGameObjectsWithTag("Player").ToList();
        NetworkObject target = players.GetRandom().GetComponent<NetworkObject>();
        return target;
	}
}
