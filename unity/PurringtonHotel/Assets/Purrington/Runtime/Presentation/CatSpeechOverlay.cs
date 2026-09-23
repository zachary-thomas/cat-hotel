using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace Purrington.Presentation
{
    /// <summary>One non-interactive screen-space bubble, shared by all speaking cats.</summary>
    public sealed class CatSpeechOverlay : MonoBehaviour
    {
        RectTransform panel;
        CanvasGroup fade;
        TextMeshProUGUI speaker, body;
        CatSpeechShape shape;
        readonly List<Vector2> candidates = new List<Vector2>();

        public static CatSpeechOverlay Create(Transform parent)
        {
            var go = new GameObject("Cat speech overlay", typeof(RectTransform), typeof(Canvas), typeof(CanvasGroup));
            go.transform.SetParent(parent, false);
            var canvas = go.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 15;
            // Deliberately no GraphicRaycaster: speech never takes world input.
            var overlay = go.AddComponent<CatSpeechOverlay>();
            overlay.fade = go.GetComponent<CanvasGroup>();
            overlay.fade.blocksRaycasts = false;
            overlay.fade.interactable = false;
            overlay.panel = new GameObject("Speech bubble", typeof(RectTransform)).GetComponent<RectTransform>();
            overlay.panel.SetParent(go.transform, false);
            overlay.panel.anchorMin = overlay.panel.anchorMax = overlay.panel.pivot = Vector2.zero;
            overlay.shape = overlay.panel.gameObject.AddComponent<CatSpeechShape>();
            overlay.shape.raycastTarget = false;
            overlay.speaker = overlay.Label("Speaker", Resources.Load<TMP_FontAsset>("Fonts/Fredoka SDF"));
            overlay.body = overlay.Label("Dialogue", Resources.Load<TMP_FontAsset>("Fonts/Nunito SDF"));
            overlay.Hide();
            return overlay;
        }

        TextMeshProUGUI Label(string name, TMP_FontAsset font)
        {
            var label = new GameObject(name, typeof(RectTransform)).AddComponent<TextMeshProUGUI>();
            label.transform.SetParent(panel, false);
            label.font = font;
            label.color = new Color32(48, 69, 48, 255);
            label.fontWeight = FontWeight.Medium;
            label.raycastTarget = false;
            label.textWrappingMode = TextWrappingModes.Normal;
            label.overflowMode = TextOverflowModes.Overflow;
            label.rectTransform.anchorMin = label.rectTransform.anchorMax = label.rectTransform.pivot = Vector2.zero;
            return label;
        }

        public void Hide() { if (panel) panel.gameObject.SetActive(false); }

        public void Present(string name, string text, string gesture, Vector2 anchor, Rect area,
            IList<Rect> protectedAreas, float textScale, bool motion, float elapsed, float duration)
        {
            if (string.IsNullOrEmpty(text) || !area.Contains(anchor)) { Hide(); return; }
            float ui = Mathf.Clamp(Screen.width / 390f, .9f, 1.3f);
            float scale = Mathf.Clamp(textScale, 1, 1.5f) * ui;
            float padding = 12 * ui;
            float width = Mathf.Min(260 * scale, area.width - 8 * ui);
            if (width < 120 * ui) { Hide(); return; }
            body.fontSize = 17 * scale;
            speaker.fontSize = 13 * scale;
            body.text = text;
            speaker.text = name;
            float nameHeight = speaker.GetPreferredValues(name, width - 2 * padding - 20 * ui, 0).y;
            float bodyHeight = body.GetPreferredValues(text, width - 2 * padding, 0).y;
            Vector2 size = new Vector2(width, padding * 2 + nameHeight + bodyHeight + 3 * ui);
            candidates.Clear();
            candidates.Add(anchor + new Vector2(-width / 2, 16 * ui));
            candidates.Add(anchor + new Vector2(18 * ui, 12 * ui));
            candidates.Add(anchor + new Vector2(-width - 18 * ui, 12 * ui));
            for (float y = anchor.y + 58 * ui; y + size.y <= area.yMax; y += 24 * ui)
                candidates.Add(new Vector2(anchor.x - width / 2, y));
            candidates.Add(anchor - new Vector2(width / 2, size.y + 42 * ui));
            if (!TryPlace(size, area, candidates, protectedAreas, out var box)) { Hide(); return; }
            // Each new line gets a small hop, so a reply feels like a new cat speaking.
            float entrance = motion ? Mathf.Clamp01(elapsed / .28f) : 1;
            float settle = 1 - Mathf.Pow(1 - entrance, 3);
            float hop = motion ? Mathf.Sin(entrance * Mathf.PI) * (1 - entrance) * 3 * ui : 0;
            var displayPosition = box.position + Vector2.up * (-8 * ui * (1 - settle) + hop);
            panel.anchoredPosition = displayPosition;
            panel.sizeDelta = size;
            body.rectTransform.anchoredPosition = new Vector2(padding, padding);
            body.rectTransform.sizeDelta = new Vector2(width - padding * 2, bodyHeight);
            speaker.rectTransform.anchoredPosition = new Vector2(padding, padding + bodyHeight + 3 * ui);
            speaker.rectTransform.sizeDelta = new Vector2(width - padding * 2 - 20 * ui, nameHeight);
            float heartPulse = motion ? .7f + .3f * settle + .13f * Mathf.Sin(entrance * Mathf.PI) : 1;
            shape.Configure(anchor - displayPosition, gesture == "happy", ui, false, heartPulse);
            fade.alpha = motion ? Mathf.Min(Mathf.SmoothStep(0, 1, Mathf.Clamp01(elapsed / .17f)),
                Mathf.Clamp01((duration - elapsed) / .22f)) : 1;
            panel.gameObject.SetActive(true);
        }

        public static bool TryPlace(Vector2 size, Rect area, IList<Vector2> positions, IList<Rect> protectedAreas, out Rect result)
        {
            result = default;
            if (size.x > area.width - 4 || size.y > area.height) return false;
            foreach (var position in positions)
            {
                var candidate = new Rect(new Vector2(Mathf.Clamp(position.x, area.xMin + 2, area.xMax - size.x - 2), position.y), size);
                if (candidate.yMin < area.yMin || candidate.yMax > area.yMax) continue;
                bool overlaps = false;
                foreach (var region in protectedAreas)
                {
                    var padded = Rect.MinMaxRect(region.xMin - 4, region.yMin - 4, region.xMax + 4, region.yMax + 4);
                    if (candidate.Overlaps(padded)) { overlaps = true; break; }
                }
                if (overlaps) continue;
                result = candidate;
                return true;
            }
            return false;
        }
    }

    /// <summary>Shared rounded chat panel, white rim, pointed tail, and happy heart.</summary>
    public sealed class CatSpeechShape : MaskableGraphic
    {
        Vector2 anchor; bool happy, status; float scale = 1, heartPulse = 1;
        public void Configure(Vector2 value, bool heart, float ui, bool roomStatus = false, float pulse = 1)
        { anchor = value; happy = heart; scale = ui; status = roomStatus; heartPulse = pulse; SetVerticesDirty(); }
        protected override void OnPopulateMesh(VertexHelper mesh)
        {
            mesh.Clear();
            var box = rectTransform.rect;
            var cream = status ? new Color32(255, 242, 215, 255) : new Color32(255, 248, 232, 255);
            var border = status ? new Color32(189, 129, 80, 255) : new Color32(190, 168, 132, 255);
            float radius = (status ? 11 : 17) * scale;
            Rounded(mesh, new Rect(box.position + new Vector2(0, -3 * scale), box.size), radius,
                new Color32(39, 51, 35, 42));
            Tail(mesh, box, anchor, 8 * scale, border);
            Tail(mesh, box, Vector2.Lerp(anchor, box.center, .08f), 6.5f * scale, Color.white);
            Tail(mesh, box, Vector2.Lerp(anchor, box.center, .18f), 4.5f * scale, cream);
            Rounded(mesh, box, radius, border);
            Rounded(mesh, Inset(box, 1 * scale), radius - 1 * scale, Color.white);
            Rounded(mesh, Inset(box, 4 * scale), radius - 4 * scale, cream);
            if (happy)
            {
                var at = new Vector2(box.width - 20 * scale, box.height - 19 * scale);
                var rose = new Color32(191, 108, 100, 255);
                float heartScale = scale * heartPulse;
                Rounded(mesh, new Rect(at + new Vector2(-7, -1) * heartScale, Vector2.one * 8 * heartScale), 4 * heartScale, rose);
                Rounded(mesh, new Rect(at + new Vector2(-1, -1) * heartScale, Vector2.one * 8 * heartScale), 4 * heartScale, rose);
                Triangle(mesh, at + new Vector2(-7, 2) * heartScale, at + new Vector2(7, 2) * heartScale,
                    at + new Vector2(0, -8) * heartScale, rose);
            }
        }
        static Rect Inset(Rect box, float amount)
        { return new Rect(box.position + Vector2.one * amount, box.size - Vector2.one * 2 * amount); }
        static void Tail(VertexHelper mesh, Rect box, Vector2 anchor, float halfWidth, Color32 color)
        {
            if (anchor.x < 0 && anchor.y > 0 && anchor.y < box.height)
            {
                float y = Mathf.Clamp(anchor.y, 13, box.height - 13);
                Triangle(mesh, new Vector2(1, y - halfWidth), new Vector2(1, y + halfWidth), anchor, color);
            }
            else if (anchor.x > box.width && anchor.y > 0 && anchor.y < box.height)
            {
                float y = Mathf.Clamp(anchor.y, 13, box.height - 13);
                Triangle(mesh, new Vector2(box.width - 1, y - halfWidth), new Vector2(box.width - 1, y + halfWidth), anchor, color);
            }
            else
            {
                float x = Mathf.Clamp(anchor.x, 20, box.width - 20);
                float edge = anchor.y < 0 ? 1 : box.height - 1;
                Triangle(mesh, new Vector2(x - halfWidth, edge), new Vector2(x + halfWidth, edge), anchor, color);
            }
        }
        static void Triangle(VertexHelper mesh, Vector2 a, Vector2 b, Vector2 c, Color32 color)
        { int i = mesh.currentVertCount; mesh.AddVert(a, color, Vector2.zero); mesh.AddVert(b, color, Vector2.zero); mesh.AddVert(c, color, Vector2.zero); mesh.AddTriangle(i, i + 1, i + 2); }
        static void Rounded(VertexHelper mesh, Rect box, float radius, Color32 color)
        {
            int start = mesh.currentVertCount;
            mesh.AddVert(box.center, color, Vector2.zero);
            for (int corner = 0; corner < 4; corner++)
            {
                Vector2 center = new Vector2(corner == 0 || corner == 3 ? box.xMax - radius : box.xMin + radius, corner < 2 ? box.yMax - radius : box.yMin + radius);
                for (int step = 0; step <= 6; step++)
                {
                    float angle = (corner * 90 + step * 15) * Mathf.Deg2Rad;
                    mesh.AddVert(center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius, color, Vector2.zero);
                }
            }
            for (int i = 0; i < 28; i++) mesh.AddTriangle(start, start + 1 + i, start + 1 + (i + 1) % 28);
        }
    }
}
