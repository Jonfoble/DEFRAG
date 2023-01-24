using Unity.Entities;
using Unity.Mathematics;
using UnityEngine;

namespace ProjectDawn.Navigation.Hybrid
{
    [AddComponentMenu("Agents Navigation/Settings/Spatial Partitioning Settings")]
    [DisallowMultipleComponent]
    [HelpURL("https://lukaschod.github.io/agents-navigation-docs/manual/authoring.html")]
    public class SpatialPartitioningSettingsAuthoring : EntityBehaviour
    {
        [SerializeField]
        protected int AgentCapacity = 2000;

        [SerializeField]
        protected float3 CellSize = 3;

        /// <summary>
        /// Returns default component of <see cref="AgentSpatialPartitioningSystem.Settings"/>.
        /// </summary>
        public AgentSpatialPartitioningSystem.Settings DefaultSettings => new AgentSpatialPartitioningSystem.Settings
        {
            AgentCapacity = AgentCapacity,
            CellSize = CellSize,
        };

        /// <summary>
        /// <see cref="AgentSpatialPartitioningSystem.Settings"/> component of this Entity.
        /// Accessing this property is potentially heavy operation as it will require wait for agent jobs to finish.
        /// </summary>
        public AgentSpatialPartitioningSystem.Settings EntitySettings
        {
            get => World.DefaultGameObjectInjectionWorld.EntityManager.GetComponentData<AgentSpatialPartitioningSystem.Settings>(m_Entity);
            set => World.DefaultGameObjectInjectionWorld.EntityManager.SetComponentData(m_Entity, value);
        }

        /// <summary>
        /// Returns true if entity has <see cref="AgentSpatialPartitioningSystem.Settings"/>.
        /// </summary>
        public bool HasEntitySettings => World.DefaultGameObjectInjectionWorld != null && World.DefaultGameObjectInjectionWorld.EntityManager.HasComponent<AgentSpatialPartitioningSystem.Settings>(m_Entity);

        void Awake()
        {
            var entity = GetOrCreateEntity();
            var world = World.DefaultGameObjectInjectionWorld;
            var manager = world.EntityManager;
            manager.AddComponentData(entity, DefaultSettings);
        }
    }

    internal class AgentSpatialBaker : Baker<SpatialPartitioningSettingsAuthoring>
    {
        public override void Bake(SpatialPartitioningSettingsAuthoring authoring) => AddComponent(authoring.DefaultSettings);
    }
}
