using UnityEngine;

//拟定一个灯光结构体，因为要变化所以就用class制定了，不知道会不会很大
public class LightData
{
    private Color lightColor;
    private float _range;
    private float _intensity { get; set; }
    private float _spotAngle;
    private float innerAngle;

    public void SetIntensity(float value)
    {
        _intensity = value;
    }

    public void SetLightColor(Color color)
    {
        lightColor = color;
    }

    public Color GetLightColor()
    {
        return lightColor;
    }

    public void SetRange(float range)
    {
        _range = range;
    }

    public float GetRange()
    {
        return _range;
    }

    public float GetSpotAngle()
    {
        return _spotAngle;
    }

    public void SetSpotAngle(float spotAngle)
    {
        _spotAngle = spotAngle;
    }

    public float GetIntensity()
    {
        return _intensity;
    }

    public LightData(Light light)
    {
        lightColor = light.color;
        _intensity = light.intensity;
        innerAngle = light.innerSpotAngle;
        _spotAngle = light.spotAngle;
    }
}