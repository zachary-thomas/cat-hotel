using System;
using System.Linq;
using Newtonsoft.Json.Linq;
using Purrington.Domain;
using TMPro;
using UnityEngine;

namespace Purrington.Presentation
{
    // The Hotel tab's home layout from concept art 02: the hotel name with its level pill over the world,
    // and a "Next:" goal card with an icon tile, progress toward the next hotel level and a chevron that goes there.
    public sealed partial class HotelUI
    {
        public struct Goal { public string Icon, Headline, Caption; public float Progress; public bool ShowProgress; public string Target; }
        static readonly string[] ServiceNames = { "Rooms & housekeeping", "Kitchen & milkshakes", "Lounge & play", "Reception & arrivals" };

        // Every two service upgrades raise the hotel level (HotelModel: level = 1 + purchases / 2, capped at 10).
        public static Goal NextGoal(HotelModel model)
        {
            var h = model.Hotel();
            int level = h.level, done = h.purchases % 2;
            var goal = new Goal { ShowProgress = level < 10, Progress = done / 2f, Caption = level < 10 ? done + " / 2 upgrades to level " + (level + 1) : "Top hotel level reached" };
            // Small offline trickles stay in the details panel; only a meaningful sum becomes the headline goal.
            if (model.State.pendingCoins >= 25) { goal.Icon = "coin"; goal.Headline = "Collect " + Math.Floor(model.State.pendingCoins).ToString("N0") + " coins"; goal.Target = "collect"; return goal; }
            var notReady = model.State.rooms.FirstOrDefault(r => r.floor >= 0 && r.kind != "stairs" && r.kind != "garden" && r.kind != "terrace" && !model.IsRoomReady(r));
            if (notReady != null) { goal.Icon = "bed"; goal.Headline = "Next: Get " + notReady.name + " ready"; goal.Target = "build"; return goal; }
            if (level >= 10) { goal.Icon = "crown"; goal.Headline = "Meadow House is complete"; goal.Target = "life"; return goal; }
            int cheapest = 0; double best = double.MaxValue;
            for (int i = 0; i < 4; i++) { if (h.upgrades[i] >= 10) continue; var q = model.Quote("upgrade", new JObject { { "service", i } }); if (q.cost < best) { best = q.cost; cheapest = i; } }
            goal.Icon = "sofa"; goal.Headline = "Next: Upgrade " + ServiceNames[cheapest]; goal.Target = "upgrade";
            return goal;
        }

        void OpenGoal(string target)
        {
            if (target == "collect") { var result = app.Model.ClaimOffline(); app.Report(result); if (result.success) app.Audio?.PlayEffect("collect"); Rebuild(); }
            else if (target == "build") Navigate("Build");
            else if (target == "upgrade") { lifeFocus = "manager"; Navigate("Life"); }
            else Navigate("Life");
        }

        // Compact goal card content inside the Hotel overview panel's top area (height `area`).
        void GoalCard(RectTransform panel, float area)
        {
            var goal = NextGoal(app.Model);
            var tile = Panel("Goal icon", panel, Mint);
            float tileSize = Mathf.Min(area - 16, 52);
            Pin(tile, new Vector2(0, 1), new Vector2(0, 1), new Vector2(0, 1), new Vector2(10, -8 - tileSize), new Vector2(10 + tileSize, -8));
            GoalIcon(tile, goal.Icon);
            var headline = Text(panel, goal.Headline, 15, Ink, true); headline.enableAutoSizing = true; headline.fontSizeMin = 10 * textScale; headline.fontSizeMax = 15 * textScale; headline.textWrappingMode = TextWrappingModes.NoWrap; headline.overflowMode = TextOverflowModes.Ellipsis;
            Pin(headline.rectTransform, new Vector2(0, 1), Vector2.one, new Vector2(0, 1), new Vector2(20 + tileSize, -8 - area * .45f), new Vector2(-56, -6));
            if (goal.ShowProgress)
            {
                var track = Panel("Goal progress", panel, Mint);
                Pin(track, new Vector2(0, 1), Vector2.one, new Vector2(0, 1), new Vector2(20 + tileSize, -area * .62f), new Vector2(-60, -area * .62f + 8));
                var fill = Panel("Goal progress fill", track, ConceptTheme.Ui.Leaf);
                fill.anchorMin = Vector2.zero; fill.anchorMax = new Vector2(Mathf.Clamp01(goal.Progress), 1); fill.offsetMin = fill.offsetMax = Vector2.zero;
                fill.gameObject.SetActive(goal.Progress > 0);
            }
            var caption = Text(panel, goal.Caption, 11, InkSoft); caption.textWrappingMode = TextWrappingModes.NoWrap; caption.overflowMode = TextOverflowModes.Ellipsis;
            Pin(caption.rectTransform, new Vector2(0, 1), Vector2.one, new Vector2(0, 1), new Vector2(20 + tileSize, -area + 4), new Vector2(-56, -area * .66f));
            var go = Button(panel, "", () => OpenGoal(goal.Target), CardTone, 12); go.name = "Goal chevron";
            Pin(go, new Vector2(1, 1), new Vector2(1, 1), new Vector2(1, 1), new Vector2(-50, -area / 2 - 22), new Vector2(-6, -area / 2 + 22));
            // A drawn chevron (two stepped bars) so it never depends on a font glyph or the text scale.
            for (int i = 0; i < 4; i++) foreach (int sign in new[] { 1, -1 }) { if (sign < 0 && i == 0) continue; var step = Rect("Chevron step", go); step.anchorMin = step.anchorMax = step.pivot = new Vector2(.5f, .5f); step.sizeDelta = new Vector2(4, 4); step.anchoredPosition = new Vector2(3 - i * 2.5f, sign * i * 3.2f); var img = step.gameObject.AddComponent<UnityEngine.UI.Image>(); img.color = Ink; img.raycastTarget = false; }
        }

