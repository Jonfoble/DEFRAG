using Unity.Entities;

namespace ProjectDawn.Navigation
{
    [UpdateInGroup(typeof(FixedStepSimulationSystemGroup))]
    public partial class AgentSystemGroup : ComponentSystemGroup { }
}
