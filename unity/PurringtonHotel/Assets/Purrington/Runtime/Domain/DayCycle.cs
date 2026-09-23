using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace Purrington.Domain
{
    public readonly struct DayLight
    {
        public readonly float sunPitch, sunYaw, sunIntensity, shadowStrength, exposure, temperature, glow;
        public readonly float[] sun, sky, equator, ground, background; // linear RGB
        public DayLight(float sunPitch, float sunYaw, float sunIntensity, float shadowStrength, float exposure, float temperature, float glow, float[] sun, float[] sky, float[] equator, float[] ground, float[] background)
        { this.sunPitch = sunPitch; this.sunYaw = sunYaw; this.sunIntensity = sunIntensity; this.shadowStrength = shadowStrength; this.exposure = exposure; this.temperature = temperature; this.glow = glow; this.sun = sun; this.sky = sky; this.equator = equator; this.ground = ground; this.background = background; }
    }

    public sealed class DayCycle
    {
        static readonly string[] Numbers = { "minute", "sunPitch", "sunYaw", "sunIntensity", "shadowStrength", "exposure", "temperature", "glow" };
        static readonly string[] Colors = { "sun", "sky", "equator", "ground", "background" };
        sealed class Key { public float[] n = new float[Numbers.Length]; public float[][] c = new float[Colors.Length][]; }
        readonly List<Key> keys;
        DayCycle(List<Key> keys) { this.keys = keys; }
        public int Count => keys.Count;

        public static DayCycle Parse(string json)
        {
            JObject root;
            try { root = JObject.Parse(json ?? ""); } catch (Exception e) { throw new FormatException("DayCycle.json is not valid JSON: " + e.Message); }
            if (!(root["keys"] is JArray array) || array.Count < 2) throw new FormatException("DayCycle.json needs a \"keys\" array with at least two keys.");
            var list = new List<Key>();
            for (int i = 0; i < array.Count; i++)
            {
                if (!(array[i] is JObject o)) throw new FormatException("DayCycle.json keys[" + i + "] must be an object.");
                var k = new Key();
                for (int f = 0; f < Numbers.Length; f++)
                {
                    var t = o[Numbers[f]];
                    if (t == null || (t.Type != JTokenType.Integer && t.Type != JTokenType.Float)) throw new FormatException("DayCycle.json keys[" + i + "] is missing number \"" + Numbers[f] + "\".");
                    k.n[f] = (float)t;
                }
                for (int f = 0; f < Colors.Length; f++)
                {
                    var t = o[Colors[f]];
                    if (t == null || t.Type != JTokenType.String) throw new FormatException("DayCycle.json keys[" + i + "] is missing color \"" + Colors[f] + "\".");
                    try { k.c[f] = Linear((string)t); } catch (FormatException) { throw new FormatException("DayCycle.json keys[" + i + "] color \"" + Colors[f] + "\" is not a hex color."); }
                }
                if (k.n[0] < 0 || k.n[0] >= 1440) throw new FormatException("DayCycle.json keys[" + i + "] minute must be in [0, 1440).");
                if (list.Count > 0 && k.n[0] <= list[list.Count - 1].n[0]) throw new FormatException("DayCycle.json keys must be in increasing minute order (keys[" + i + "]).");
                if (k.n[7] < 0 || k.n[7] > 1) throw new FormatException("DayCycle.json keys[" + i + "] glow must be in [0, 1].");
                list.Add(k);
            }
            return new DayCycle(list);
        }

        public DayLight Evaluate(float minute) => Evaluate(minute, default);

        // Per-frame form: fills reuse's color arrays in place (allocating only the ones that are null), so a caller that keeps the result allocates nothing.
        public DayLight Evaluate(float minute, DayLight reuse)
        {
            minute = ((minute % 1440f) + 1440f) % 1440f;
            int b = 0; while (b < keys.Count && keys[b].n[0] <= minute) b++; if (b == keys.Count) b = 0;
            int a = (b - 1 + keys.Count) % keys.Count;
            var ka = keys[a]; var kb = keys[b];
            float span = ((kb.n[0] - ka.n[0]) + 1440f) % 1440f; if (span <= 0) span = 1440f;
            float t = (((minute - ka.n[0]) + 1440f) % 1440f) / span;
            float N(int f) => ka.n[f] + (kb.n[f] - ka.n[f]) * t;
            float yawDelta = ((kb.n[2] - ka.n[2] + 540f) % 360f) - 180f;
            float[] C(int f, float[] into)
            {
                if (into == null || into.Length != 3) into = new float[3];
                for (int i = 0; i < 3; i++) into[i] = ka.c[f][i] + (kb.c[f][i] - ka.c[f][i]) * t;
                return into;
            }
            return new DayLight(N(1), ka.n[2] + yawDelta * t, N(3), N(4), N(5), N(6), N(7), C(0, reuse.sun), C(1, reuse.sky), C(2, reuse.equator), C(3, reuse.ground), C(4, reuse.background));
        }

        static float[] Linear(string hex)
        {
            SurfacePalette.Rgb(hex, out var r, out var g, out var b);
            float L(double c) => (float)(c <= .04045 ? c / 12.92 : Math.Pow((c + .055) / 1.055, 2.4));
            return new[] { L(r), L(g), L(b) };
        }
    }
}
