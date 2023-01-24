using Unity.Entities;
using UnityEngine;
using UnityEditor;

namespace ProjectDawn.Navigation.Hybrid
{
    [RequireMatchingQueriesForUpdate]
    [UpdateInGroup(typeof(InitializationSystemGroup))]
    public partial class SelectionGizmosSystem : SystemBase
    {
        protected override void OnUpdate()
        {
            if (Selection.gameObjects.Length == 0)
                return;
            Entities
            .WithAll<Agent>()
            .ForEach((Entity entity, Transform transform) =>
            {
                // TODO: Change to this once gizmos command buffer support parallel resize
                //bool isSelected = UnityEditor.Selection.Contains(transform.gameObject);

                bool isSelected = transform.gameObject == Selection.activeGameObject;

                bool hasDrawGizmos = EntityManager.HasComponent<DrawGizmos>(entity);

                if (isSelected && !hasDrawGizmos)
                {
                    EntityManager.AddComponent<DrawGizmos>(entity);
                }
                else if (!isSelected && hasDrawGizmos)
                {
                    EntityManager.RemoveComponent<DrawGizmos>(entity);
                }
            }).WithStructuralChanges().WithoutBurst().Run();
        }
    }
}
