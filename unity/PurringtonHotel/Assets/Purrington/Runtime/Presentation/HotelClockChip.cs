using Purrington.Domain;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace Purrington.Presentation
{
    // "Day 3 · 10:30" with a sun/moon glyph; refreshes once per in-game minute.
    public sealed class HotelClockChip : MonoBehaviour
    {
        HotelModel model; TextMeshProUGUI label; Image sun, moon; bool compact; int lastMinute = -1, lastDay = -1;

        public void Bind(HotelModel model, TextMeshProUGUI label, Image sun, Image moon, bool compact)
        { this.model = model; this.label = label; this.sun = sun; this.moon = moon; this.compact = compact; lastMinute = -1; Update(); }

        public static float MoonAmount(float daylight) => 1f - Mathf.Clamp01(daylight * 1.6f);

        void Update()
        {
            if (model == null) return;
            var c = model.Clock; int minute = (int)c.minute;
            if (minute == lastMinute && c.day == lastDay) return;
            lastMinute = minute; lastDay = c.day;
            label.text = HotelClock.Label(c, compact);
            float m = MoonAmount(c.daylight);
            var s = sun.color; s.a = 1 - m; sun.color = s;
            var n = moon.color; n.a = m; moon.color = n;
        }
    }
}
