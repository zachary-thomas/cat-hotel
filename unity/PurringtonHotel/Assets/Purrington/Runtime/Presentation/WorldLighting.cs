using System;
using Purrington.Domain;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Purrington.Presentation
{
    // Applies the day-cycle keyframes to the sun, ambient light, sky color and a runtime copy of the grading profile.
    public sealed class WorldLighting : MonoBehaviour
    {
        public static float Glow { get; private set; }
        public Light Sun { get; private set; }
        HotelModel model; Camera cam; GodotGeometry geometry; DayCycle cycle; float? pinned;
        VolumeProfile profile; ColorAdjustments adjust; WhiteBalance balance; DayLight light;

        public float Minute => pinned ?? (model != null ? model.Clock.minute : HotelClock.StartMinute);

        public void Initialize(HotelModel model, Camera cam, GodotGeometry geometry)
        {
            this.model = model; this.cam = cam; this.geometry = geometry;
            var text = Resources.Load<TextAsset>("Content/DayCycle");
            if (text == null) throw new InvalidOperationException("Resources/Content/DayCycle.json is missing.");
            cycle = DayCycle.Parse(text.text);
            Sun = new GameObject("Sun and moon").AddComponent<Light>();
            Sun.transform.SetParent(transform); Sun.type = LightType.Directional; Sun.shadows = LightShadows.Soft; Sun.shadowBias = .045f; Sun.shadowNormalBias = .45f;
            var volume = FindFirstObjectByType<Volume>();
            if (volume != null && volume.sharedProfile != null)
            {
                // Volume.profile deep-clones the shared profile and its components, so Override never writes to ParityGrading.asset.
                profile = volume.profile;
                profile.TryGet(out adjust); profile.TryGet(out balance);
            }
            Apply();
        }

        public void Pin(float? minute) { pinned = minute; Apply(); }

        void LateUpdate() { if (cycle != null) Apply(); }

        void Apply()
        {
            var l = light = cycle.Evaluate(Minute, light);
            ApplyTo(Sun, cam, l);
            if (adjust != null) adjust.postExposure.Override(l.exposure);
            if (balance != null) balance.temperature.Override(l.temperature);
            Glow = l.glow;
            geometry?.SetGlow(Glow * 3.2f);
        }

        public static void ApplyTo(Light sun, Camera cam, DayLight l)
        {
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = C(l.sky); RenderSettings.ambientEquatorColor = C(l.equator); RenderSettings.ambientGroundColor = C(l.ground);
            sun.transform.rotation = Quaternion.Euler(l.sunPitch, l.sunYaw, 0);
            sun.color = C(l.sun); sun.intensity = l.sunIntensity; sun.shadowStrength = l.shadowStrength;
            if (cam != null) cam.backgroundColor = C(l.background);
        }

        static Color C(float[] linear) => new Color(linear[0], linear[1], linear[2]).gamma;

        void OnDestroy()
        {
            if (profile == null) return;
            foreach (var c in profile.components) if (c != null) Destroy(c);
            Destroy(profile);
        }
    }
}
