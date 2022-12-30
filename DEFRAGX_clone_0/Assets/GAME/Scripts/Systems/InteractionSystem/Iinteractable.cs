using UnityEngine;

namespace Jonfoble.Interaction
{
	public interface Iinteractable
	{
		string InteractionPrompt { get; }
		KeyCode InteractionKeyCode { get; }
		void Interact(GameObject go);
	}
}