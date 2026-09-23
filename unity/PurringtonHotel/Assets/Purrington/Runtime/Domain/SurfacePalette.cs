using System;
using System.Collections.Generic;

namespace Purrington.Domain
{
    // World surface roles and HUD tokens. Targets are sampled from assets/ui/mobile (world) and docs/concept-art (HUD).
    public static class SurfacePalette
    {
        public readonly struct Row
        {
            public readonly string source, target; public readonly bool authored;
            public Row(string source, string target, bool authored) { this.source = source; this.target = target; this.authored = authored; }
        }

        // authored=true: a legacy Godot color whose hue family must survive. false: a presentation literal given a new role.
        public static readonly Row[] Rows =
        {
            new Row("60a830","8CC84B",true), new Row("186030","4FA64A",true), new Row("a86030","C9A07A",true),
            new Row("f0d8c0","E8D3B2",true), new Row("ede8d9","E4DCCB",true), new Row("fff8e9","FFF4DF",true),
            new Row("f0a830","F7CC62",true), new Row("ffd16f","F7CC62",true), new Row("ffab97","F08C7C",true),
            new Row("60d6a6","8ED9AE",true), new Row("dfd2f5","C3B2EE",true), new Row("f078a8","F5AEB4",true),
            new Row("a8d8f0","A9DDF6",true), new Row("dba5b0","F2A7B2",true), new Row("d7a4ba","E7A9C6",true),
            new Row("87b7a5","86CFA4",true), new Row("9dc4b5","9ED8BA",true), new Row("e6a1a6","F49AA2",true),
            new Row("ebb2b6","F6A9B0",true), new Row("74c5c5","7FD3CF",true), new Row("83d4d0","92DDD8",true),
            new Row("a8e9df","B2EEE4",true), new Row("b2e9df","BDF1E7",true), new Row("d7b5c4","EDBBD0",true),
            new Row("a892b9","B9A2DD",true), new Row("bfaecb","CDBDEB",true), new Row("e1c8d3","F2D3E0",true),
            new Row("ca9eae","E7A2B8",true), new Row("d4afbd","EDB5C7",true), new Row("dd929f","F2949F",true),
            new Row("e19fab","F4A3B0",true), new Row("e59889","F29A8A",true), new Row("ecb3a8","F6B8AB",true),
            new Row("edc76a","F7CC62",true), new Row("f7d880","F9DC84",true), new Row("c295c0","D69AD2",true),
            new Row("caa3c8","DFAEDA",true), new Row("9783a7","A58DD0",true), new Row("ac97bc","BBA4DD",true),
            new Row("b3a0c2","C4AEE3",true), new Row("b3c8cf","B4D8E6",true), new Row("bed5dc","C3E2EE",true),
            new Row("a7bbc2","A6CFE0",true), new Row("9eacc1","98A9EA",true), new Row("a8b7cd","A5B6EE",true),
            new Row("94a1b4","8E9FE0",true), new Row("9eb9b1","9FD1BF",true), new Row("b2cfcb","B6E0D8",true),
            new Row("9cb8b0","9ACFBC",true),
            // Destination lawns (world-map.png): Meadow, Seaside sand, Forest grass, Snowcap snow.
            new Row("83a36e","8CC84B",false), new Row("cfbb90","F3E2B5",false), new Row("758c64","6FAE55",false), new Row("c2cdcb","F4F7FB",false),
            // Room and shell literals: wainscot panels, per-destination roofs, window frame and panes, hedges.
            new Row("738448","8FD7A8",false), new Row("7e8c65","9ADCB2",false), new Row("87936e","86D2A0",false), new Row("697f59","7ECB98",false),
            new Row("a87868","6DBB6A",false), new Row("82a9a2","5C9EE0",false), new Row("7c8e6d","B0703F",false), new Row("d9e1d7","F1F5FA",false),
            new Row("90bfc0","A9DDF6",false), new Row("b5ddcf","C8EBFA",false), new Row("88ab72","6CC06A",false), new Row("6e9b62","5FB35C",false), new Row("a9bccd","B4DCF2",false),
        };

        public const string Ink = "244335", InkSoft = "4E6555", Card = "FBF6E9", CardEdge = "E6DCC4", Sage = "DCE5C5";
        public const string Leaf = "4E7F3A", LeafText = "2E6B2C", Coin = "E9B43A", CoinRim = "B9832A";

        static readonly string[] glass = { "90bfc0", "b5ddcf", "a9bccd" };
        static Dictionary<string, string> map;

        public static bool TryMap(string hex6, out string target)
        {
            if (map == null) { var m = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase); foreach (var r in Rows) m[r.source] = r.target; map = m; }
            target = null;
            return hex6 != null && map.TryGetValue(hex6, out target);
        }

        public static bool IsGlass(string hex6) => hex6 != null && Array.Exists(glass, g => g.Equals(hex6, StringComparison.OrdinalIgnoreCase));

