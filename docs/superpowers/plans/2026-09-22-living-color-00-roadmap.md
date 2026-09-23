# Living color roadmap: Phases A–D

September 22, 2026 · Unity only

**Spec:** [living color and day/night design](../specs/2026-09-22-living-color-day-night-design.md). Its "Phase map" and "Extension points" sections are the contract between phases.

**Why:** the game renders flat and muted compared with the repository's art direction. The world should look like `assets/ui/mobile/*.png` (bright pastel voxel dioramas, soft light, glowing lanterns, dense flowers and vines, happy cats). The HUD should look like `docs/concept-art/01`–`06` (cream cards, deep-green ink, leaf-green buttons, gold paw coin). The orthographic isometric camera never changes. `docs/unity-migration/evidence/unity-first/01-hotel-390x844.png` is the baseline, not a target.

## Phases

| Phase | Plan | Status | Depends on |
|---|---|---|---|
| **A: Living color and day/night** | [01-phase-a](2026-09-22-living-color-01-phase-a.md) | Done on `feat/living-color-phase-a` (e9038e6..9f6746d); QA reviewed. Open polish: noon slightly hazy, night dim; bottom objective card truncates at 360@150% | nothing (touches few shared files) |
| **B: Light and life** | to be written after A lands | Not started | A (`HotelModel.Clock`, `WorldLighting.Glow`, `ConceptTheme.Ui`) |
| **C: Detail kits** | shared with [playable hotel world art](2026-09-22-playable-hotel-polish-01-world-art.md) Tasks 2–3 | Not started | A (palette table, tone variants, glow); hotel-growth roadmap and Main Street, per that plan |
| **D: Playability loop** | to be written after A; needs its own spec (save schema) | Not started | A (clock, UI tokens, reserved title sub-pill); B's tween helper for income pops |

### Phase A: Living color and day/night (this round)

Palette retargeted to `assets/ui/mobile`; trilight ambient; softer, warmer sun; grading (bloom, split toning, lift, saturation); SSAO on mobile; deterministic voxel tone variants; a 24-minute day/night cycle derived from `State.elapsed` with `DayCycle.json` keyframes; window and lamp glow; guests nap at night, sunny spots close, day visitors pause; a `Day N · hh:mm` clock chip; top bar and bottom nav restyled to concept-art tokens.

### Phase B: Light and life (next)

Carry these into its spec:
- Point lights on lanterns, lamps and the reception lamp, reading `WorldLighting.Glow`, with a small cap on per-object lights for mobile.
- Particles, all respecting `settings.motion`:
  - coin sparkle on income
  - hearts on petting
  - drifting blossom petals (`garden.png`)
  - dust motes in sunbeams
  - falling leaves (Forest)
  - fireflies when `Clock.phase == Night`
- A small tween/ease helper (Presentation; unscaled time; reduced-motion aware) used for squash-and-stretch on cat hops, a placement bounce and settle wobble on furniture, and income-pop bounce.
- UI motion: button press bounce, wallet count-up, panel slide-in, active-tab tile slide.
- Acceptance: QA GIF or frame strip per effect; the mobile frame-time budget from Phase A still holds.

### Phase C: Detail kits

Carry these into its spec, or into the world-art plan's Tasks 2–3:
- Facade and roof kit (ridges, eaves, gables, chimneys, arched entrance, flower boxes, cat crest) driven by shell edges.
- Dense vines and flower clusters on walls and fences; blossom trees; potted plants; hedges; stepping stones; lanterns on posts.
- Interiors: bookshelves, cat trees, gingham beds and cushions, paw-print rugs, framed pictures, plank floors with grain, beams and wainscot.
- Cat look pass: happy closed-eye faces, pink blush, rounder voxel silhouettes (`cats-01.png`), with outfits still fitting.
- In-world signage: a "Purrington Hotel" board and "Good cats, brighter days" signs.
- Per-destination kits following `world-map.png` (Seaside blue roofs and pier, Forest cabin and autumn trees, Snowcap snow roofs and hot spring).
- Must not block navigation, picking or construction; must use lower-detail clusters at far zoom and on mobile.

### Phase D: Playability loop

Carry these into its spec (it needs a save-schema change: `StrictSaveJson`, `HotelModel.Valid`, migration, domain tests):
- A hotel level with an XP/upgrade ladder, shown as a "Hotel level N" pill under the destination title (the layout slot is reserved in A).
- A goal ladder: the "Next: Upgrade the lounge · 1/2 upgrades to level 5" card (concept 02) and a short checklist ("A warm welcome: prepare 2 more suites", concept 06).
- Persistent "+N" income pops over rooms (built on the Phase B tween helper) and ambient cat lines ("Miso is settling in").
- A day summary opened from the clock chip (the stub tap handler exists in A), plus optional night-specific goals and lines.
- Reconcile with the playful-mobile-ui and first-run plans so there is one goal system, not two.

## Rules for every phase

- Unity only; the legacy Godot game is reference only.
- Keep the isometric orthographic 36.59° / 315° camera, framing and pan/zoom.
- Never edit the Godot oracle section of `tests/unity-domain` to make a change pass.
- Every visual phase ends with before/after QA captures under `docs/art/qa-shots/living-color/` and a mobile frame-time check.
