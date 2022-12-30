using Jonfoble.ObjectPool;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Jonfoble.FloatingText
{
    public class FloatingTextHandler : MonoBehaviour
    {
        private void OnEnable()
        {
            Invoke("AddPool", 1f);
        }
        void AddPool()
        {
            ObjectPoolManager.Instance.AddObject("FloatingText", gameObject);
        }
    }
}
