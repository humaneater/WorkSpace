using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LightController : MonoBehaviour
{
    public Vector3 direction = Vector3.zero;
    [Range(-10,10)]public float speed;
    public Transform light;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
       light.Rotate(Vector3.right + direction,Time.deltaTime * speed); 
    }
}
