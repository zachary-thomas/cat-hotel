using System.Linq;
using Purrington.Domain;
using UnityEngine;

namespace Purrington.Presentation
{
    // World roles come from assets/ui/mobile; HUD tokens from docs/concept-art. Both live in SurfacePalette.
    public static class ConceptTheme
    {
        public static Color Ink => ColorOf(SurfacePalette.Ink);
        public static Color Cream => ColorOf("F8F3E3");
        public static Color Sage => ColorOf(SurfacePalette.Sage);
        public static Color Moss => ColorOf("789B58");
        public static Color Clay => ColorOf("D6A182");
        public static Color Honey => ColorOf("D7AE55");
        public static class Ui
        {
            public static Color Ink => ColorOf(SurfacePalette.Ink);
            public static Color InkSoft => ColorOf(SurfacePalette.InkSoft);
            public static Color Card => ColorOf(SurfacePalette.Card);
            public static Color CardEdge => ColorOf(SurfacePalette.CardEdge);
            public static Color Sage => ColorOf(SurfacePalette.Sage);
            public static Color Leaf => ColorOf(SurfacePalette.Leaf);
            public static Color LeafText => ColorOf(SurfacePalette.LeafText);
            public static Color Coin => ColorOf(SurfacePalette.Coin);
            public static Color CoinRim => ColorOf(SurfacePalette.CoinRim);
            public static Color[] All => new[] { Ink, InkSoft, Card, CardEdge, Sage, Leaf, LeafText, Coin, CoinRim, Color.white };
        }
        public static Color ColorOf(string hex)
        {
            ColorUtility.TryParseHtmlString("#"+hex.TrimStart('#'),out var color);
            return color;
        }
        // Paths have their own role: legacy geometry reused the timber swatch for paving.
        public static string PathColor(string style,float x,float z)
        {
            Color color=ColorOf(style=="gravel"?"C7C1AD":style=="brick"?"AAA895":"BBB6A5");
            int tile=Mathf.Abs(Mathf.RoundToInt(x)*17+Mathf.RoundToInt(z)*31)%5;
            color*=.96f+tile*.02f;color.a=1;
            return ColorUtility.ToHtmlStringRGB(color);
        }
        public static Color Surface(string authored)
        {
            string key=(authored??"ffffffff").TrimStart('#');
            ColorUtility.TryParseHtmlString("#"+key,out var original);
            if(key.Length>=6&&SurfacePalette.TryMap(key.Substring(0,6),out var replacement)){var mapped=ColorOf(replacement);mapped.a=original.a;return mapped;}
            return original;
        }
    }
}
