using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DontDestroySingleton : Singleton<DontDestroySingleton>
{
    private void Awake()
    {
        DontDestroyOnLoad(this.gameObject);
    }
}
