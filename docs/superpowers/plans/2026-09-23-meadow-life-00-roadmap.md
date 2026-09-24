# Meadow Life roadmap: the manager, neighbors, events and a Sims-style build mode

September 23, 2026 · Unity only · Meadow House (map 0) only; the other destinations come later.

## Goal

Make Purrington feel more like The Sims and Animal Crossing:
- In Life, you control the manager cat directly. Tap somewhere and it walks there. Tap a cat to chat.
- The manager can walk into town, meet neighbors, become friends with them, take on their requests, and host events in the plaza.
- Build mode gets the direct, hands-on tools The Sims is known for.

**Core loop:** town gives reasons to build, and building gives reasons to go to town. Neighbors ask for rooms and items. Events need props and bring guests. Good rooms bring guests who introduce new neighbors.

## Decisions (from the user, 2026-09-23)

- **The hotel keeps earning** while the manager is in town, in a shop, at an event or on a trip. Nothing pauses and nothing is penalized.
- **The manager has no needs.** No hunger, energy or mood meters.
- **Conversations work like Animal Crossing.** The player picks a topic from icon bubbles, and the cat answers with a written line. Lines are snappy, witty and entertaining (see the writing guide below).
- **Meadow only for now.** All neighbors, requests, events and exploration happen on the Meadow map. The data is keyed by map so other destinations can be added later.
- **Saves are disposable,** so schema changes just start a new save. `StrictSaveJson` and `HotelModel.Valid` still have to accept and check every new field, and each one needs a domain test.

## What already exists

- **Manager:** `HotelState.managerName/Coat/Markings/Outfit`. Its position is in `HotelData.town` (`x`, `z`, `phase` hotel|street, `destination`, `shop`).
- **Movement:** `SendManager`, `AdvanceManager` and `BuildManagerRoute` (`HotelTown.cs`) handle hotel → gate → street. `TownRoute` is a small node graph (`MainStreet.json`: `hotel_gate`, `crosswalk`, `square`, two shop doors).
- **Town mode:** `VoxelWorld.EnterTownMode`, `FocusManager` and `SelectTownGround` (`VoxelWorldTown.cs`). "Explore Main Street" opens it. Shop interiors are in `StoreInteriorView`.
- **Quests and events:** Welcome Picnic, First Look and Market Day (`TownEvent.cs`, `TownCommerce.cs`).
- **Relationships:** `CatState.bond` (0–100), `friend` and `preference`. `FriendScore` pulls friends toward each other. Items can be gated by bond.
- **Speech and care:** `CatSpeechOverlay` and `VoxelWorldSpeech` for world speech bubbles. `SetCareMode(catId)` for hands-on petting.
- **Build:** the Build tab now has modes, a floor rail and guided tools (`557dfe4`). `SurfacePalette` holds the wall and floor colors.

## Phases

| # | Phase | Plan | Status | Depends on |
|---|---|---|---|---|
| 1 | **The manager in Life:** tap to move, pie menu, topic chats with guests | [01-manager](2026-09-23-meadow-life-01-manager.md) | Done 2026-09-24 | nothing |
| 2 | **Neighbors and friendship** | [02-neighbors](2026-09-24-meadow-life-02-neighbors.md) | Done 2026-09-24 | 1 (chat system) |
| 3 | **Requests, rumors and the Meadow outskirts** | [03-requests-rumors](2026-09-24-meadow-life-03-requests-rumors.md) | Done 2026-09-24 (build requests count furniture groups; the B3 vibe score can replace them later) | 2 |
| 4 | **Plaza events** (general event system) | [04-plaza-events](2026-09-24-meadow-life-04-plaza-events.md) | Done 2026-09-24 (Market Day kept as is, beside three new events; prop slots not built) | 2 |
| B1 | **Build: pick up and carry, walls up/cutaway/down** | (inline, no separate plan) | Done 2026-09-24 (press-and-drag a furnishing to carry it, dropped on release; new buys drag the ghost but still confirm with Place; walls toggle sits under the floor rail) | nothing (Presentation) |
| B2 | **Build: paint and eyedropper for walls, floors and item colors** | (inline) | Done 2026-09-24 (8 wall and 8 floor swatches per room, 5 item tints; `paint_room`/`tint_object` commands with undo; tap-to-paint, eyedropper; Paint & style tile under Walls & doors) | B1 |
| B3 | **Build: room vibe score and saved room blueprints** | (inline) | Done 2026-09-24 (Cozy/Lively/Calm 0–100% with one tip, shown on room selection and room tiles; guests favor matching vibes in painted rooms only, which keeps the Godot parity baseline; up to 12 saved designs under Furnish → Sets via `place_blueprint`; build requests still count furniture groups) | B1 |

The build track (B) mostly touches different files from phases 1–4, so it can run in parallel after phase 1 lands. It shares `HotelUI.cs`, so run it in its own worktree and merge often.

---

### Phase 1: The manager in Life

