# Build UI refactor

**Goal:** make building, and especially floors and stairs, easy to understand. Domain commands (`HotelModel.Execute`, `Quote`) are unchanged; this is a Presentation-only rework of the Build tab.

## Problems found (2026-09-23)

- **One long list.** Construction tools, furniture shopping, outdoor pavilions, land and paths all share one scroll, filtered by nine chips: All, Hotel, Rooms, Arrangements, Land, Paths, Furniture, Outdoors, Storage. "All" shows only furniture, and construction hides under "Hotel".
- **Three ways to make a room.** "Draw a bedroom", "Make a bedroom" (claim a walled space) and "Rooms" (outdoor pavilions), with no explanation of the difference.
- **Floors and stairs are hidden.** The floor switcher only appears once a second floor exists. Stairs are a card deep in "Hotel". Nothing says how stairs, the upstairs floor, growing that floor and drawing rooms up there connect.
- **Tools are buried.** Undo and Redo sit behind a "Tools" toggle, next to a "Play" button nobody needs.
- **Selection is buried too.** Actions for a selected room or furnishing appear as cards at the top of the scroll, far from the thing that was tapped.
- **Tool feedback is weak.** Each tool gets one line ("Tap hotel to position") plus toasts. There's no step-by-step hint, the cost only shows in a toast, and Confirm can be pressed before there's anything valid to confirm.

## Design

The pattern follows cozy builders (The Sims build mode, Happy Home Paradise, Two Point): first choose a mode, then a tool; the world stays visible; the selected object gets its own action bar.

1. **Mode tabs** at the top of the Build sheet: **Build** (structure), **Furnish** (the shop) and **Storage (n)**.
2. **Build mode** is a grid of tool tiles in labelled groups:
   - **Rooms:** Bedroom, Suite, Lounge, plus the floor's themed room. Each tile starts drag-to-draw. A "Room from walls" tile claims a walled space, and its room type is chosen in the tool bar.
   - **Floors & stairs:** Stairs up, Stairs down, Grow floor, Remove floor. Locked tiles show the hotel level they need.
   - **Walls & doors:** Walls; Doors & windows.
   - **Outside:** garden pavilions (the old "Rooms"), Paths, and Land plots.
   - **Your rooms:** a compact list with an Edit button on each.
3. **Furnish mode:** the item catalogue with chips for All, Furniture, Outdoors and Sets (the old "Arrangements").
4. **Floor rail:** always visible on the left in Build. It lists Rooftop, Upstairs, Ground and Basement:
   - a built floor opens when tapped
   - a floor you can open shows "+ Upstairs" and starts the stairs tool on the floor below
   - a locked floor shows "Lv 3"
5. **Tool guide:**
   - **Top banner:** the tool name, a step hint written for that tool, and a live status line showing the quote cost or the reason it can't be placed.
   - **Bottom bar:** option chips when the tool has them (room type), then Cancel, Rotate (only when it applies) and Confirm (disabled until the target is valid).
6. **Selection bar:** tapping a room or furnishing replaces the sheet with a bottom bar showing its name and status, plus Move, Rotate, Copy, Resize, Store or Remove as they apply, and Done. Tapping empty ground deselects.
7. **After building stairs:** a "Stairs built · Upstairs is open" card offers "Go up", which switches to that floor.
8. **Undo and Redo** are always in the Build header. The Tools toggle and the Play button are removed.

## Verification

- EditMode tests for:
  - tile groups and the floor rail states (built, can open, locked)
  - the stairs tile starting the stairs tool
  - mode tabs switching content
  - Confirm staying disabled until a valid preview exists
  - selection showing the action bar
- Update the `ParityInputAcceptance` click paths (Bedroom tile, Guest room tile, Confirm).
- Editor captures at desktop and 430×932.
