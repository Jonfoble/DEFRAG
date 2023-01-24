using Unity.Entities;
using Unity.Transforms;
using Unity.Mathematics;
using Unity.Collections;
using Unity.Jobs;
using Unity.Burst;
using static Unity.Entities.SystemAPI;
using static Unity.Mathematics.math;

namespace ProjectDawn.Navigation
{
    /// <summary>
    /// Partitions agents into arbitary size cells. This allows to query nearby agents more efficiently.
    /// Space is partitioned using multi hash map.
    /// </summary>
    [BurstCompile]
    [RequireMatchingQueriesForUpdate]
    [UpdateBefore(typeof(AgentForceSystemGroup))]
    [UpdateInGroup(typeof(AgentSystemGroup))]
    public partial struct AgentSpatialPartitioningSystem : ISystem
    {
        const int InitialCapacity = 2000;

        NativeMultiHashMap<int, int> m_Map;
        NativeList<Entity> m_Entities;
        NativeList<AgentBody> m_Bodies;
        NativeList<AgentShape> m_Shapes;
        NativeList<LocalTransform> m_Transforms;
        int m_Capacity;
        float3 m_CellSize;

        internal JobHandle ScheduleUpdate(ref SystemState state, JobHandle dependency)
        {
            dependency = new ClearJob
            {
                Entities = m_Entities,
                Bodies = m_Bodies,
                Shapes = m_Shapes,
                Transforms = m_Transforms,
                Map = m_Map,
            }.Schedule(dependency);

            var copyHandle = new CopyJob
            {
                Entities = m_Entities,
                Bodies = m_Bodies,
                Shapes = m_Shapes,
                Transforms = m_Transforms,
            }.Schedule(dependency);

            var hashHandle = new HashJob
            {
                Map = m_Map.AsParallelWriter(),
                CellSize = m_CellSize,
            }.Schedule(dependency);

            return JobHandle.CombineDependencies(copyHandle, hashHandle);
        }

        [BurstCompile]
        public void OnUpdate(ref SystemState state)
        {
            var singleton = GetSingletonRW<Singleton>();
            if (TryGetSingleton(out Settings settings))
            {
                singleton.ValueRW.m_CellSize = settings.CellSize;
                m_CellSize = settings.CellSize;

                if (singleton.ValueRW.m_Capacity != settings.AgentCapacity)
                {
                    state.Dependency = new ChangeCapacityJob
                    {
                        Map = m_Map,
                        Entities = m_Entities,
                        Bodies = m_Bodies,
                        Shapes = m_Shapes,
                        Transforms = m_Transforms,
                        Capacity = settings.AgentCapacity,
                    }.Schedule(state.Dependency);
                    singleton.ValueRW.m_Capacity = settings.AgentCapacity;
                }
            }
            
            state.Dependency = ScheduleUpdate(ref state, state.Dependency);
        }

        [BurstCompile]
        public void OnCreate(ref SystemState state)
        {
            m_Map = new NativeMultiHashMap<int, int>(InitialCapacity, Allocator.Persistent);
            m_Entities = new NativeList<Entity>(InitialCapacity, Allocator.Persistent);
            m_Bodies = new NativeList<AgentBody>(InitialCapacity, Allocator.Persistent);
            m_Shapes = new NativeList<AgentShape>(InitialCapacity, Allocator.Persistent);
            m_Transforms = new NativeList<LocalTransform>(InitialCapacity, Allocator.Persistent);

            m_Capacity = 2000;
            m_CellSize = 3;

            state.EntityManager.AddComponentData(state.SystemHandle, new Singleton
            {
                m_Map = m_Map,
                m_Entities = m_Entities,
                m_Bodies = m_Bodies,
                m_Shapes = m_Shapes,
                m_Transforms = m_Transforms,
                m_Capacity = m_Capacity,
                m_CellSize = m_CellSize,
            });
        }

        [BurstCompile]
        public void OnDestroy(ref SystemState systemState)
        {
            m_Map.Dispose();
            m_Entities.Dispose();
            m_Bodies.Dispose();
            m_Shapes.Dispose();
            m_Transforms.Dispose();
        }

        public struct Settings : IComponentData
        {
            public int AgentCapacity;
            public float3 CellSize;
        }

        public struct Singleton : IComponentData
        {
            internal NativeMultiHashMap<int, int> m_Map;
            internal NativeList<Entity> m_Entities;
            internal NativeList<AgentBody> m_Bodies;
            internal NativeList<AgentShape> m_Shapes;
            internal NativeList<LocalTransform> m_Transforms;
            internal int m_Capacity;
            internal float3 m_CellSize;

