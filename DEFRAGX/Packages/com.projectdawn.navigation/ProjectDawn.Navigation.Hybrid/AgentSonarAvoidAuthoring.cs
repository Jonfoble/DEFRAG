using Unity.Entities;
using Unity.Mathematics;
using UnityEngine;

namespace ProjectDawn.Navigation.Hybrid
{
    /// <summary>
    /// Agent avoidance of nearby agents.
    /// </summary>
    [RequireComponent(typeof(AgentAuthoring))]
    [AddComponentMenu("Agents Navigation/Agent Sonar Avoid")]
    [DisallowMultipleComponent]
    [HelpURL("https://lukaschod.github.io/agents-navigation-docs/manual/authoring.html")]
    public class AgentAvoidAuthoring : MonoBehaviour
    {
        [SerializeField]
        protected float Radius = 6;

        [SerializeField, Range(0, 180)]
        protected float Angle = 135;

        [SerializeField]
        protected SonarAvoidMode Mode = SonarAvoidMode.IgnoreBehindAgents;

        [SerializeField]
        protected bool BlockedStop = false;

        Entity m_Entity;

        /// <summary>
        /// Returns default component of <see cref="AgentSonarAvoid"/>.
        /// </summary>
        public AgentSonarAvoid DefaultAvoid => new AgentSonarAvoid
        {
            Radius = Radius,
            Angle = math.radians(Angle),
            Mode = Mode,
            BlockedStop = BlockedStop,
        };

        /// <summary>
        /// <see cref="AgentSonarAvoid"/> component of this <see cref="AgentAuthoring"/> Entity.
        /// Accessing this property is potentially heavy operation as it will require wait for agent jobs to finish.
        /// </summary>
        public AgentSonarAvoid EntityAvoid
        {
            get => World.DefaultGameObjectInjectionWorld.EntityManager.GetComponentData<AgentSonarAvoid>(m_Entity);
            set => World.DefaultGameObjectInjectionWorld.EntityManager.SetComponentData(m_Entity, value);
        }

        /// <summary>
        /// Returns true if <see cref="AgentAuthoring"/> entity has <see cref="AgentSonarAvoid"/>.
        /// </summary>
        public bool HasEntityAvoid => World.DefaultGameObjectInjectionWorld != null && World.DefaultGameObjectInjectionWorld.EntityManager.HasComponent<AgentSonarAvoid>(m_Entity);

        void Awake()
        {
            var world = World.DefaultGameObjectInjectionWorld;
            m_Entity = GetComponent<AgentAuthoring>().GetOrCreateEntity();
            world.EntityManager.AddComponentData(m_Entity, DefaultAvoid);
        }

        void OnDestroy()
        {
            var world = World.DefaultGameObjectInjectionWorld;
            if (world != null)
                world.EntityManager.RemoveComponent<AgentSonarAvoid>(m_Entity);
        }
    }

    internal class AgentSonarAvoidBaker : Baker<AgentAvoidAuthoring>
    {
        public override void Bake(AgentAvoidAuthoring authoring) => AddComponent(authoring.DefaultAvoid);
    }
}
