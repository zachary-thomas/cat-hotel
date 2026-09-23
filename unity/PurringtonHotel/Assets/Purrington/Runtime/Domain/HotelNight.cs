namespace Purrington.Domain
{
    // Night only changes where guests go and how long they sleep; income, capacity and room status never read the clock.
    public sealed partial class HotelModel
    {
        bool SunClosed => Clock.daylight < .25f;
        bool VisitorsResting => Clock.phase == DayPhase.Night;
        double NightPreference(VenueSnapshot v)
        {
            if (Clock.phase != DayPhase.Night) return 0;
            return v.role == "bed" ? 50 : v.role == "seat" || v.role == "warm" ? 3 : 0;
        }
        float SleepDuration(Actor a) => Clock.phase == DayPhase.Night ? 90 + StableHash(a.view.id ?? "") % 61u : 11;
        bool NightNap(string phase, string action) => phase == "activity" && action == "sleep" && Clock.phase == DayPhase.Night;
    }
}