Full detail is in the [phase 1 plan](2026-09-23-meadow-life-01-manager.md). In short:
- The manager is always on the Meadow map. In Life, tapping the ground walks the manager there, whether that's inside the hotel on any floor, the lawn, or the street.
- Tapping a guest cat opens a **pie menu** of icon bubbles: **Chat**, **Pet** (opens the existing care mode), **Follow** and **Cancel**.
- **Chat:** the manager walks up and the guest stops and turns to face them. Three **topic bubbles** fan out, and the guest answers with a line that types out with a blip for each letter. How much the guest likes the topic changes `bond`.
- An action queue holds up to 3 actions. A Follow-manager toggle is available. "Explore Main Street" becomes a shortcut that walks the manager to the gate and follows it.

### Phase 2: Neighbors and friendship

- **Six neighbors** live in the houses around the square. Each is an authored cat with a coat, markings, a signature accessory, a personality, 2 liked topics, 1 disliked topic, a favorite gift and a daily schedule tied to the `DayCycle` hours (home, Paw Mart, square bench, fountain, hotel lounge).

  | Neighbor | Personality | Likes | Dislikes | Hook |
  |---|---|---|---|---|
  | **Marmalade** | Peppy baker | Snacks, Play | Naps | Runs the kiosk on Market Day |
  | **Sir Reginald Floofington III** | Snooty retired opera star | Hotel, Gossip | Play | Judges your lobby out loud |
  | **Pickles** | Sporty jogger | Play, Weather | Naps | Laps the square at dawn |
  | **Old Tom** | Grumpy fisherman | Snacks, Weather | Gossip | Softens up at Best Friend |
  | **Juniper** | Dreamy stargazer and gardener | Weather, Naps | Hotel | Only out after dusk and at dawn |
  | **Dot** | Bookish librarian (tuxedo) | Gossip, Hotel | Weather | Hands out rumors (phase 3) |

- **Friendship** runs from 0 to 100 per neighbor, in tiers: Stranger (0), Acquaintance (15), Friend (40), Best Friend (75).
  - Each neighbor counts toward friendship at most 3 times per game day. Later chats still get lines but give no points.
  - Tier-ups get a unique line and a hearts burst.
- **Gifts:** buy them at Paw Mart and give them from the pie menu. Favorite gifts count the most, and one gift per neighbor per day counts.
- **Tier rewards:**
  - Acquaintance: the neighbor books a stay and turns up as a named guest, using the existing guest system.
  - Friend: gives a furniture blueprint or wear item and starts sending requests (phase 3).
  - Best Friend: a 3-step personal story chain and a framed photo item for the hotel.
- **Town graph:** add nodes for each house door, the benches, the fountain and the notice board. Neighbors walk the same graph and replace some of the anonymous `NeighborhoodView` walkers.
- **UI:** a Neighbors page in the Cats tab. Each neighbor gets a portrait, tier hearts, what you've learned about their likes (these start as "?" and fill in as you chat, like Animal Crossing) and where they are right now.
- **Save:** `HotelData.neighbors`: `id`, `friendship`, `chatsToday`, `chatDay`, `giftDay`, `known`, `flags`. The content lives in `Resources/Content/Neighbors.json`.

### Phase 3: Requests, rumors and the Meadow outskirts

- **Neighbor requests.** Each Friend+ neighbor can have 1 open request. The notice board in the square shows up to 3. They refresh once per game day. There are three kinds:
  - **Fetch:** "Old Tom wants a tin of sardines from Paw Mart." Buy it and give it.
  - **Build:** "Juniper wants a room with 3 plants and a window seat." Checked against the hotel state, using the venue tags and the B3 vibe score.
  - **Social:** "Introduce Pickles to a guest who likes Play." Chat with the right guest while the neighbor is nearby.

  Rewards: coins, friendship, and sometimes an item. Welcome Picnic and First Look become story requests in this system.
- **Rumors** are the random quests. Dot, or whichever Friend+ neighbor you're talking to, sometimes offers a rumor instead of a line, for example: "Heard a kitten mewing by the old oak. Probably nothing. Probably a kitten." Accepting it puts a marker in the **Meadow outskirts**. The manager walks there and finds the thing by tapping (a kitten, a lost item, a buried treasure). Finishing a rumor unlocks a new guest cat, an item or coins.
- **Meadow outskirts:** 3 small new spots at the edges of the Meadow map, each connected to the street graph by a path:
  - **Old Oak**
  - **Lily Pond**
  - **Hilltop Lookout** (good at sunset and at night)

  First confirm there is room inside the Meadow bounds of `GodotGeometry.json` plus the Unity-side additions. If there isn't, extend the map in a new Unity content file rather than re-exporting from Godot.

### Phase 4: Plaza events

Market Day becomes a general **event system**:

1. **Pick** an event at the notice board. The first three:
   - **Market Day** (the existing one)
   - **Movie Night** (evening only; uses night lighting and lamps)
   - **Nap-a-thon**