        // Lantern and lamp-shade swatches glow with the windows at dusk and night.
        public const string LanternGlow = "FFE6A8";
        static readonly string[] lamps = { "ffe6a8", "f5da83" };
        public static bool IsLamp(string hex6) => hex6 != null && Array.Exists(lamps, g => g.Equals(hex6, StringComparison.OrdinalIgnoreCase));
        public static bool Glows(string hex6) => IsGlass(hex6) || IsLamp(hex6);

        // Stable per-voxel tone pick from a rounded position; never UnityEngine.Random, so captures repeat.
        public static int Variant(float x, float y, float z)
        {
            unchecked
            {
                int h = (int)Math.Round(x * 2) * 73856093 ^ (int)Math.Round(y * 2) * 19349663 ^ (int)Math.Round(z * 2) * 83492791;
                return (int)((uint)h % 3u);
            }
        }

        // 0 = base, 1 = 4% lighter nudged warm, 2 = 4% darker nudged cool.
        public static string Tone(string hex6, int variant)
        {
            Rgb(hex6, out double r, out double g, out double b);
            if (variant == 1) { r = Mix(r * 1.04, 1.00, .03); g = Mix(g * 1.04, .886, .03); b = Mix(b * 1.04, .690, .03); }
            else if (variant == 2) { r = Mix(r * .96, .722, .03); g = Mix(g * .96, .784, .03); b = Mix(b * .96, .910, .03); }
            return Hex(r, g, b);
        }

        // Fallback for colors without a row: keep the hue, lift toward high-key and add a little color.
        // Dark and near-gray colors (ink, black fur, stone, white plaster) are returned unchanged.
        public static string Pastelize(string hex6)
        {
            Rgb(hex6, out var r, out var g, out var b);
            double v = Math.Max(r, Math.Max(g, b)), c = v - Math.Min(r, Math.Min(g, b)), s = v <= 0 ? 0 : c / v;
            if (v < .35 || s < .08) return Hex(r, g, b);
            // Oranges and tans (timber, floors, sand) keep their saturation so the world doesn't drift orange; other hues get the pastel boost.
            double hue = Hue(hex6); bool warm = hue >= 15 && hue <= 55;
            double s2 = warm ? s : Math.Min(.62, Math.Max(s, s * 1.3 + .04)), v2 = v + (1 - v) * (warm ? .18 : .3);
            double h = Hue(hex6) / 60, c2 = v2 * s2, x = c2 * (1 - Math.Abs(h % 2 - 1)), m = v2 - c2;
            double r2, g2, b2;
            if (h < 1) { r2 = c2; g2 = x; b2 = 0; } else if (h < 2) { r2 = x; g2 = c2; b2 = 0; } else if (h < 3) { r2 = 0; g2 = c2; b2 = x; }
            else if (h < 4) { r2 = 0; g2 = x; b2 = c2; } else if (h < 5) { r2 = x; g2 = 0; b2 = c2; } else { r2 = c2; g2 = 0; b2 = x; }
            return Hex(r2 + m, g2 + m, b2 + m);
        }

        public static double Chroma(string hex) { Rgb(hex, out var r, out var g, out var b); return Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b)); }
        public static double Value(string hex) { Rgb(hex, out var r, out var g, out var b); return Math.Max(r, Math.Max(g, b)); }
        public static double Hue(string hex)
        {
            Rgb(hex, out var r, out var g, out var b);
            double max = Math.Max(r, Math.Max(g, b)), c = Chroma(hex);
            if (c <= 0) return 0;
            double h = max == r ? ((g - b) / c) % 6 : max == g ? (b - r) / c + 2 : (r - g) / c + 4;
            h *= 60; return h < 0 ? h + 360 : h;
        }
        public static double RelativeLuminance(string hex)
        {
            Rgb(hex, out var r, out var g, out var b);
            double L(double c) => c <= .03928 ? c / 12.92 : Math.Pow((c + .055) / 1.055, 2.4);
            return .2126 * L(r) + .7152 * L(g) + .0722 * L(b);
        }
        public static double Contrast(string a, string b)
        {
            double x = RelativeLuminance(a), y = RelativeLuminance(b);
            return (Math.Max(x, y) + .05) / (Math.Min(x, y) + .05);
        }

        public static void Rgb(string hex, out double r, out double g, out double b)
        {
            hex = (hex ?? "000000").TrimStart('#');
            if (hex.Length < 6) throw new FormatException("Expected a six-digit hex color, got '" + hex + "'.");
            r = Convert.ToInt32(hex.Substring(0, 2), 16) / 255.0; g = Convert.ToInt32(hex.Substring(2, 2), 16) / 255.0; b = Convert.ToInt32(hex.Substring(4, 2), 16) / 255.0;
        }
        static double Mix(double a, double b, double t) => a + (b - a) * t;
        static string Hex(double r, double g, double b)
        {
            int C(double v) => (int)Math.Round(Math.Max(0, Math.Min(1, v)) * 255);
            return C(r).ToString("X2") + C(g).ToString("X2") + C(b).ToString("X2");
        }
    }
}
