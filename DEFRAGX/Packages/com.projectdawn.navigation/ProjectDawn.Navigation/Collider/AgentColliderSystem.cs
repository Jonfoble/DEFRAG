using Unity.Entities;
using Unity.Transforms;
using Unity.Mathematics;
using Unity.Collections;
using Unity.Collections.LowLevel.Unsafe;
using Unity.Jobs;
using Unity.Burst;
using Unity.Burst.Intrinsics;
using static Unity.Entities.SystemAPI;

namespace ProjectDawn.Navigation
{
    [BurstCompile]
    [RequireMatchingQueriesForUpdate]
    [UpdateInGroup(typeof(AgentSystemGroup))]
    [UpdateAfter(typeof(AgentTransformSystemGroup))]
    public partial struct AgentColliderSystem : ISystem
    {
        const int NumIterations = 4;
        const float ResolveFactor = 0.7f;

        SystemHandle m_SpatialPartitioningSystem;

        [BurstCompile]
        public void OnCreate(ref SystemState state)
        {
            m_SpatialPartitioningSystem = state.WorldUnmanaged.GetExistingUnmanagedSystem<AgentSpatialPartitioningSystem>();
        }

        public void OnDestroy(ref SystemState state) { }

        [BurstCompile]
        public void OnUpdate(ref SystemState state)
        {
            var spatial = GetSingletonRW<AgentSpatialPartitioningSystem.Singleton>();
            var world = state.WorldUnmanaged;
            ref var spatialSystem = ref world.GetUnsafeSystemRef<AgentSpatialPartitioningSystem>(m_SpatialPartitioningSystem);

            var job = new AgentColliderJob
            {
                Spatial = spatial.ValueRO,
                ResolveFactor = ResolveFactor,
            };

            for (int iteration = 0; iteration < NumIterations; ++iteration)
            {
                state.Dependency = spatialSystem.ScheduleUpdate(ref world.ResolveSystemStateRef(m_SpatialPartitioningSystem), state.Dependency);
                state.Dependency = job.ScheduleParallel(state.Dependency);
            }
        }
    }

    [BurstCompile]
    partial struct AgentColliderJob : IJobEntity
    {
        [ReadOnly]
        public AgentSpatialPartitioningSystem.Singleton Spatial;
        public float ResolveFactor;

        public void Execute(Entity entity, ref AgentBody body, ref LocalTransform transform, in AgentShape shape, in AgentCollider collider)
        {
            if (body.IsStopped)
                return;

            if (shape.Type == ShapeType.Cylinder)
            {
                var action = new CylindersCollision
                {
                    Entity = entity,
                    Body = body,
                    Shape = shape,
                    Transform = transform,
                    ResolveFactor = ResolveFactor,
                };

                Spatial.QueryCylinder(transform.Position, shape.Radius, shape.Height, ref action);

                if (action.Weight > 0)
                {
                    action.Displacement = action.Displacement / action.Weight;
                    transform.Position += action.Displacement;
                }
            }
            else
            {
                var action = new CirclesCollision
                {
                    Entity = entity,
                    Body = body,
                    Shape = shape,
                    Transform = transform,
                    ResolveFactor = ResolveFactor,
                };

                Spatial.QuerySphere(transform.Position, shape.Radius, ref action);

                if (action.Weight > 0)
                {
                    action.Displacement = action.Displacement / action.Weight;
                    transform.Position += new float3(action.Displacement, 0);
                }
            }
        }

        struct CirclesCollision : ISpatialQueryEntity
        {
            public Entity Entity;
            public AgentBody Body;
            public AgentShape Shape;
            public LocalTransform Transform;
            public float2 Displacement;
            public float Weight;
            public float ResolveFactor;

            public void Execute(Entity otherEntity, AgentBody otherBody, AgentShape otherShape, LocalTransform otherTransform)
            {
                if (otherShape.Type != ShapeType.Circle)
                    return;

                float2 towards = Transform.Position.xy - otherTransform.Position.xy;

                float distancesq = math.lengthsq(towards);
                float radiusSum = Shape.Radius + otherShape.Radius;
                if (distancesq > radiusSum * radiusSum || Entity == otherEntity)
                    return;

                float distance = math.sqrt(distancesq);
                float penetration = radiusSum - distance;

                if (distance < 0.0001f)
                {
                    // Avoid both having same displacement
                    if (otherEntity.Index > Entity.Index)
                    {
                        towards = -Body.Velocity.xy;
                    }
                    else
                    {
                        towards = Body.Velocity.xy;
                    }
                    penetration = 0.01f;
                }
                else
                {
                    penetration = (penetration / distance) * ResolveFactor;
                }

                Displacement += towards * penetration;
                Weight++;
            }
        }

        struct CylindersCollision : ISpatialQueryEntity
        {
            public Entity Entity;
            public AgentBody Body;
            public AgentShape Shape;
            public LocalTransform Transform;
            public float3 Displacement;
            public float Weight;
            public float ResolveFactor;

            public void Execute(Entity otherEntity, AgentBody otherBody, AgentShape otherShape, LocalTransform otherTransform)
            {
                if (otherShape.Type != ShapeType.Cylinder)
                    return;

                float extent = Shape.Height * 0.5f;
                float otherExtent = otherShape.Height * 0.5f;
                if (math.abs((Transform.Position.y + extent) - (otherTransform.Position.y + otherExtent)) > extent + otherExtent)
                    return;

                float2 towards = Transform.Position.xz - otherTransform.Position.xz;
                float distancesq = math.lengthsq(towards);
                float radius = Shape.Radius + otherShape.Radius;
                if (distancesq > radius * radius || Entity == otherEntity)
                    return;

                float distance = math.sqrt(distancesq);
                float penetration = radius - distance;

                if (distance < 0.0001f)
                {
                    // Avoid both having same displacement
                    if (otherEntity.Index > Entity.Index)
                    {
                        towards = -Body.Velocity.xz;
                    }
                    else
                    {
                        towards = Body.Velocity.xz;
                    }
                    penetration = 0.01f;
                }
                else
                {
                    penetration = (penetration / distance) * ResolveFactor;
                }

                Displacement += new float3(towards.x, 0, towards.y) * penetration;
                Weight++;
            }
        }
    }
}
