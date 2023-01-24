using Unity.Entities;

namespace ProjectDawn.Navigation
{
    /// <summary>
    /// Agent separation from nearby agents.
    /// </summary>
    public struct AgentSeparation : IComponentData
    {
        /// <summary>
        /// Radius at which agent will attempt separate from each other.
        /// </summary>
        public float Radius;
    }
}
