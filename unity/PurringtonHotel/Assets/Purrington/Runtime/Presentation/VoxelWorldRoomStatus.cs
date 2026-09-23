using System.Collections.Generic;
using Purrington.Domain;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace Purrington.Presentation
{
    public sealed partial class VoxelWorld
    {
        RoomStatusBadges roomStatusBadges;

        void UpdateRoomStatusBadges()
        {
            if (roomStatusBadges == null) roomStatusBadges = new RoomStatusBadges(transform);
            roomStatusBadges.Sync(model);
            roomStatusBadges.Position(WorldCamera, rooms, VisibleWorldRect(),
                !care && !blocked && WorldCamera.enabled, model.State.settings.motion);
        }
    }

    // Screen-space labels stay legible above roofs without becoming world input targets.
    sealed class RoomStatusBadges
    {
        sealed class Badge
        {
            public RoomState room;
            public RectTransform panel;
            public CanvasGroup fade;
            public CatSpeechShape shape;
            public TextMeshProUGUI label;
            public string status;
            public float appearedAt;
            public float dismissedAt = -1;
        }

        readonly Canvas canvas;
        readonly TMP_FontAsset font;
        readonly Dictionary<string, Badge> badges = new Dictionary<string, Badge>();
        readonly HashSet<string> wanted = new HashSet<string>();
        readonly List<string> stale = new List<string>();
        readonly List<Rect> placed = new List<Rect>();
        readonly List<Vector2> candidates = new List<Vector2>();
        float textScale = 1;

        public RoomStatusBadges(Transform parent)
        {
            var root = new GameObject("Room status badges", typeof(RectTransform), typeof(Canvas));
            root.transform.SetParent(parent, false);
            canvas = root.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 12;
            font = Resources.Load<TMP_FontAsset>("Fonts/Nunito SDF");
            // No GraphicRaycaster: a room badge cannot intercept a placement tap.
        }

        public void Sync(HotelModel model)
        {
            wanted.Clear();
            textScale = Mathf.Clamp(model.State.settings.textScale, 1, 1.5f);
            foreach (var room in model.State.rooms)
            {
                var info = model.RoomStatus(room.id);
                if (info.ready)
                {
                    if (badges.TryGetValue(room.id, out var finished) && finished.dismissedAt < 0)
                        finished.dismissedAt = Time.unscaledTime;
                    continue;
                }
                wanted.Add(room.id);
                if (!badges.TryGetValue(room.id, out var badge))
                {
                    badge = Create(room.id);
                    badges.Add(room.id, badge);
                }
                badge.room = room;
                badge.dismissedAt = -1;
                if (badge.status != info.status)
                {
                    badge.status = info.status;
                    badge.label.text = info.status;
                    badge.appearedAt = Time.unscaledTime;
                }
            }
            stale.Clear();
            foreach (var entry in badges)
            {
                if (wanted.Contains(entry.Key)) continue;
                if (entry.Value.dismissedAt < 0) entry.Value.dismissedAt = Time.unscaledTime;
                if (!model.State.settings.motion || Time.unscaledTime - entry.Value.dismissedAt >= .18f)
                    stale.Add(entry.Key);
            }
            foreach (var id in stale)
            {
                badges[id].panel.gameObject.SetActive(false);
                Object.Destroy(badges[id].panel.gameObject);
                badges.Remove(id);
            }
        }

        Badge Create(string id)
        {
            var panel = new GameObject("RoomStatus_" + id, typeof(RectTransform), typeof(CanvasGroup)).GetComponent<RectTransform>();
            panel.SetParent(canvas.transform, false);
            panel.anchorMin = panel.anchorMax = panel.pivot = Vector2.zero;
            var fade = panel.GetComponent<CanvasGroup>();
            fade.blocksRaycasts = false;
            fade.interactable = false;
            var shape = panel.gameObject.AddComponent<CatSpeechShape>();
            shape.raycastTarget = false;

            var label = new GameObject("Reason", typeof(RectTransform), typeof(TextMeshProUGUI)).GetComponent<TextMeshProUGUI>();
            label.transform.SetParent(panel, false);
            label.font = font;
            label.color = new Color32(134, 80, 46, 255);
            label.alignment = TextAlignmentOptions.Center;
            label.textWrappingMode = TextWrappingModes.NoWrap;
            label.overflowMode = TextOverflowModes.Ellipsis;
            label.raycastTarget = false;
            label.rectTransform.anchorMin = Vector2.zero;
            label.rectTransform.anchorMax = Vector2.one;
            label.rectTransform.offsetMin = new Vector2(13, 6);
            label.rectTransform.offsetMax = new Vector2(-13, -6);
            return new Badge { panel = panel, fade = fade, shape = shape, label = label, appearedAt = Time.unscaledTime };
        }

        public void Position(Camera camera, IDictionary<string, Transform> rooms, Rect worldArea, bool visible, bool motion)
        {
            if (!visible || worldArea.width < 110 || worldArea.height < 40)
            {
                foreach (var badge in badges.Values) badge.panel.gameObject.SetActive(false);
                return;
            }
            var area = Rect.MinMaxRect(worldArea.xMin + 6, worldArea.yMin + 6, worldArea.xMax - 6, worldArea.yMax - 6);
            placed.Clear();
            foreach (var badge in badges.Values)
            {
                if (!rooms.TryGetValue(badge.room.id, out var root) || !root)
                {
                    badge.panel.gameObject.SetActive(false);
                    continue;
                }
                HotelModel.RoomSize(badge.room, out float width, out float depth);
                float height = Mathf.Max(4.5f, 3.4f + Mathf.Ceil(width * VoxelWorld.Unit * .48f) * .17f);
                var world = root.TransformPoint(new Vector3(width * VoxelWorld.Unit * .5f, height, depth * VoxelWorld.Unit * .5f));
                var screen = camera.WorldToScreenPoint(world);
                if (screen.z <= 0 || !Rect.MinMaxRect(area.xMin - 60, area.yMin - 60, area.xMax + 60, area.yMax + 60).Contains(screen))
                {
                    badge.panel.gameObject.SetActive(false);
                    continue;
                }
                badge.label.fontSize = 15 * textScale;
                var preferred = badge.label.GetPreferredValues(badge.status, 1000, 1000);
                var size = new Vector2(Mathf.Min(preferred.x + 26, area.width - 4), preferred.y + 14);
                float ui = Mathf.Clamp(Screen.width / 390f, .9f, 1.3f);
                candidates.Clear();
                candidates.Add(new Vector2(screen.x - size.x * .5f, screen.y - size.y - 10 * ui));
                candidates.Add(new Vector2(screen.x - size.x * .5f, screen.y + 10 * ui));
                candidates.Add(new Vector2(screen.x + 10 * ui, screen.y - size.y * .5f));
                candidates.Add(new Vector2(screen.x - size.x - 10 * ui, screen.y - size.y * .5f));
                if (!CatSpeechOverlay.TryPlace(size, area, candidates, placed, out var box))
                {
                    badge.panel.gameObject.SetActive(false);
                    continue;
                }
                if (!badge.panel.gameObject.activeSelf) badge.appearedAt = Time.unscaledTime;
                float entrance = motion ? Mathf.Clamp01((Time.unscaledTime - badge.appearedAt) / .32f) : 1;
                float settle = 1 - Mathf.Pow(1 - entrance, 3);
                float hop = motion ? Mathf.Sin(entrance * Mathf.PI) * (1 - entrance) * 3 * ui : 0;
                var position = new Vector2(Mathf.Round(box.x), Mathf.Round(box.y)) +
                    Vector2.up * (-8 * ui * (1 - settle) + hop);
                badge.panel.sizeDelta = size;
                badge.panel.anchoredPosition = position;
                badge.shape.Configure((Vector2)screen - position, false, ui, true);
                float departure = badge.dismissedAt < 0 ? 1 :
                    1 - Mathf.Clamp01((Time.unscaledTime - badge.dismissedAt) / .18f);
                badge.fade.alpha = (motion ? Mathf.SmoothStep(0, 1, Mathf.Clamp01(entrance * 1.6f)) : 1) * departure;
                badge.panel.gameObject.SetActive(true);
                placed.Add(box);
            }
        }
    }
}
