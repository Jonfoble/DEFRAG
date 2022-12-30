using UnityEngine;
using Unity.Collections;
using UnityEngine.Events;

namespace Jonfoble.ScriptableSystem
{
    [CreateAssetMenu(menuName = "Jonfoble/ScriptableSystem/ScriptableAction")]
    public class ScriptableAction : ScriptableObject
    {
        [ReadOnly] public UnityEvent ActionEvent;

        [ContextMenu("Call Action")] // Utilised to create a button
        public void CallAction()
        {
            ActionEvent?.Invoke();
        }
    }
}