            /// <summary>
            /// Query agents that intersect with the line.
            /// </summary>
            public int QueryLine<T>(float3 from, float3 to, ref T action) where T : unmanaged, ISpatialQueryEntity
            {
                int count = 0;

                // Based on http://www.cse.yorku.ca/~amana/research/grid.pdf

                // Convert to unit voxel size
                from = from / m_CellSize;
                to = to / m_CellSize;

                // Convert to parametric line form: u + v * t, t >= 0
                float3 u = from;
                float3 v = to - from;

                // Find start and end voxel coordinates
                int3 point = (int3) round(from);
                int3 end = (int3) round(to);

                // Initialized to either 1 or - 1 indicating whether X and Y are incremented or decremented as the
                // ray crosses voxel boundaries(this is determined by the sign of the x and y components of → v).
                int3 step = (int3) sign(v);

                float3 boundaryDistance = select(-0.5f, 0.5f, step == 1);

                // Here we find distance to closest voxel boundary on each axis
                // Formula is actually quite simple we just equate parametric line to cloest voxel boundary
                // u + v * t = start + boundaryDistance, step = 1
                // u + v * t = start - boundaryDistance, step = -1
                float3 tMax = select((point + boundaryDistance - u) / v, float.MaxValue, step == 0);

                // TDelta indicates how far along the ray we must move
                // (in units of t) for the horizontal component of such a movement to equal the width of a voxel.
                // Similarly, we store in tDeltaY the amount of movement along the ray which has a vertical component equal to the height of a voxel.
                float3 tDelta = select(abs(1f / v), float.MaxValue, step == 0);

                // Loop through each voxel
                for (int i = 0; i < 100; ++i)
                {
                    int hash = GetCellHash(point.x, point.y, point.z);

                    // Find all entities in the bucket
                    if (m_Map.TryGetFirstValue(hash, out int index, out var iterator))
                    {
                        do
                        {
                            action.Execute(m_Entities[index], m_Bodies[index], m_Shapes[index], m_Transforms[index]);
                            count++;
                        }
                        while (m_Map.TryGetNextValue(out index, ref iterator));
                    }

                    // Stop if reached the end voxel
                    if (all(point == end))
                        break;

                    // Progress line towards the voxel that will be reached fastest
                    if (tMax.x < tMax.y)
                    {
                        if (tMax.x < tMax.z)
                        {
                            tMax.x = tMax.x + tDelta.x;
                            point.x = point.x + step.x;
                        }
                        else
                        {
                            tMax.z = tMax.z + tDelta.z;
                            point.z = point.z + step.z;
                        }
                    }
                    else
                    {
                        if (tMax.y < tMax.z)
                        {
                            tMax.y = tMax.y + tDelta.y;
                            point.y = point.y + step.y;
                        }
                        else
                        {
                            tMax.z = tMax.z + tDelta.z;
                            point.z = point.z + step.z;
                        }
                    }
                }

                return count;
            }

            /// <summary>
            /// Query agents that intersect with the sphere.
            /// </summary>
            public int QuerySphere<T>(float3 center, float radius, ref T action) where T : unmanaged, ISpatialQueryEntity
            {
                int count = 0;

                // Find min and max point in radius
                int3 min = (int3) math.round((center - radius) / m_CellSize);
                int3 max = (int3) math.round((center + radius) / m_CellSize);

                max++;

                for (int i = min.x; i < max.x; ++i)
                {
                    for (int j = min.y; j < max.y; ++j)
                    {
                        for (int k = min.z; k < max.z; ++k)
                        {
                            int hash = GetCellHash(i, j, k);

                            // Find all entities in the bucket
                            if (m_Map.TryGetFirstValue(hash, out int index, out var iterator))
                            {
                                do
                                {
                                    action.Execute(m_Entities[index], m_Bodies[index], m_Shapes[index], m_Transforms[index]);
                                    count++;
                                }
                                while (m_Map.TryGetNextValue(out index, ref iterator));
                            }
                        }
                    }
                }

                return count;
            }

            /// <summary>
            /// Query agents that intersect with the cylinder.
            /// </summary>
            public int QueryCylinder<T>(float3 center, float radius, float height, ref T action) where T : unmanaged, ISpatialQueryEntity
            {
                int count = 0;

                // Find min and max point in radius
                int3 min = (int3) math.round((center - new float3(radius, 0, radius)) / m_CellSize);
                int3 max = (int3) math.round((center + new float3(radius, height, radius)) / m_CellSize);

                max++;

                for (int i = min.x; i < max.x; ++i)
                {
                    for (int j = min.y; j < max.y; ++j)
                    {
                        for (int k = min.z; k < max.z; ++k)
                        {
                            int hash = GetCellHash(i, j, k);

                            // Find all entities in the bucket
                            if (m_Map.TryGetFirstValue(hash, out int index, out var iterator))
                            {
                                do
                                {
                                    action.Execute(m_Entities[index], m_Bodies[index], m_Shapes[index], m_Transforms[index]);
                                    count++;
                                }
                                while (m_Map.TryGetNextValue(out index, ref iterator));
                            }
                        }
                    }
                }

                return count;
            }

