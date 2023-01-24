using Unity.Entities;
using Unity.Transforms;
using Unity.Mathematics;
using Unity.Collections;
using Unity.Jobs;
using Unity.Burst;
using UnityEngine;
using static Unity.Entities.SystemAPI;
using ProjectDawn.LocalAvoidance;

namespace ProjectDawn.Navigation
{
    [BurstCompile]
    [RequireMatchingQueriesForUpdate]
    public partial struct AgentAvoidGizmosSystem : ISystem
    {
        public void OnCreate(ref SystemState state) { }

        public void OnDestroy(ref SystemState state) { }

        [BurstCompile]
        public void OnUpdate(ref SystemState state)
        {
            var spatial = GetSingleton<AgentSpatialPartitioningSystem.Singleton>();
            var gizmos = GetSingletonRW<GizmosSystem.Singleton>();
            new AgentAvoidJob
            {
                Gizmos = gizmos.ValueRW.CreateCommandBuffer().AsParallelWriter(),
                Spatial = spatial,
            }.ScheduleParallel();
        }

        [BurstCompile]
        unsafe partial struct AgentAvoidJob : IJobEntity
        {
            [ReadOnly]
            public AgentSpatialPartitioningSystem.Singleton Spatial;
            public GizmosCommandBuffer.ParallelWriter Gizmos;

            public void Execute(Entity entity, in AgentBody body, in AgentShape shape, in AgentSonarAvoid avoid, in LocalTransform transform, in DrawGizmos drawGizmos)
            {
                if (body.IsStopped)
                    return;

                if (math.length(body.Force) < 1e-3f)
                    return;

                var sonar = new SonarAvoidance(Allocator.Temp);

                float3 desiredDirection = body.Force;

                // Sonar should not extend pass the destination
                var sonarRadius = math.min(avoid.Radius, math.distance(body.Destination, transform.Position));

                // Recreate avoidance structure
                sonar.Set(transform.Position, desiredDirection, shape.GetUp(), shape.Radius, sonarRadius, math.length(body.Velocity));

                // Add nearby agents as obstacles
                var action = new Action
                {
                    DrawCircle = new DrawCircle { Gizmos = Gizmos },
                    Sonar = sonar,
                    Entity = entity,
                    Body = body,
                    Shape = shape,
                    Avoid = avoid,
                    Transform = transform,
                    DesiredDirection = desiredDirection,
                };
                if (shape.Type == ShapeType.Cylinder)
                {
                    Spatial.QueryCylinder(transform.Position, avoid.Radius, shape.Height, ref action);
                }
                else
                {
                    Spatial.QuerySphere(transform.Position, avoid.Radius, ref action);
                }

                // Add blocker behind the velocity
                // This will prevent situations where agent has on right and left equally good paths
                if (math.length(body.Velocity) > 1e-3f)
                    sonar.InsertObstacle(math.normalizesafe(-body.Velocity), avoid.Angle);

                sonar.DrawSonar(new DrawArc
                {
                    Gizmos = Gizmos,
                    InnerRadius = sonar.InnerRadius,
                    OuterRadius = sonar.OuterRadius,
                });

                sonar.Dispose();
            }

            struct Action : ISpatialQueryEntity
            {
                public DrawCircle DrawCircle;

                public SonarAvoidance Sonar;
                public Entity Entity;
                public AgentBody Body;
                public AgentShape Shape;
                public AgentSonarAvoid Avoid;
                public LocalTransform Transform;
                public float3 DesiredDirection;

                public void Execute(Entity otherEntity, AgentBody otherBody, AgentShape otherShape, LocalTransform otherTransform)
                {
                    // Skip itself
                    if (Entity == otherEntity)
                        return;

                    if (Avoid.Mode == SonarAvoidMode.IgnoreBehindAgents)
                    {
                        if (math.dot(DesiredDirection, math.normalizesafe(otherTransform.Position - Transform.Position)) < 0 && math.length(otherBody.Velocity) > 0)
                            return;
                    }

                    if (Shape.Type == ShapeType.Cylinder && otherShape.Type == ShapeType.Cylinder)
                    {
                        float extent = Shape.Height * 0.5f;
                        float otherExtent = otherShape.Height * 0.5f;
                        if (math.abs((Transform.Position.y + extent) - (otherTransform.Position.y + otherExtent)) > extent + otherExtent)
                            return;
                    }

                    Sonar.InsertObstacle(otherTransform.Position, otherBody.Velocity, otherShape.Radius);

                    Sonar.DrawObstacle(DrawCircle, otherTransform.Position, otherBody.Velocity, otherShape.Radius);
                }
            }

            struct DrawArc : SonarAvoidance.IDrawArc
            {
                public GizmosCommandBuffer.ParallelWriter Gizmos;
                public float InnerRadius;
                public float OuterRadius;
                void SonarAvoidance.IDrawArc.DrawArc(float3 position, float3 up, float3 from, float3 to, float angle, UnityEngine.Color color)
                {
                    Gizmos.DrawSolidArc(position, up, to, math.degrees(angle), OuterRadius, color);
                    Gizmos.DrawWireArc(position, up, to, math.degrees(angle), OuterRadius, UnityEngine.Color.white);
                    Gizmos.DrawLine(position, position + from * OuterRadius, UnityEngine.Color.white);
                    Gizmos.DrawLine(position, position + to * OuterRadius, UnityEngine.Color.white);

                    Gizmos.DrawSolidArc(position, up, to, math.degrees(angle), InnerRadius, new UnityEngine.Color(1, 1, 1, 0.4f));
                }
            }

            struct DrawCircle : SonarAvoidance.IDrawCircle
            {
                public GizmosCommandBuffer.ParallelWriter Gizmos;

                void SonarAvoidance.IDrawCircle.DrawCircle(float3 center, float radius, Color color)
                {
                    Gizmos.DrawSolidDisc(center, new float3(0, 1, 0), radius, color);
                }
            }
        }
    }
}
