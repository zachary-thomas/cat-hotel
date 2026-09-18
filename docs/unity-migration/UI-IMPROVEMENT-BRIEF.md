# Unity UI improvement brief — Purrington Hotel

**Owner:** UI-focused bot (this chat)  
**Repo:** https://github.com/zachary-thomas/cat-hotel (`main` @ Unity Meadow commit)  
**Local:** `C:\Users\zach7\Repos\Projects\cat-hotel`  
**Primary code:** `unity/PurringtonHotel/Assets/Purrington/Runtime/Presentation/HotelUI.cs` (~42KB, partial class), plus `HotelApp.cs`, `HotelParityUI.cs`, care/input presentation helpers  
**Engine:** Unity 6000.3.24f1 LTS, uGUI + TextMeshPro, Input System, URP  
**Sibling bots:** Construction Parity, Hotel Life Parity, Destinations Parity, Meadow Finisher — they own non-UI milestones; keep UI changes presentation-only


## Stance: parity + improvements

Parity with Godot UI behavior is the **floor**. Every slice should also improve clarity, delight, and mobile feel (brighter cream/mint/coral chrome, snappier feedback, clearer objectives/status) without hiding the voxel world or changing domain rules.

## Non-negotiables

1. Stay **voxel 3D + orthographic isometric**; the hotel world must stay visible.
2. Do **not** change domain rules, prices, save formats, or Godot saves.
3. No live commerce/ads.
4. UI events must **never** place furniture or pan the world underneath chrome.
5. Keep EditMode tests green (`.\tools\unity.ps1 Test`).

## Design system (already partially coded)

| Token | Hex / asset | Use |
|---|---|---|
| Ink | `#173D32` | Body/dark text |
| Cream | `#FFF8E9` | Surfaces |
| Mint | `#60D6A6` | Primary actions |
| Coral | `#FFAB97` | Highlights / alerts |
| Gold | `#FFD16F` | Rewards / coins |
| Lilac | `#DFD2F5` | Accents |
| Heading | Fredoka SDF | Titles |
| Body | Nunito SDF | Labels |

Targets: safe-area aware; hit ≥48 (primary ≥56); text scale 100/125/150%; reduced motion + independent music/SFX.

## Current state (from source + docs)

- Procedural uGUI rebuild on navigation/layout; wallet label updates on income.
- Tabs: Hotel / Cats / Build / Life / Map; placement mode; care mode; settings; `compactObjective` flag exists.
- Known gaps vs plan: large chrome can still dominate; placement browse vs world height rules need verification; sheets/catalogue polish incomplete; care stage feedback can be stronger; desktop side-catalogue vs phone dock consistency.

## Priority upgrades (do in order)

### P0 — World-visible layouts
- Enforce **placement mode**: only item, price, Rotate, Cancel, Place; **≥50%** safe height for world.
- Enforce **browse mode**: catalogue/sheets leave **≥35%** world height.
- Collapse welcome/objective into a **compact objective card** (use/extend `compactObjective`).
- Compact wallet/status chip (mint/gold), not a full-width banner.

### P1 — Navigation & sheets
- Bottom dock: five labeled tabs, **Build** visually central/prominent.
- Secondary details in **bottom sheets** (not stacked full-screen panels).
- Category chips: keep horizontal scroll; clearer selected state; illustrated catalogue cards.
- Desktop: side catalogue OK if actions match mobile semantics.

### P2 — Care UX
- Large live voxel care stage; immediate tool feedback for Pet/Brush/Feather/Yarn/Cushion/Box.
- Gesture polish can hand off stroke/flick physics to **Meadow Finisher**; UI owns tool chrome + feedback.

### P3 — Polish & a11y
- Toast/save-error persistent banner styling; Retry obvious.
- Text-scale reflow into sheets; safe insets on notch devices.
- Capture before/after at 390×844, 360×640@150%, 1280×800 into `docs/unity-migration/evidence/ui-polish/`.

## Implementation notes

- Prefer editing `HotelUI` rebuild paths and layout helpers; avoid domain edits.
- `AvailableWorldRect` / acceptance layout hooks already exist — use them for height rules and tests.
- Evidence references: `docs/unity-migration/evidence/`, IMPLEMENTATION-PLAN “Mobile UI direction”.
- Cloud Agents require Pro on this account; until then, apply changes locally in Cursor IDE or via machine Shell with careful review.

## Acceptance checklist

- [ ] Placement layout leaves ≥50% world height at 390×844 and 360×640@150%
- [ ] Browse leaves ≥35% world height
- [ ] Objective is collapsible card; dock matches design
- [ ] No accidental world pan/place when tapping UI
- [ ] `.\tools\unity.ps1 Test` green
- [ ] Screenshots committed under evidence/ui-polish

## Out of scope (other bots)

- Construction copy/resize/paths/land/God mode → Construction Parity  
- Reservations/milkshakes/speech/housekeeping → Hotel Life Parity  
- Seaside/Forest/Snowcap → Destinations Parity  
- Meadow life density + care gesture physics → Meadow Finisher  

