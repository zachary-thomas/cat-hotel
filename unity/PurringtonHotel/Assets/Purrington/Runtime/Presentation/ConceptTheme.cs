using System;
using System.Collections.Generic;
using UnityEngine;

namespace Purrington.Presentation
{
    // Material roles interpreted from docs/concept-art/02 and 06, not the later art cards.
    public static class ConceptTheme
    {
        public static Color Ink => ColorOf("244335");
        public static Color Cream => ColorOf("F8F3E3");
        public static Color Sage => ColorOf("DCE5C5");
        public static Color Moss => ColorOf("789B58");
        public static Color Clay => ColorOf("D6A182");
        public static Color Honey => ColorOf("D7AE55");
        static readonly Dictionary<string,string> Surfaces = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase)
        {
            {"60a830","82934D"}, {"186030","425C35"}, {"a86030","B3824C"},
            {"f0d8c0","D2AD77"}, {"ede8d9","BBB6A5"}, {"fff8e9","EFE2C9"},
            {"f0a830","D7AE55"}, {"ffd16f","D7AE55"}, {"ffab97","BF7958"},
            {"60d6a6","738448"}, {"dfd2f5","89936C"}, {"f078a8","C58A75"},
            {"a8d8f0","C6D4C1"}, {"dba5b0","BE8C76"}, {"d7a4ba","B78B78"},
            {"87b7a5","687E53"}, {"9dc4b5","82936B"}, {"e6a1a6","B98063"}, {"ebb2b6","C99678"},
            {"74c5c5","788D61"}, {"83d4d0","97A67D"}, {"a8e9df","B7C29B"}, {"b2e9df","BECBA5"},
            {"d7b5c4","B89576"}, {"a892b9","8C9270"}, {"bfaecb","A5AC8B"}, {"e1c8d3","D0B99C"},
            {"ca9eae","B98168"}, {"d4afbd","C59B80"}, {"dd929f","B87E64"}, {"e19fab","C08B70"},
            {"e59889","BF7958"}, {"ecb3a8","D49E7F"}, {"edc76a","D7AE55"}, {"f7d880","E0C477"},
            {"c295c0","8A986B"}, {"caa3c8","A0AD81"},
            {"9783a7","66754E"}, {"ac97bc","869565"}, {"b3a0c2","99A679"},
            {"b3c8cf","A3B18F"}, {"bed5dc","B9C6A5"}, {"a7bbc2","8E9E7C"},
            {"9eacc1","B07D62"}, {"a8b7cd","C49377"}, {"94a1b4","986A54"},
            {"9eb9b1","879777"}, {"b2cfcb","A3B294"}, {"9cb8b0","8C9D7B"}
        };
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
            if(key.Length>=6 && Surfaces.TryGetValue(key.Substring(0,6),out var replacement))
            {
                var mapped=ColorOf(replacement);mapped.a=original.a;return mapped;
            }
            return original;
        }
    }
}
