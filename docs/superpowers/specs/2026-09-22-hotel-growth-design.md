# Purrington Hotel: growing the hotel (shell, floors, wardrobe)

September 22, 2026 · Unity (`unity/PurringtonHotel`) · brainstormed with the user in-session.

## Why

Players said three things about the current Meadow hotel:

1. **The owned lot's grass doesn't match the world.** The Meadow lot renders a flat, saturated green next to the muted sage of the concept-graded world. Other maps drift less but should be checked.
2. **Expansion is unsatisfying (A), sprawls flat (B) and runs out (C).** Buying a plot is a payment that yields an empty rectangle. Every room is a free-standing box with four walls (`RoomState {x,z,width,depth}`) separated by outdoor path, so the hotel reads as segmented modules. There is no hallway, lobby or shared indoor space for scratchers, window perches and armchairs.
3. **Cats should be able to wear clothes.**

The user also asked for a wider list of ideas that would make the game better (see "Idea backlog").

## Decisions made during brainstorming

| Topic | Decision |
|---|---|
| Building model | **Shell + rooms**: the hotel is a continuous building ("shell") per floor; rooms are areas drawn inside it; leftover shell is hallway/lobby. |
| Outdoor rooms | Still allowed. A room drawn entirely outside the shell is a **pavilion** and keeps today's free-standing four-wall rendering. |
| Wall editing | Both the rectangle room tool (option 1) **and** a Sims-style wall tool (option 3) — one data model (walls live on grid edges). Ship the room tool, room stamps and floor painting first; the wall tool follows (non-rectangular rooms). |
| Expansion cost | **Per cell**, with one drag = one purchase and the total shown before Confirm. (Recommended default; the user did not object. Revisit in balancing.) |
| Plots | Plots stop being the reward. They are land the shell can grow onto; painting floor onto an unowned plot offers to buy it in the same confirm. |
| Going up | Stairwells connect floors. New floors unlock with hotel level and each brings a themed room kind: **Upper floor → Sunroom**, **Rooftop → Garden**, **Basement → Spa**. |
| Mobile controls | One finger draws in build tools; two fingers pan and pinch. Offset cursor above the finger. Ghost preview + cost pill with Confirm/Cancel. Existing 20-step Undo covers mistakes. |
| Clothing | Cosmetic wardrobe with head / neck / back slots. Items bought with coins or gifted at friendship milestones. |

## Player experience

### Build tools (Build tab → new "Hotel" category, before Rooms)

