using Fusion;
using UnityEngine;

namespace Projectiles
{
	[RequireComponent(typeof(Health), typeof(HitboxRoot))]
	public class DummyTarget : NetworkBehaviour
	{
		// PRIVATE MEMBERS

		[SerializeField]
		private float _reviveTime = 3f;
		[SerializeField]
		private Animation _animation;
		[SerializeField]
		private AnimationClip _reviveClip;
		[SerializeField]
		private bool _useLagCompensation;

		[Networked]
		private TickTimer _reviveCooldown { get; set; }

		private Health _health;
		private HitboxRoot _hitboxRoot;
		private Collider _collider;

		private bool _isAlive;

		// MONOBEHAVIOUR

		protected void Awake()
		{
			_health = GetComponent<Health>();
			_hitboxRoot = GetComponent<HitboxRoot>();
			_collider = GetComponentInChildren<Collider>();
		}

		protected void OnEnable()
		{
			_isAlive = false;
		}

		// NetworkBehaviour INTERFACE

		public override void Spawned()
		{
			_collider.enabled = _useLagCompensation == false;
			_hitboxRoot.HitboxRootActive = _useLagCompensation;
		}

		public override void FixedUpdateNetwork()
		{
			if (_useLagCompensation == true)
			{
				_hitboxRoot.HitboxRootActive = _health.IsAlive;
			}
			else
			{
				_collider.enabled = _health.IsAlive;
			}

			if (_health.IsAlive == false)
			{
				if (_reviveCooldown.Expired(Runner) == true)
				{
					_health.ResetHealth();
					_reviveCooldown = default;
				}
				else if (_reviveCooldown.IsRunning == false)
				{
					_reviveCooldown = TickTimer.CreateFromSeconds(Runner, _reviveTime);
				}
			}
		}

		public override void Render()
		{
			SetIsAlive(_health.IsAlive);
		}

		// PRIVATE MEMBERS

		private void SetIsAlive(bool value, bool force = false)
		{
			if (value == _isAlive && force == false)
				return;

			_isAlive = value;

			if (value == true)
			{
				_animation.Play(_reviveClip.name);
			}
		}
	}
}