2. **Invite** neighbors. Whether each one attends depends on friendship and on whether the event matches their likes. Attendees also bring anonymous shoppers.
3. **Decorate** the six plaza prop slots from a small event prop kit. It's a simple picker, not the full build tools. Props also count toward Buzz.
4. **Host** for 90–120 seconds of game time. Chatting with attendees during the event fills a **Buzz** meter.
5. **Payoff** in bronze, silver or gold: coins, a wave of hotel guests, friendship for attendees, and an event-exclusive prop or wear item. One event per game day. The hotel keeps earning throughout.

Save: `town.eventRemaining`, `town.marketCompletionSerial` and `town.welcomeKind` become a general `town.activeEvent {id, remaining, buzz, props[], attendees[]}` plus `town.eventDay`.

### Build track

- **B1: pick up and carry.**
  - Tapping a placed item picks it up. It follows your finger with validity coloring (green or red footprint) and drops where you release. It has an optional grid snap and rotates with a two-finger twist or the Rotate button.
  - Walls up/cutaway/down is a three-state toggle in the Build header. It works with the fixed isometric camera.
- **B2: paint.**
  - A paint tool for walls and floors, using swatches from `SurfacePalette`. Tap to paint one surface, or drag to fill a room.
  - An eyedropper picks up a color. Items with a `color` role get 3–4 swatch variants, a small version of The Sims' Create-a-Style.
- **B3: vibe and blueprints.**
  - Each room gets a **vibe score** (Cozy, Lively or Calm, from 0 to 100%), worked out from item tags, light, plants, crowding and paint harmony. It shows as a chip on the room with one tip, for example: "Cozy 64% · add a warm light." Guests with matching preferences favor high-vibe rooms. Build requests use the score.
  - **Saved blueprints:** save a decorated room and place a copy of it later, extending Arrangements.

---

## Dialogue writing guide

The chats are the heart of this. Write every line against these rules:

- **Short:** 80 characters or fewer, so a line fits in two bubble lines at 360 px width and 150% text. No line should need scrolling.
- **One joke per line.** Deadpan beats punny. Cat puns at most once every 5 lines. No "purr-fect".
- **Every line has a point of view.** It shows who the cat is. A generic line fails the check.
- **The kindness floor:** dislike lines are cranky or huffy, never mean to the player.
- **Line sets by reaction:** each topic has **love**, **like**, **meh** and **dislike** lines. Reaction icons pop over the head: ❤️ love, ✨ like, 💭 meh, 💢 dislike.
- **Topics** have fixed icons: 🐟 Snacks, 💤 Naps, 🧶 Play, 💬 Gossip, ☀️ Weather, 🏨 Hotel. They're drawn as UI sprites, not emoji glyphs. A chat offers 3 of the 6 at random, plus Bye.

Samples that set the tone:

| Who | Topic | Reaction | Line |
|---|---|---|---|
| Guest (likes food) | Snacks | love | "Is it a snack if you eat it lying down? Asking for me." |
| Guest (likes naps) | Naps | love | "I napped so hard I woke up in a different sunbeam." |
| Guest (likes play) | Weather | meh | "Weather's fine. Is it chasing weather, though?" |
| Guest | Hotel | like | "The lobby smells like fresh towels and ambition." |
| Marmalade | Play | love | "Race you to the fountain! ...I already started. I'm winning!" |
| Marmalade | Naps | dislike | "Naps are just waiting with your eyes closed. Unacceptable." |
| Sir Reginald | Hotel | love | "Your lobby has potential. Like a tenor with a head cold." |
| Sir Reginald | Play | dislike | "I do not 'play.' I perform. There is a difference, darling." |
| Pickles | Naps | dislike | "Naps? I did forty laps before breakfast. Breakfast was a lap." |
| Old Tom | Weather | like | "Sunny. Great. Now the fish can see me coming." |
| Old Tom | Gossip | dislike | "Gossip's like bait. Smells bad and something always bites." |
| Juniper | Weather | love | "The clouds today look like they're thinking about us." |
| Dot | Gossip | love | "I only deal in verified rumors. Cite your sources, please." |
| Dot | Weather | dislike | "Weather is just the sky being dramatic. Next topic." |

**Line counts:**
- Phase 1: about 72 guest lines, 6 topics × 4 reactions × 3 variants, chosen by the guest's `preference`. Plus 6 lines for when a guest is too busy to talk.
- Phase 2: 16 or more lines per neighbor (their likes and dislikes, a generic pool, tier-up lines, schedule-aware lines such as "Pickles, mid-lap: 'Can't talk, cardio.'").

Lines live in content JSON, never in code. Picking a line is deterministic (hash of game day, cat, topic and chat count), so domain tests can assert exact lines, and the same moment replays the same way.

## Rules for every phase

- Domain first: plain C# commands in `HotelModel`, tested in `tests/unity-domain` (`PASS <n> checks`), then Presentation. Presentation never grants coins, bond or items.
- The camera stays on the fixed isometric angle. Every motion cue respects `settings.motion`. Touch targets work at 360×640 with 150% text.
- Each phase ends with `.\tools\unity-bridge.ps1 test`, a `capture -Tab Life` screenshot of the new feature, and one final review (lean process).
- Don't touch the Godot oracle section of the harness.
