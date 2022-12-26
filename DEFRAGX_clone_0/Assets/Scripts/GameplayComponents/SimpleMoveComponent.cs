using DG.Tweening;
using Fusion;
using UnityEngine;

namespace Projectiles.UI
{
	[OrderBefore(typeof(HitboxManager))]
	public class SimpleMoveComponent : NetworkBehaviour
	{
		// PRIVATE MEMBERS

		[SerializeField]
		private Vector3 _offset = new Vector3(0f, 0f, 10f);
		[SerializeField]
		private float _speed = 10f;
		[SerializeField]
		private Ease _ease = Ease.InOutSine;
		[SerializeField]
		private bool _predictMove = true;

		[Networked]
		private int _startTick { get; set; }
		[Networked]
		private Vector3 _startPosition { get; set; }
		[Networked]
		private Vector3 _targetPosition { get; set; }

		private Rigidbody _rigidbody;
		private float _distance;

		// NetworkBehaviour INTERFACE

		public override void Spawned()
		{
			if (HasStateAuthority == true)
			{
				_startTick = Runner.Tick;
				_startPosition = transform.position;
				_targetPosition = _startPosition + transform.rotation * _offset;
			}

			_distance = _offset.magnitude;
		}

		public override void FixedUpdateNetwork()
		{
			if (_predictMove == true || HasStateAuthority == true)
			{
				UpdatePosition(Runner.Tick);
			}
			else
			{
				var simulation = Runner.Simulation;

				float floatTick = simulation.InterpFrom.Tick + (simulation.InterpTo.Tick - simulation.InterpFrom.Tick) * simulation.InterpAlpha;
				UpdatePosition(floatTick);
			}

			if (_predictMove == true)
			{
				if (_rigidbody != null)
				{
					// Update colliders position in physics scene
					_rigidbody.position = transform.position;
				}
				else
				{
					Debug.LogError("For predicted movement Rigidbody component is needed to updated collider position (in physics scene) correctly during resimulations");
				}
			}
		}

		public override void Render()
		{
			if (_predictMove == true || HasStateAuthority == true)
			{
				UpdatePosition(Runner.Tick + Runner.Simulation.StateAlpha);
			}
			else
			{
				var simulation = Runner.Simulation;

				float floatTick = simulation.InterpFrom.Tick + (simulation.InterpTo.Tick - simulation.InterpFrom.Tick) * simulation.InterpAlpha;
				UpdatePosition(floatTick);
			}
		}

		// MONOBEHAVIOUR

		protected void Awake()
		{
			_rigidbody = GetComponent<Rigidbody>();
		}

		// PRIVATE METHODS

		private void UpdatePosition(float floatTick)
		{
			float elapsedTime = (floatTick - _startTick) * Runner.DeltaTime;
			float totalDistance = _speed * elapsedTime;

			float currentDistance = totalDistance % (_distance * 2f);

			if (currentDistance > _distance)
			{
				// Returning
				float progress = (currentDistance - _distance) / _distance;
				transform.position = Vector3.Lerp(_targetPosition, _startPosition, DOVirtual.EasedValue(0f, 1f, progress, _ease));
			}
			else
			{
				float progress = currentDistance / _distance;
				transform.position = Vector3.Lerp(_startPosition, _targetPosition, DOVirtual.EasedValue(0f, 1f, progress, _ease));
			}
		}
	}
}
