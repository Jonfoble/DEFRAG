using Unity.Entities;
using Unity.Mathematics;
using Unity.Collections;
using Unity.Burst;
using UnityEngine.Experimental.AI;
using static Unity.Entities.SystemAPI;
using UnityEditor.AI;

namespace ProjectDawn.Navigation
{
    [BurstCompile]
    [RequireMatchingQueriesForUpdate]
    public partial struct NavMeshGizmosSystem : ISystem
    {
        public void OnCreate(ref SystemState state) { }

        public void OnDestroy(ref SystemState state) { }

        [BurstCompile]
        public void OnUpdate(ref SystemState state)
        {
            var navmesh = GetSingleton<NavMeshQuerySystem.Singleton>();
            var gizmos = GetSingletonRW<GizmosSystem.Singleton>();
            new Job
            {
                Navmesh = navmesh,
                Gizmos = gizmos.ValueRW.CreateCommandBuffer().AsParallelWriter(),
            }.ScheduleParallel();
            navmesh.World.AddDependency(state.Dependency);
        }

        [BurstCompile]
        partial struct Job : IJobEntity
        {
            [ReadOnly]
            public NavMeshQuerySystem.Singleton Navmesh;
            public GizmosCommandBuffer.ParallelWriter Gizmos;

            public void Execute(Entity entity, in DrawGizmos drawGizmos, in NavMeshPath path, in DynamicBuffer<NavMeshNode> nodes)
            {
                if (path.State != NavMeshPathState.Finished)
                    return;

                var polygons = nodes.AsNativeArray().Reinterpret<PolygonId>();

                if (!Navmesh.IsPathValid(polygons))
                    return;

                NativeArray<float3> vertices = new NativeArray<float3>(24, Allocator.Temp);
                NativeArray<PolygonId> neighbours = new NativeArray<PolygonId>(24, Allocator.Temp);
                NativeArray<byte> indices = new NativeArray<byte>(24, Allocator.Temp);
                for (int i = 0; i < polygons.Length; ++i)
                {
                    if (Navmesh.GetEdgesAndNeighbors(polygons[i], vertices.Reinterpret<UnityEngine.Vector3>(), neighbours, indices, out int numVertices, out int numNeighbours))
                    {
                        var progress = polygons.Length > 1 ? (float) i / (polygons.Length - 1) : 1;
                        var color = UnityEngine.Color.Lerp(new UnityEngine.Color(1, 0, 0, 0.3f), new UnityEngine.Color(0, 1, 0, 0.3f), progress);
                        Gizmos.DrawAAConvexPolygon(vertices.GetSubArray(0, numVertices), color);
                    }
                }
                vertices.Dispose();
                neighbours.Dispose();
                indices.Dispose();
            }
        }
    }
}