        // Small voxel glyphs drawn from rects, in the same style as the navigation icons.
        void GoalIcon(RectTransform tile, string icon)
        {
            var art = Rect(icon + " glyph", tile); art.anchorMin = art.anchorMax = art.pivot = new Vector2(.5f, .5f); art.sizeDelta = new Vector2(28, 24); art.anchoredPosition = Vector2.zero;
            void B(float x, float y, float w, float hgt, Color c) { var r = Rect("Block", art); r.anchorMin = r.anchorMax = r.pivot = Vector2.zero; r.anchoredPosition = new Vector2(x, y); r.sizeDelta = new Vector2(w, hgt); var img = r.gameObject.AddComponent<UnityEngine.UI.Image>(); img.color = c; img.raycastTarget = false; }
            var leaf = ConceptTheme.Ui.Leaf;
            if (icon == "coin") { B(6, 2, 16, 20, Coin); B(2, 6, 24, 12, Coin); B(10, 8, 8, 8, ConceptTheme.Ui.CoinRim); }
            else if (icon == "bed") { B(2, 2, 24, 4, leaf); B(2, 6, 4, 14, leaf); B(6, 6, 20, 7, leaf); B(7, 13, 7, 4, CardTone); }
            else if (icon == "crown") { B(3, 3, 22, 8, Coin); B(3, 11, 4, 9, Coin); B(12, 11, 4, 11, Coin); B(21, 11, 4, 9, Coin); }
            else { B(3, 3, 22, 7, leaf); B(3, 10, 5, 8, leaf); B(20, 10, 5, 8, leaf); B(8, 10, 12, 11, leaf); B(3, 1, 3, 3, Ink); B(22, 1, 3, 3, Ink); }
        }

        // The hotel's name over the world, with its level pill, as in concept art 02.
        void HomeTitle()
        {
            if (careCat >= 0 || welcome) return;
            float safeWidth = ((RectTransform)safe).rect.width;
            float w = wideLayout ? 280 : Mathf.Clamp(safeWidth - 206, 120, 240);
            var block = Rect("Hotel title", safe);
            Pin(block, Vector2.one, Vector2.one, Vector2.one, new Vector2(-10 - w, -140), new Vector2(-10, -68));
            if (wideLayout) Pin(block, new Vector2(.5f, 1), new Vector2(.5f, 1), new Vector2(.5f, 1), new Vector2(-w / 2, -134), new Vector2(w / 2, -68));
            var name = Text(block, (string)app.Model.Map()["name"], 26, Ink, true);
            name.alignment = TextAlignmentOptions.Right; if (wideLayout) name.alignment = TextAlignmentOptions.Center;
            name.enableAutoSizing = true; name.fontSizeMin = 14; name.fontSizeMax = 26 * textScale; name.textWrappingMode = TextWrappingModes.NoWrap;
            name.outlineWidth = .22f; name.outlineColor = new Color32(251, 246, 233, 255);
            Pin(name.rectTransform, new Vector2(0, 1), Vector2.one, new Vector2(.5f, 1), new Vector2(0, -38), Vector2.zero);
            var pill = Panel("Hotel level pill", block, CardTone);
            float pillW = Mathf.Min(w, 108 * textScale), pillH = 24 * Mathf.Max(1, textScale * .85f);
            if (wideLayout) Pin(pill, new Vector2(.5f, 0), new Vector2(.5f, 0), new Vector2(.5f, 0), new Vector2(-pillW / 2, 2), new Vector2(pillW / 2, 2 + pillH));
            else Pin(pill, new Vector2(1, 0), new Vector2(1, 0), new Vector2(1, 0), new Vector2(-pillW, 2), new Vector2(0, 2 + pillH));
            var level = Text(pill, "Hotel level " + app.Model.Hotel().level, 12, LeafText, true); level.alignment = TextAlignmentOptions.Center; level.enableAutoSizing = true; level.fontSizeMin = 8; level.fontSizeMax = 12 * textScale; level.textWrappingMode = TextWrappingModes.NoWrap; Stretch(level.rectTransform, 6, 1, 6, 1);
        }
    }
}