            /// <summary>
            /// Query partitions that intersect with the sphere.
            /// </summary>
            public int QuerySphereBoxes<T>(float3 center, float radius, T action) where T : unmanaged, ISpatialQueryVolume
            {
                int count = 0;

                // Find min and max point in radius
                int3 min = (int3) math.round((center - radius) / m_CellSize);
                int3 max = (int3) math.round((center + radius) / m_CellSize);

                max++;

                for (int i = min.x; i < max.x; ++i)
                {
                    for (int j = min.y; j < max.y; ++j)
                    {
                        for (int k = min.z; k < max.z; ++k)
                        {
                            action.Execute(new float3(i, j, k) * m_CellSize, m_CellSize);
                            count++;
                        }
                    }
                }

                return count;
            }

            /// <summary>
            /// Query partitions that intersect with the cylinder.
            /// </summary>
            public int QueryCylindreBoxes<T>(float3 center, float radius, float height, T action) where T : unmanaged, ISpatialQueryVolume
            {
                int count = 0;

                // Find min and max point in radius
                int3 min = (int3) math.round((center - new float3(radius, 0, radius)) / m_CellSize);
                int3 max = (int3) math.round((center + new float3(radius, height, radius)) / m_CellSize);

                max++;

                for (int i = min.x; i < max.x; ++i)
                {
                    for (int j = min.y; j < max.y; ++j)
                    {
                        for (int k = min.z; k < max.z; ++k)
                        {
                            action.Execute(new float3(i, j, k) * m_CellSize, m_CellSize);
                            count++;
                        }
                    }
                }

                return count;
            }

            static int GetCellHash(int x, int y, int z)
            {
                var hash = (int) math.hash(new int3(x, y, z));
                return hash;
            }
        }
    }

    public interface ISpatialQueryEntity
    {
        void Execute(Entity entity, AgentBody body, AgentShape shape, LocalTransform transform);
    }

    public interface ISpatialQueryVolume
    {
        void Execute(float3 position, float3 size);
    }

    [BurstCompile]
    partial struct CopyJob : IJobEntity
    {
        public NativeList<Entity> Entities;
        public NativeList<AgentBody> Bodies;
        public NativeList<AgentShape> Shapes;
        public NativeList<LocalTransform> Transforms;

        void Execute(Entity entity, in AgentBody body, in AgentShape shape, in LocalTransform transform)
        {
            Entities.Add(entity);
            Bodies.Add(body);
            Shapes.Add(shape);
            Transforms.Add(transform);
        }
    }

    [BurstCompile]
    partial struct HashJob : IJobEntity
    {
        public NativeMultiHashMap<int, int>.ParallelWriter Map;
        public float3 CellSize;
        void Execute([EntityIndexInQuery] int entityInQueryIndex, in Agent agent, in LocalTransform transform)
        {
            var hash = GetCellHash(transform.Position);
            Map.Add(hash, entityInQueryIndex);
        }

        int GetCellHash(float3 value)
        {
            var hash = (int) math.hash(new int3(math.round(value.xyz / CellSize)));
            return hash;
        }
    }

    [BurstCompile]
    struct ClearJob : IJob
    {
        public NativeMultiHashMap<int, int> Map;
        public NativeList<Entity> Entities;
        public NativeList<AgentBody> Bodies;
        public NativeList<AgentShape> Shapes;
        public NativeList<LocalTransform> Transforms;

        public void Execute()
        {
            Map.Clear();
            Entities.Clear();
            Bodies.Clear();
            Shapes.Clear();
            Transforms.Clear();
        }
    }

    [BurstCompile]
    struct ChangeCapacityJob : IJob
    {
        public NativeMultiHashMap<int, int> Map;
        public NativeList<Entity> Entities;
        public NativeList<AgentBody> Bodies;
        public NativeList<AgentShape> Shapes;
        public NativeList<LocalTransform> Transforms;
        public int Capacity;

        public void Execute()
        {
            Map.Capacity = Capacity;
            Entities.Capacity = Capacity;
            Bodies.Capacity = Capacity;
            Shapes.Capacity = Capacity;
            Transforms.Capacity = Capacity;
        }
    }
}
