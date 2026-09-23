using System;

namespace Purrington.Domain
{
    public enum DayPhase { Dawn, Day, Dusk, Night }

    public readonly struct ClockReading
    {
        public readonly int day;
        public readonly float minute;
        public readonly DayPhase phase;
        public readonly float daylight;
        public ClockReading(int day, float minute, DayPhase phase, float daylight) { this.day = day; this.minute = minute; this.phase = phase; this.daylight = daylight; }
        public int Hour => (int)(minute / 60);
        public int MinuteOfHour => (int)minute % 60;
    }

    // Time of day is derived from played seconds, so it needs no save field and pauses while the app is closed.
    public static class HotelClock
    {
        public const float DayLengthSeconds = 1440f, StartMinute = 480f;
        public const float DawnStart = 300f, DayStart = 450f, DuskStart = 1050f, NightStart = 1200f;
        public const float Sunrise = 270f, Sunset = 1230f;

        public static ClockReading Read(double elapsed)
        {
            if (double.IsNaN(elapsed) || double.IsInfinity(elapsed) || elapsed < 0) elapsed = 0;
            double total = StartMinute + elapsed;
            double days = Math.Floor(total / DayLengthSeconds);
            float minute = (float)(total - days * DayLengthSeconds);
            if (minute < 0 || minute >= DayLengthSeconds) minute = 0;
            int day = days >= int.MaxValue - 1 ? int.MaxValue : (int)days + 1;
            return new ClockReading(day, minute, PhaseAt(minute), Daylight(minute));
        }

        public static DayPhase PhaseAt(float minute) =>
            minute < DawnStart || minute >= NightStart ? DayPhase.Night :
            minute < DayStart ? DayPhase.Dawn :
            minute < DuskStart ? DayPhase.Day : DayPhase.Dusk;

        public static float Daylight(float minute)
        {
            if (minute <= Sunrise || minute >= Sunset) return 0;
            return (float)Math.Pow(Math.Sin(Math.PI * (minute - Sunrise) / (Sunset - Sunrise)), .6);
        }

        // Compact (portrait phones) stacks "Day N" over the time so both fit a narrow chip.
        public static string Label(ClockReading r, bool compact)
        {
            string time = r.Hour.ToString("00") + ":" + r.MinuteOfHour.ToString("00");
            return "Day " + r.day + (compact ? "\n" : " · ") + time;
        }
    }

    public sealed partial class HotelModel { public ClockReading Clock => HotelClock.Read(State.elapsed); }
}
