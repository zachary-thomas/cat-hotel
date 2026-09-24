# Meadow Life phase 4: plaza events

September 24, 2026 · Unity only · Meadow (map 0) · [roadmap](2026-09-23-meadow-life-00-roadmap.md)

**Goal:** the player hosts events in the square. Neighbors who like the theme, or like the manager, turn up. Chatting with them fills a Buzz meter, and Buzz sets the payoff.

## Decisions

- **Market Day stays as it is,** with its bundle, kiosks and hotel welcome. The new system runs next to it, and the two can't overlap.
- **Three new events** in `Events.json`:

  | Event | Topic | Hours | Hosting fee | Gold item |
  |---|---|---|---|---|
  | Movie Night | gossip | 18:00–23:59 | 80 coins | Amber lantern |
  | Nap-a-thon | naps | 10:00–16:00 | 60 coins | Sunshine cushion |
  | Yarn Festival | play | 08:00–18:00 | 100 coins | Play tunnel |

  Every event lasts 120 seconds of game time. One plaza event per game day.
- **Attendance** is decided when the event starts. A neighbor comes if they're out at that hour and either love or like the topic, or are a Friend or closer. Anyone who dislikes the topic stays away unless they're a Best Friend. Attendees stand in a ring around the square node, so the manager can chat with all of them from the middle.
- **Buzz** runs from 0 to 100:
  - +1 every 4 seconds for each attendee
  - chatting with an attendee during the event: love +20, like +15, meh +8
  - a gift to an attendee: +15
- **Payoff:**
  - Bronze (under 40 Buzz): 80 coins
  - Silver (40 or more): 180 coins and +3 friendship for each attendee
  - Gold (80 or more): 320 coins, +6 friendship for each attendee, a new guest cat if one is still unmet, and the event's gold item in storage

  Tier rewards from the friendship gain pay out as usual. The hotel keeps earning throughout.
- **Save:** `TownState` gains `plazaEvent`, `plazaRemaining`, `plazaBuzz`, `plazaDay`, `plazaAttendees`, `plazaSerial` and `plazaResult`.

## Tasks

1. `Events.json` and a `PlazaContent` loader. Domain in `HotelPlaza.cs`: host checks, attendance, the Buzz tick, Buzz from chat and gifts, payoff, neighbor positions during events, validation, domain tests.
2. Presentation:
   - an event plan sheet (reached from the Life HUD's event row)
   - props on the square for each event
   - attendee poses (napping at the Nap-a-thon)
   - the Buzz row in the HUD
   - a result banner
3. EditMode tests and bridge screenshots of each event in progress.
