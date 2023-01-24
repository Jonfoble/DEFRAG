using Unity.Entities;
using Unity.Transforms;
using Unity.Collections;
using Unity.Burst;
using UnityEngine.Experimental.AI;
using static Unity.Entities.SystemAPI;

namespace ProjectDawn.Navigation
{
    /// <summary>
    /// System that forces agents to stay within NavMesh surface.
    /// </summary>
    [BurstCompile]
    [RequireMatchingQueriesForUpdate]
    [UpdateInGroup(typeof(AgentSystemGroup))]
    [UpdateAfter(typeof(AgentTransformSystemGroup))]
    [UpdateAfter(typeof(AgentColliderSystem))]
    public partial struct NavMeshPositionSystem : ISystem
    {
        public void OnCreate(ref SystemState state) { }

        public void OnDestroy(ref SystemState state) { }

        [BurstCompile]
        public void OnUpdate(ref SystemState state)
        {
            var navmesh = GetSingleton<NavMeshQuerySystem.Singleton>();
            new NavMeshPositionJob
            {
                NavMesh = navmesh
            }.ScheduleParallel();
            navmesh.World.AddDependency(state.Dependency);
        }

        [BurstCompile]
        partial struct NavMeshPositionJob : IJobEntity
        {
            [ReadOnly]
            public NavMeshQuerySystem.Singleton NavMesh;

            public void Execute(ref DynamicBuffer<NavMeshNode> nodes, ref NavMeshPath path, ref LocalTransform transform)
            {
                var location = path.Location;

                // Early out if location is not valid
                if (location.polygon.IsNull())
                    return;

                var newLocation = NavMesh.MoveLocation(location, transform.Position, path.AreaMask);

                ProgressPath(ref nodes, location.polygon, newLocation.polygon);

                transform.Position = newLocation.position;
                path.Location = newLocation;
            }

            static void ProgressPath(ref DynamicBuffer<NavMeshNode> nodes, PolygonId previousPolygon, PolygonId newPolygon)
            {
                if (FindIndex(ref nodes, newPolygon, out int index))
                {
                    if (nodes.Length > 1)
                    {
                        for (int i = 0; i < index; ++i)
                        {
                            nodes.RemoveAt(0);
                        }
                    }
                }
                else
                {
                    if (FindIndex(ref nodes, previousPolygon, out int index2))
                    {
                        if (nodes.Length > 1)
                        {
                            for (int i = 0; i < index2 + 1; ++i)
                            {
                                nodes.RemoveAt(0);
                            }
                        }
                    }
                    if (previousPolygon != newPolygon)
                    {
                        nodes.Insert(0, new NavMeshNode { Value = newPolygon });
                    }
                }
            }

            static bool FindIndex(ref DynamicBuffer<NavMeshNode> nodes, PolygonId newPolygon, out int index)
            {
                for (int i = 0; i < nodes.Length; ++i)
                {
                    if (nodes[i].Value == newPolygon)
                    {
                        index = i;
                        return true;
                    }
                }
                index = -1;
                return false;
            }
        }
    }
}
