using Unity.Entities;

namespace ProjectDawn.Navigation
{
    /// <summary>
    /// Agent avoidance of nearby agents using Sonar Avoidance algorithm.
    /// </summary>
    public struct AgentSonarAvoid : IComponentData
    {
        /// <summary>
        /// The maximum distance at which agent will attempt to avoid nearby agents.
        /// </summary>
        public float Radius;
        /// <summary>
        /// The maximum angle at which agent will attempt to nearby agents.
        /// </summary>
        public float Angle;
        /// <summary>
        /// Mode that modifies avoidance behaviour.
        /// </summary>
        public SonarAvoidMode Mode;
        /// <summary>
        /// Whenever agent should stop if all directions are blocked.
        /// </summary>
        public bool BlockedStop;
    }
}