| Tool | Gesture | Result |
|---|---|---|
| **Grow** | One-finger drag paints cells | Adds floor to the current floor's shell; exterior walls wrap the outline automatically. Painting onto an unowned plot adds that plot's price to the quote. |
| **Room** | Drag a rectangle | Inside the shell: an interior room with shared walls and a centered door. On bare land: grows the shell to include it first. Kinds: Bedroom, Suite, Lounge, plus floor-themed kinds once unlocked. |
| **Pavilion** | Existing room placement | Free-standing outdoor room (today's behavior). |
| **Stamps** | Tap a furnished template, tap to place | Existing templates; interior when placed inside the shell. |
| **Doors & windows** | Tap a wall edge | Cycles wall → door → window (exterior edges also offer an open archway). |
| **Erase** | Drag across floor / tap a wall | Refunds what was paid. Rooms must be removed before the floor under them. |
| **Walls** (phase 2) | Drag along grid lines, one bend per drag | Free walls; enclosed regions with a door become rooms (non-rectangular). |

The floor switcher (a small ▲ 1 ▼ chip beside the Build panel) appears once a second floor exists. Floors above the one you are viewing are hidden; the viewed floor shows cutaway walls; floors below render normally underneath.

### Floors

| Floor | Unlock | Themed room | What it adds |
|---|---|---|---|
| Ground (0) | Start | Bedroom, Suite, Lounge | Lobby and hallways |
| Upper (1) | Hotel level 3 + first stairwell | **Sunroom** | Window-heavy lounge; cats nap in sunbeams (+income bonus when furnished) |
| Rooftop (2) | Hotel level 5 | **Garden** | Open-air; plants and outdoor furniture only; no roof drawn |
| Basement (−1) | Hotel level 7 | **Spa** | Warm, lamp-lit; spa furniture |

Upper cells must sit on indoor cells of the floor below (basement cells under ground-floor cells). A **stairwell** is a 2×3 room kind placed on floor L that also occupies the same cells on floor L+1 and links them for cat navigation.

### Wardrobe (Cats tab → cat → Wardrobe)

Three slots: **head** (sun hat, beanie, flower crown, sailor hat, tiny crown), **neck** (bow tie, bandana, bell collar, knitted scarf), **back** (sweater, raincoat, cape). The cat's care-view camera frames the cat while you try things on; tapping an item previews it on the cat without spending. Buying adds it to the hotel wardrobe (usable by every cat). Three signature items are gifts that unlock when a specific cat reaches friendship 50. Outfits are cosmetic; guests keep their outfits while roaming.

## Architecture

### Save version 3 (domain, `Runtime/Domain`)

```text
HotelData.floors : List<FloorState>
FloorState  { int level; Dictionary<string,double> cells /* "x,z" → paid */; Dictionary<string,EdgeState> edges }
EdgeState   { string kind /* wall|door|window|open */; string room /* owner room id or "" */; double paid }
RoomState.floor, ObjectState.floor : int (default 0)
RoomState.door : int (-1 = use rotation; lets a drawn room open onto a hallway on any side)
RoomState.cells : List<string> (wall-tool rooms only; null and unsaved for rectangles)
CatState.outfit : Dictionary<string,string> /* slot → wear id */, HotelState.wardrobe : List<string>
```

* **Edges** use canonical keys: `v:x,z` is the edge on grid line *x* between cells (x−1,z) and (x,z); `h:x,z` is on line *z* between (x,z−1) and (x,z).
* **Exterior walls are derived**, not stored: an edge between an indoor and a non-indoor cell is a wall unless a stored edge overrides it (door, window, open archway).
* **Room walls are owned**: `SyncRoomWalls` regenerates every room-owned edge from the room rectangles after each command, so moving, resizing and removing rooms never leaves stray walls. Player-placed doors/windows (`room == ""`) survive.
* **Doors** are centered on the room's `rotation` side: one edge on odd-length sides, two edges (a double door) on even-length sides, so the existing `DoorPosition` stays correct. Lounges (`shared`) get doors on all four sides, matching legacy behavior.
* **Interior vs pavilion** is derived: a room whose cells are all indoor is interior; one with no indoor cells is a pavilion; anything else is invalid.
* **Migration v2 → v3** (`ShellMigration.Upgrade`) turns each non-terrace room into shell cells plus owned walls on floor 0 and refunds any path under them. It runs on load, on JSON restore and on starter creation. Migrated hotels look and route the same as before.
* **Navigation**: interior rooms no longer add their own wall solids; shell edges (wall/window) do. Indoor cells are walkable. Floors add a floor component to nav keys and stairwells add cross-floor edges (phase 3).

### Presentation (`Runtime/Presentation`)

* `VoxelWorldShell.cs` renders shell floors (timber boards reused from `BuildRoom`), wall runs (merged edges from the pure `ShellDraw.Runs` helper) with the existing wall styling, doors, windows, and cutaway heights (back walls 2.1, front walls 0.25, full walls 2.46 in exterior view). Interior rooms skip their own walls and roof; the shell draws one roof per island in exterior view.
* `HotelShellUI.cs` (a new `HotelUI` partial) adds the Hotel build category and tool flow, reusing `BeginCommand` / `UpdateCommandTarget` / `PreviewCommand` / `PlaceCommand` from `HotelParityUI.cs`.
* `VoxelWorldInput.cs` gains a `drawing` mode: one finger draws, two fingers pan and pinch.
* `CatOutfitView.cs` builds voxel wear pieces parented to `GodotCatRig` bindings (`head`, `body`), placed from the binding's renderer bounds so they fit every cat size.

### Content

* Wear items live in `Assets/Resources/Content/Wardrobe.json` (id, name, slot, price, gift cat, voxel parts).
* Themed rooms reuse existing catalogue items for now: a perch makes a Sunroom ready, planters and benches a rooftop Garden (the rooftop counts as outdoors), and a fireplace a Spa. Dedicated themed furniture is a later art task, not part of these plans.

## Error handling

Every build command is a quote-then-execute transaction (existing `Quote`/`Execute`), so failures never change state or coins. Player-facing failure messages:

| Situation | Message |
|---|---|
| Painting off owned land (no buy) | "Grow the hotel on land you own." |
| Erasing floor under a room | "Remove the room here first." |
| Room half inside the shell | "Draw rooms fully inside the hotel or fully outside it." |
| Room without a door / open side | "Every room needs a door." / "Rooms need walls all the way around." |
| Wall through a room | "Walls can't cut through a room." |
| Archway on an interior edge | "Archways go on outside walls; inside, just leave the floor open." |
| Upper floor without support | "Upper floors need hotel floor underneath." |
| Floor not unlocked | "The rooftop opens at hotel level 5." (and so on) |
| Wear not owned | "Buy this in the wardrobe first." |

Save failures keep the existing Retry flow. Invalid or corrupt v3 saves are rejected by `StrictSaveJson` and `Valid`, and the originals are preserved.

## Testing

* **Domain** (`tests/unity-domain`, `dotnet run --project tests/unity-domain`, about 1 minute, no Unity needed): new `ShellSuites.cs` (shell, drawing, floors, floor life, wall tool) and `WardrobeSuites.cs`. Covers migration equivalence (Meadow capacity 4 / rate 64 unchanged), per-cell pricing, plot auto-buy, enclosure and door rules, owned-wall sync on move/resize/remove, refunds, Undo/Redo, strict JSON rejection, nav through doors, stair routing, floor unlock gates and wardrobe purchase, dress and gift rules.
* **Unity EditMode** (`tools/unity.ps1 Test`): compile gate plus existing suites; the `38`-item assertions are updated when content grows.
* **Visual QA** (`tools/unity.ps1 Windows` then `QA`, plus editor Game-view captures via the Unity plugin): Meadow, Seaside, Forest and Snowcap lawn match; a hallway-and-lobby hotel; a two-floor hotel with stairs; Rooftop and Basement; a dressed cat in care view and roaming. Portrait and landscape at text 100% and 150%. Captures go to `docs/art/qa-shots/hotel-growth/`.

## Idea backlog (brainstormed, prioritized)

Ranked by how much they build on the new systems and by cost. Each "Next" item needs its own short spec before planning.

| Priority | Idea | Why it's good now |
|---|---|---|
| **Next** | **Sunbeam spots**: windows cast moving light patches; cats path to nap in them | Makes the new window edges matter; pure charm. |
| **Next** | **Lobby charm score**: hallway/lobby decor raises arrival speed and reviews | Gives open-plan space a purpose beyond looks. |
| **Next** | **Guest requests**: a guest asks for "a room with a window", "a rooftop nap", "something warm to wear" | Ties floors, windows and wardrobe into short goals. |
| **Next** | **Staff uniforms**: the wardrobe applied to Daisy and the reception/kitchen staff | Reuses the wardrobe with almost no new code. |
| Soon | **Photo mode + postcards** (the Godot version had an album) | Shareable; shows off multi-floor hotels. |
| Soon | **Cat-tree shafts**: a vertical climbing tower that links floors for cats only | A playful alternative to stairs. |
| Soon | **Seasons**: snow on the roof, autumn leaves, spring blossoms; seasonal wear | Cheap scenery variety plus wardrobe drops. |
| Soon | **Daily cozy goals** (three per day, small rewards) | A reason to return without pressure. |
| Soon | **Garden growing**: plant beds on the roof garden bloom over real time | An idle-friendly progression loop. |
| Later | **Forever homes**: long-stay guests can be adopted as resident cats | An emotional long-term goal. |
| Later | **Neighbor visits / events** (dog travel club, bunny delegation from the original brainstorm) | Variety; the ported event systems. |
| Later | **Home-screen widget and welcome-back notifications** | Retention; platform work. |
| Later | **Accessibility**: haptics on draw, color-blind-safe build previews (the invalid preview currently relies on red/green) | Quality bar. |

## Out of scope

Live commerce, accounts or cloud saves. Changes to the Godot build. Balancing beyond first-pass constants (tracked in the roadmap's balancing checkpoint).
