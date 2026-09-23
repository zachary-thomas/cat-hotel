using UnityEngine;
using UnityEngine.UI;

namespace Purrington.Presentation
{
    // Gold paw coin from the concept art, built from rounded images so no icon font is needed.
    public static class UiCoin
    {
        public static RectTransform Create(RectTransform parent, Sprite round, float size)
        {
            var coin = Disc("Paw coin", parent, round, ConceptTheme.Ui.CoinRim, size, Vector2.zero);
            Disc("Face", coin, round, ConceptTheme.Ui.Coin, size - 4, Vector2.zero);
            float s = size / 26f;
            Disc("Pad", coin, round, ConceptTheme.Ui.CoinRim, 9 * s, new Vector2(0, -3 * s));
            foreach (var toe in new[] { new Vector2(-6, 3), new Vector2(-2, 7), new Vector2(2, 7), new Vector2(6, 3) })
                Disc("Toe", coin, round, ConceptTheme.Ui.CoinRim, 4 * s, toe * s);
            return coin;
        }

        static RectTransform Disc(string name, RectTransform parent, Sprite round, Color color, float size, Vector2 offset)
        {
            var r = new GameObject(name, typeof(RectTransform)).GetComponent<RectTransform>();
            r.SetParent(parent, false); r.anchorMin = r.anchorMax = r.pivot = new Vector2(.5f, .5f); r.sizeDelta = new Vector2(size, size); r.anchoredPosition = offset;
            var image = r.gameObject.AddComponent<Image>(); image.sprite = round; image.type = round != null ? Image.Type.Sliced : Image.Type.Simple; image.color = color; image.raycastTarget = false;
            return r;
        }
    }
}
