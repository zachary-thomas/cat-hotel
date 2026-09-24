# Meadow Life phase 3: requests, rumors and the Meadow outskirts

September 24, 2026 · Unity only · Meadow (map 0) · [roadmap](2026-09-23-meadow-life-00-roadmap.md)

**Goal:** neighbors ask for favors that send you shopping or building, and pass on rumors that send the manager out to three new spots behind the plaza to find something.

## Decisions

- **Requests.** An Acquaintance or closer neighbor posts one request a day, the first time you chat that day. It stays open until it's done.
  - **Fetch:** bring a Paw Mart gift that isn't their favorite. Reward: 50 coins and +8 friendship.
  - **Build:** add N more pieces from a furniture group to the hotel ("two more plants"). The count present when the request is posted is saved as the baseline. Reward: 120 coins and +8 friendship.
  - A **Request** bubble in the neighbor's chat repeats the ask, or completes it once it's ready. Request friendship ignores the daily chat cap, and tier rewards still pay out.
- **Rumors.** One rumor can be active at a time, and at most one new rumor starts per game day. Any Acquaintance or closer neighbor may pass it on: their greeting becomes the rumor line. A rumor names a spot and a find.
  - **Kitten:** introduces an unknown guest cat, or gives 100 coins if every cat is known.
  - **Lost item:** 80 coins.
  - **Treasure:** a furniture piece goes into storage.
- **Finding.** While a rumor is active, a sparkle shows at its spot and the Life HUD gets a "Go look" button. Tapping either walks the manager there along the street graph, and arriving claims the find.
- **Outskirts.** Three new street nodes behind the plaza:
  - `lily_pond` at (−18, 38), linked from `bench_west`
  - `hilltop` at (0, 46), linked from `square`
  - `old_oak` at (20, 40), linked from `bench_east`

  Stepping stones mark each link. Each spot gets a small voxel kit. Scenery inside those areas isn't built.
- **Save.**
  - `NeighborState` gains `request`, `requestBase`, `requestDay` and `requestsDone`.
  - `TownState` gains `rumorSpot`, `rumorFind`, `rumorGiver`, `rumorDay` and `rumorsFound`.
  - Both are validated.

## Tasks

1. `Quests.json` (spots, finds, rumor lines for every spot and find, found lines, build templates, thank-you lines) and a `QuestContent` loader.
2. Domain in `HotelQuests.cs`:
   - request posting and completion
   - rumor posting, the `Search` order and finding
   - validation
   - domain tests
3. Presentation:
   - `OutskirtsArt` (pond, oak, lookout, stepping stones, sparkle)
   - the Request bubble in chat
   - the rumor banner and "Go look" button
   - the found banner
   - requests on the Neighbors page
4. EditMode tests and bridge screenshots of the outskirts and of a find.
