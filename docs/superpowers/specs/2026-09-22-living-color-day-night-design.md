# Purrington Hotel: living color and day/night

September 22, 2026 · Unity only · design approved in conversation, awaiting spec review

## Goal

Close the gap between the Unity build and the repository's art direction, for both the world and the UI, while keeping the game's orthographic isometric view. The references are an aesthetic target, not a camera change: they show the same isometric voxel diorama we already render, only brighter, more colorful, softer-lit and far more detailed.

## Visual references

| Source | Role | What to take from it |
|---|---|---|
| `assets/ui/mobile/*.png` (especially `welcome-hotel`, `upgrade-lounge`, `garden`, `lantern-gathering`, `cats-01`, `paw-mart`, `world-map`) | **Primary world art style** | High-key pastel "candy" palette (mint, butter, coral, blush pink, lavender, honey wood, cream plaster, bright leaf green, clear sky blue); soft, low-contrast shading with gentle contact shadows; warm glowing lamps and lanterns with a soft bloom; a peach-to-lilac dusk (`lantern-gathering`); gingham fabrics; dense vines, flowers and potted plants; happy closed-eye cats with pink blush. |
| `docs/concept-art/01`–`06` | **Primary UI chrome and in-game composition** | Cream rounded cards and pills, deep-green ink type, a leaf-green primary button, a gold paw-coin wallet with `+N / min`, a sage tile behind the active tab, the hotel-name title with a level pill, the "Next: ..." progress card, in-world signs; the isometric cutaway framing of 02, 03 and 06. |
| `docs/art/qa-shots/welcome-ui-390x844.png` | Current welcome screen (uncommitted work in progress) | Already follows both references; keep it as it is. |
| `docs/unity-migration/evidence/unity-first/01-hotel-390x844.png`, `docs/art/qa-shots/hotel-growth/shell-cutaway-landscape.png` | **Baseline only, not a target** | What the game looks like today. |

Where the two sets differ, the world follows `assets/ui/mobile` (brighter and more playful) and the HUD follows `docs/concept-art` (cream and ink). Concept art's earthier greens are not a target for world surfaces.

## Problem

The current world (`docs/art/qa-shots/hotel-growth/shell-cutaway-landscape.png`) reads flat: muted olive/khaki surfaces, one flat light, almost no grading, no grounding shadows on phones, and no sense of time passing. This spec delivers **Phase A** (a look pass plus a day/night cycle with light gameplay) and reserves clean extension points for Phases B, C and D, which get their own specs later.

Success for Phase A:

- Side-by-side QA captures at 12:00 show visibly richer color, grounded contact shadows, and warm/cool light contrast compared with today's baseline. This holds on the Windows preview and at mobile quality.
- A full in-game day passes in 24 real minutes of play. Dawn, day, dusk and night are each distinct, and night has warm glowing windows and lamps.
- At night guests nap in their rooms, sunny spots empty, and new day visitors stop arriving. Income is unchanged.
- A top-bar chip shows `Day N · hh:mm` with a sun or moon icon.
- The HUD top bar and bottom navigation match the `docs/concept-art` look: cream pills, deep-ink text and icons, a gold paw-coin wallet with a `+N / min` sub-pill, and a soft sage highlight on the active tab. They share one set of color tokens with the world palette.
- `dotnet run --project tests/unity-domain` ends `PASS <n> checks`, with the Godot oracle section untouched, and the Unity EditMode tests pass.

## Phase map

| Phase | Theme | Status |
|---|---|---|
| **A** | Living color and day/night: palette, ambient light, grading, mobile SSAO, voxel tone variation, time-of-day clock, lighting keyframes, night behavior, HUD clock, shared UI tokens with a restyled top bar and bottom nav | **This spec** |
| B | Light and life: point lights on lanterns and lamps, particles (coin sparkle, petting hearts, drifting blossom petals as in `garden.png`, dust motes, leaves, fireflies at night), a small tween/ease helper, squash-and-stretch, placement bounce, income pop bounce, UI polish (button press bounce, wallet count-up, panel slide-in) | Reserved; see "Extension points" |
| C | Detail kits following `assets/ui/mobile`: facade/roof kit, dense vines and flower clusters, blossom trees, potted plants, bookshelves, cat trees, gingham beds and paw-print rugs, plank floors, beams/wainscot, a cat look pass (happy closed-eye faces, pink blush, rounder voxel silhouettes as in `cats-01.png`), in-world signage (the concept's "Purrington Hotel" board and "Good cats, brighter days" sign) | Reserved; overlaps Tasks 2–3 of the [playable hotel world-art plan](../plans/2026-09-22-playable-hotel-polish-01-world-art.md), which remains the owner |
| D | Playability loop: hotel level and its "Hotel level N" pill under the hotel name, goal ladder with the concept's "Next: Upgrade the lounge" progress card and checklist, persistent "+N" income pops over rooms, ambient cat lines | Reserved; needs save schema, migration and domain tests |

**Relation to the playable-hotel-polish design.** Phase A replaces Task 1 ("Warm material and lighting roles") of the world-art plan. Phase A's `glow` scalar and emissive materials are the ones that plan's facade kit should use. That plan's other tasks, dependencies and the first-run plan are unchanged.

## Constraints

- Unity only (`unity/PurringtonHotel`). No Godot edits, no re-export of `GodotReference.json` / `GodotGeometry.json`.
- **The isometric view is fixed.** The orthographic 36.59° / 315° camera, its framing, and player pan/zoom stay as they are in every phase. No perspective camera, tilt-shift or depth-of-field blur over playable rooms. All aesthetic gains come from color, light, material and detail.
- The UI stays live uGUI/TextMeshPro. Concept images are references, never flat overlays.
- No save schema change in Phase A: no `StrictSaveJson` fields, no version bump. `settings.evening` remains in the save for compatibility but nothing reads it.
- Do not edit the Godot oracle checks. `HotelModel.Rate()`, capacity, room status and construction behavior are identical at every time of day.
- Match surrounding file style (dense one-line members in existing files). New files may use the same style.
- `VoxelWorld.cs`, `HotelUI.cs` and the font assets have uncommitted work in progress. Keep edits there small and additive.

## 1. Look pass

### 1.1 Palette (`ConceptTheme.cs`)

Today's `Surfaces` remap exists to push legacy Godot colors toward concept 02's earthy greens and khakis. It turns coral, mint, lilac and butter into olive and tan. The legacy authored colors (`ffab97` coral, `60d6a6` mint, `dfd2f5` lavender, `ffd16f` butter, `f078a8` pink) are actually closer to `assets/ui/mobile` than their replacements. Phase A keeps the remap as the single place that assigns surface roles, but retargets every row to the pastel candy palette sampled from `assets/ui/mobile`:

| Role | Legacy authored | Today's remap | Phase A |
|---|---|---|---|
| Lawn / grass | `60a830` | `82934D` | `8CC84B` |
| Leaf / hedge | `186030` | `425C35` | `4FA64A` (hedge shadow side `3D8A3E`) |
| Honey timber | `a86030` | `B3824C` | `D39A5A` |
| Light timber / floor | `f0d8c0` | `D2AD77` | `EAC08A` |
| Plaster | `fff8e9` | `EFE2C9` | `FFF4DF` |
| Stone / paving | `ede8d9` | `BBB6A5` | `E4DCCB` |
| Butter / gold | `ffd16f`, `f0a830` | `D7AE55` | `F7CC62` |
| Coral / sofa red | `ffab97` | `BF7958` | `F08C7C` |
| Blush pink | `f078a8`, `e6a1a6` | `C58A75`, `B98063` | `F5AEB4`, `F49AA2` |
| Mint | `60d6a6`, `74c5c5` | `738448`, `788D61` | `8ED9AE` |
| Lavender | `dfd2f5`, `a892b9` | `89936C`, `8C9270` | `C3B2EE` |
| Sky / window glass | `a8d8f0` | `C6D4C1` | `A9DDF6` |

The remaining rows follow the same rule: keep the legacy row's hue family, lift lightness into the 0.70–0.95 HSV value range, and hold saturation in the 0.35–0.65 band. That gives bright pastel rather than neon or dusty. Each destination's authored lawn swatch (`83a36e` Meadow, `cfbb90` Seaside, `758c64` Forest, `c2cdcb` Snowcap) and the hard-coded wainscot, roof, window and hedge colors in `VoxelWorldRooms.cs` / `VoxelWorldShell.cs` (`738448`, `7e8c65`, `87936e`, `697f59`, `a87868`, `82a9a2`, `7c8e6d`, `d9e1d7`, `90bfc0`, `b5ddcf`, `88ab72`, `6e9b62`) get rows in the same table. Because every surface goes through `GodotGeometry.Material` → `ConceptTheme.Surface`, this retargets Seaside (sand `F3E2B5`), Forest (grass `6FAE55`, bark roof `B0703F`) and Snowcap (snow `F4F7FB`, stone `B9C3CC`) toward `world-map.png` without a separate per-destination API. Cat fur, UI colors and `PathColor` are out of scope for the retune; cat look belongs to Phase C.

**Guard.** A domain-harness check (pure color math, no UnityEngine; see §5) asserts the Phase A table: median chroma (max−min of RGB) ≥ 0.25 (today 0.19); median HSV value ≥ 0.85 (today 0.70, which reads as high-key); luminance spread between the darkest and lightest target ≥ 0.40 so shapes still read; and every *authored* row (a legacy Godot color, as opposed to a re-roled presentation literal such as a roof or wainscot) keeps its hue within 25° of its source whenever the source has chroma ≥ 0.12. Today's table fails that last rule on 28 rows, which is the olive/khaki problem. HSV saturation is deliberately not the metric: pastels are light, so it under-reports them. This stops a later pass from quietly washing the palette out again. The check lives in a new `ArtSuites.cs`, registered in `tests/unity-domain/*.csproj` next to `ShellSuites.cs`, not in the oracle section.

To make this testable from the harness, the table moves into a new `Runtime/Domain/SurfacePalette.cs` (flat, because the harness compiles `Domain/*.cs` only). It is a plain C# class holding hex strings and HSV helpers. `ConceptTheme` reads from it.

### 1.2 Ambient and sun

- New `Runtime/Presentation/WorldLighting.cs` (a `MonoBehaviour` on the `VoxelWorld` object) owns the sun `Light`, `RenderSettings` ambient values, camera background, and runtime grading. `VoxelWorld.Initialize` creates it instead of building the sun inline.
- `RenderSettings.ambientMode = AmbientMode.Trilight`. Today's `Flat` mode ignores the sky/equator/ground colors that `SetEvening` already sets.
- Sun `shadowStrength` goes from 0.48 to 0.58. The mockups ground every object with a clear but soft, warm-tinted shadow, never a dark one. Most of the grounding comes from SSAO (§1.4) and the bright trilight fill. Bias values stay the same.
- Daytime ambient is bright and warm (sky ≈`FFF1D6`, equator ≈`F4E6C8`, ground ≈`B9D98A` bounce from the lawn), so shaded faces stay pastel, as in `upgrade-lounge.png`.
- `VoxelWorld.SetEvening(bool)` is removed. `HotelApp`, `VoxelWorld.Refresh` and `ParityRenderAcceptance` use `WorldLighting.Pin` instead (see §2.4).

### 1.3 Grading (`ProjectSetup.ConfigureRendering` → `Assets/Resources/ParityGrading.asset`)

| Override | Today | Phase A |
|---|---|---|
| Tonemapping | Neutral | Neutral (unchanged) |
| ColorAdjustments saturation / contrast | +5 / +4 | +20 / +6 (high-key: more color, gentle contrast) |
| ColorAdjustments post-exposure | 0 | +0.1 by day; driven per frame by the cycle |
| LiftGammaGain | neutral | lift slightly warm and raised (shadows never go muddy) |
| Bloom | none | threshold 1.0, intensity 0.4, scatter 0.7, tint warm `FFE3B0`; high-quality filtering off on mobile |
| SplitToning | none | highlights warm (≈`FFD9A0`), shadows soft lilac (≈`B8A8D8`), balance +20 |
| WhiteBalance | none | added with 0 values; driven per frame by the cycle |
| Vignette | none | none. The mockups have clean, bright edges |

Only emissive materials (lamps, lanterns, window glow) exceed the bloom threshold. This gives the soft halo seen in `welcome-hotel.png` and `lantern-gathering.png` while plaster and UI stay crisp. At startup, `WorldLighting` finds the global `Volume` and swaps in `Instantiate(sharedProfile)`, so runtime changes never alter the asset on disk.

### 1.4 Mobile SSAO

`ConfigureRendering` adds a `ScreenSpaceAmbientOcclusion` feature to `Mobile_Renderer.asset`, which has none today: downsample on, low sample count, intensity 0.4, radius 0.25, direct lighting strength 0.15. Desktop keeps its current SSAO settings. §4 sets the budget this must stay within.

### 1.5 Voxel tone variation (`GodotGeometry.Material`)

- Each surface color gets three tone variants: base, +4% lightness with a slight warm shift, and −4% lightness with a slight cool shift. `Material(hex)` stays as it is. A new `Material(hex, Vector3 position)` picks a variant from a stable integer hash of the rounded world position. It never uses `UnityEngine.Random`, so captures are the same every run.
- Box/voxel builders in `GodotGeometry` pass the box position. Water, `glow|` emissives, UI swatches, text meshes and cat rigs use the plain overload and get no variation.
- Variants are ordinary cached materials. The SRP batcher and `VoxelWorld.Bake` (which merges meshes by material) keep working. Baked scenery can have up to 3× as many merged meshes; §4 checks the cost.
- A vertex-color shader could replace this later without changing callers.

## 2. Day/night cycle

### 2.1 Clock (`Runtime/Domain/HotelClock.cs`)

A pure static helper derives time of day from the existing played-seconds counter `State.elapsed`. It adds no save state.

```csharp
public enum DayPhase { Dawn, Day, Dusk, Night }
public readonly struct ClockReading { public readonly int day; public readonly float minute; public readonly DayPhase phase; public readonly float daylight; /* 0 night .. 1 noon */ }
public static class HotelClock {
    public const float DayLengthSeconds = 1440f;   // 24 real minutes = 24 game hours, 1 s = 1 game minute
    public const float StartMinute = 8 * 60;       // new hotels open at 08:00 on Day 1
    public static ClockReading Read(double elapsed);
}
```

- `minute = (StartMinute + elapsed) mod 1440`. `day = floor((StartMinute + elapsed) / 1440) + 1`. `elapsed` is converted to double before the arithmetic.
- Phase boundaries: Dawn 05:00–07:30, Day 07:30–17:30, Dusk 17:30–20:00, Night 20:00–05:00.
- `daylight` is a smooth 0–1 curve, `sin(π·t)^0.6` over 04:30–20:30, so it peaks at 12:30 and is 0 from 20:30 to 04:30. Gameplay and lighting both read it.
- `HotelModel.Clock => HotelClock.Read(State.elapsed)`.
- The clock pauses when the app is closed, because `Reconcile` adds offline earnings to `pendingCoins` and does not advance `elapsed`. It stops whenever `HotelLife.Tick` stops, for example during save recovery.
- Resetting the profile starts over at Day 1, 08:00. Existing saves land at whatever time their `elapsed` implies, which is acceptable.
- `State.elapsed` is a float and has 1-second resolution after about 190 in-game days. That is fine for a clock with minute resolution; §5 tests it.

### 2.2 Lighting keyframes (`Assets/Resources/Content/DayCycle.json`)

Abridged example: the first key shows the full field set, and every key in the real file has every field. Values not listed here start from today's `SetEvening` presets and are tuned against the QA captures.

```json
{
  "keys": [
    { "minute": 0,    "sunPitch": -10, "sunYaw": 28, "sun": "7F93C8", "sunIntensity": 0.18, "sky": "33456B", "equator": "2E3B52", "ground": "283426", "background": "2A3448", "exposure": -0.35, "temperature": -18, "glow": 1.0 },
    { "minute": 330,  "...": "dawn: rose sun, lilac sky, glow fading" },
    { "minute": 480,  "...": "morning: today's warm day values" },
    { "minute": 720,  "...": "noon: brightest, glow 0" },
    { "minute": 1050, "...": "late afternoon: golden, long shadows" },
    { "minute": 1170, "...": "dusk: amber sun, glow rising" },
    { "minute": 1320, "...": "night: as minute 0" }
  ]
}
```

- Six or seven keys, wrapping around midnight. `WorldLighting` interpolates linearly between the two surrounding keys: colors in linear space, angles as numbers. Every key has every field; the loader rejects a file with missing fields or keys out of order and logs a clear error.
- Each phase has a visual reference:
  - **Day:** the bright, sunny high-key look of `welcome-hotel.png` and `upgrade-lounge.png`, with a clear sky-blue background (≈`BFE6F8`).
  - **Late afternoon:** golden, with longer shadows.
  - **Dusk:** the peach-to-lilac sky and glowing paper lanterns of `lantern-gathering.png` (background ≈`E9B8C4` blending to `B7A6DA`).
  - **Night:** deep but friendly blue-violet (≈`3B4A7A`), never black. Pastel surfaces stay readable, windows and lamps glow warmly, `glow` = 1.
  - **Dawn:** soft pink-gold.
- Night stays cozy, not gloomy. Ambient never drops below a level where a cat's face and a bed's color are still recognizable at 390×844.
- Night light: the night keys give the directional light a high, cool "moon" angle and a low intensity with soft shadows kept. Dusk and dawn keys ease between the sun and moon directions over their two-hour spans, so nothing pops.
- Per-destination tint is out of scope, so Phase A uses one curve for every map. The file format leaves room for an optional `"destinations"` override block later.

### 2.3 Glow

`WorldLighting.Glow` (0–1, from the keys) controls emission on:

- window glass surfaces, identified in `GodotGeometry` by their existing glass color roles
- the lamp renderers already collected in `GodotObjectMotion.lampColors`

Emission uses a shared warm color (`FFD590`) times `glow × 2.2`, which crosses the bloom threshold at night. Materials are changed per shared material with `SetColor("_EmissionColor")` and the `_EMISSION` keyword, not per renderer, so batching survives. Phase B's point lights and Phase C's facade windows read the same `Glow` value.

### 2.4 Pinning time for QA

`WorldLighting.Pin(float? minute)` overrides only the lighting's time. Gameplay and the save still follow `State.elapsed`. `null` returns to the live clock.

- `ParityRenderAcceptance` pins 12:30 where it called `SetEvening(false)`, and 19:30 for its "evening" captures.
- `tools/unity.ps1 QA` captures noon (12:30), golden hour (17:30), dusk (19:30) and night (23:00) variants.

### 2.5 Settings

The "Evening light" card in `HotelParityUI` (line ~368) is removed. `SetViewSettings(exterior, evening)` keeps its signature for save and test compatibility. Phase A adds no new setting. With reduced motion on, the cycle still runs, since its transitions are already slow, but Phase B particles must respect that setting.

## 3. Night gameplay (domain)

All of this is deterministic, reads `Clock.phase`, and does not change `Rate()`, capacity, room status or construction.

- **Guests nap at night.** Guests have no assigned room, so in `HotelLife.Choose` a checked-in guest during `Night` scores `bed` venues far above everything else (+50) and `seat`/`warm` venues slightly higher (+3), using the normal `Reserve` path. A `sleep` activity that starts at Night lasts 90–150 s (from the existing `StableHash`) instead of 11 s. `DescribeIntent` returns `"napping"` for a sleep activity at Night. With every bed taken, the guest falls back to the normal ordering. From Dawn on, choices are normal again, and a nap already under way simply runs out.
- **Sunny spots close.** `sun` venues are not chosen while `daylight < 0.25`.
- **Day visitors keep daytime hours.** `HotelVisitors` doesn't start a new visit during `Night`, so `visitorClock` doesn't accumulate. Visitors already on the lot finish their visit and leave normally.
- **Staff** behave as they do today. Night shifts are out of scope.
- **Social moments** are unchanged. Phase D may add night-specific lines.

`HotelLife` changes are additive branches in `Choose` / `AdvanceVisitor`, with the phase read once per tick.

## 4. HUD and UI alignment

Today's in-game UI (baseline: `docs/unity-migration/evidence/unity-first/01-hotel-390x844.png`) already has cream cards and a five-tab bottom nav. Compared with `docs/concept-art` 01–06 it reads as pastel app chrome: mint and yellow pill buttons, small gray secondary text, and hex literals scattered across `HotelUI.cs`. Phase A aligns the always-visible chrome (top bar and bottom nav) with the concept. Panels, the build tray and the care screens keep their layout and pick up the new tokens only where they already use `ConceptTheme` colors.

### 4.1 Shared UI tokens

`ConceptTheme` gains a `Ui` group, and `SurfacePalette` holds its hex values so the harness can check them next to the world palette. The tokens are sampled from concept 02:

| Token | Value | Use |
|---|---|---|
| `Ink` | `244335` (existing) | primary text, nav icons, titles |
| `InkSoft` | `4E6555` | secondary text (replaces gray) |
| `Card` | `FBF6E9` | pills, cards, nav bar |
| `CardEdge` | `E6DCC4` | 1–2 px card outline and soft drop shadow tint |
| `Sage` | `DCE5C5` (existing) | active tab tile, sub-pills |
| `Leaf` | `4E7F3A` | progress fill, primary action buttons (white label ≥ 4.5:1) |
| `LeafText` | `2E6B2C` | the `+N / min` rate text on `Sage` |
| `Coin` | `E9B43A` / rim `B9832A` | coin disc |

Contrast check (harness): `Ink` and `InkSoft` on `Card` and `Sage`, `LeafText` on `Sage`, and white on `Leaf` each reach ≥ 4.5:1.

### 4.2 Top bar

- **Wallet pill:** a gold paw-coin disc (two tinted rounded shapes plus a paw made of four dots and a pad, all uGUI images, no new sprite font), with the balance in Fredoka bold `Ink`. Under it sits a small `Sage` sub-pill showing `+120 / min` in `LeafText`. This replaces the `<color=#17612F>` rich-text rate in `HotelUI.cs:160`.
- **Hotel title:** the current "PURRINGTON" label becomes the destination name (for example "Meadow House") in Fredoka `Ink`. Phase D adds the "Hotel level N" pill under it, and Phase A leaves room for it in the layout.
- **Menu button:** a round `Card` button with an `Ink` gear glyph, replacing the mint "Menu" pill. It opens the same destination as today.
- **Clock chip (`Runtime/Presentation/HotelClockChip.cs`):** a `Card` pill next to the wallet reading `Day 3 · 10:30` in Nunito `Ink`, with a sun or moon glyph made of two tinted rounded shapes, half and half at dawn and dusk. It updates once per in-game minute. At 360 px width it collapses to `10:30` plus the glyph. Tapping it does nothing in Phase A; Phase D may open a day summary. The Nunito SDF asset must contain `·` (U+00B7); a font glyph check covers this.
- The bar follows the phone safe area and the existing text-scale setting. At 1280×800 it lays out horizontally like concept 06's top bar, using the same components.

### 4.3 Bottom navigation (`HotelUI.Navigation` / `NavigationIcon`, near line 750)

- One `Card` bar with a soft shadow. Icons and labels are in `Ink`, and the active tab sits on a rounded `Sage` tile, as in concept art 02–05. This removes the per-tab mint and yellow fills.
- Labels use Fredoka at the current size. Touch targets are unchanged or larger.
- Tab set, order and navigation behavior are unchanged.

### 4.4 Guardrails

- Only color, shape and typography change in the chrome; no flows move. Text keeps its current strings except the top-bar title.
- `HotelUI.cs` has uncommitted work. Phase A edits are limited to the top bar and navigation builders plus a token swap for their literals, and put new pieces in their own files (`HotelClockChip.cs`, `UiCoin.cs`).
- UI motion (press bounce, wallet count-up) is Phase B, so Phase A UI is static.

## 5. Testing and verification

**Domain harness (`tests/unity-domain`, new `ArtSuites.cs` and additions to the life suites):**
- Clock: `Read(0)` is Day 1 08:00 Day; phase at every boundary ±1 s; wraparound at 1440; day count at large `elapsed` (≥ 200 days) is exact to the minute; `daylight` is continuous and in [0, 1].
- Palette guard from §1.1, plus the UI token contrast check from §4.1.
- Night: with a free bed, a guest's chosen venue role at Night is `bed` and its intent is "napping"; no `sun` venue is chosen at Night; no new day visitor spawns during a full simulated Night; at Dawn guests resume normal choice.
- `Rate()` and `GuestCapacity()` are identical at 12:00 and 00:00 for the default hotel.
- Oracle section unchanged; the final line is `PASS <n> checks`.

**Unity EditMode (`Tests/EditMode/WorldLightingTests.cs`):**
- `DayCycle.json` loads, keys are ordered, all fields are present, and interpolation at a key minute returns that key exactly.
- `Pin(720)` sets `RenderSettings.ambientMode == Trilight`, the sun's shadow strength is 0.58, and `Glow == 0`. `Pin(1380)` gives `Glow == 1`.
- The runtime grading profile is not the asset on disk.
- `GodotGeometry.Material(hex, pos)` returns the same material for the same position and at most three distinct materials per hex.
- The Nunito and Fredoka SDF assets contain every glyph used by the chip and wallet (`0–9`, `·`, `:`, `+`, `/`, `Day`, `min`).


**Visual and performance gate:**
- The QA smoke run (`PreviewVerification`) walks every `Graphic` under the top bar and nav and fails if any color is outside `ConceptTheme.Ui` (plus white).
- `tools/unity.ps1 QA` captures before/after at 12:00 and 21:00 at 390×844 and 1280×800, saved under `docs/art/qa-shots/living-color/`.
- On mobile quality at 390×844, frame time with SSAO, bloom and tone variants stays within 10% of the pre-change baseline recorded in the same session. If it doesn't, mobile SSAO drops to half resolution before any other effect is cut.

## 6. Extension points reserved for B, C and D

| Hook | Provided in A | Used by |
|---|---|---|
| `HotelModel.Clock` / `DayPhase` / `daylight` | yes | B (fireflies, lamp lights), D (day summaries, night goals) |
| `WorldLighting.Glow` and the shared emissive color | yes | B point lights, C facade windows and lanterns |
| `WorldLighting.Pin(minute)` | yes | all QA captures |
| `DayCycle.json` optional per-destination block | format reserved, not implemented | C destination palettes |
| `SurfacePalette` (world roles, per-destination lawns, UI tokens) | yes | C garden and destination kits |
| `GodotGeometry.Material(hex, position)` tone variants | yes | C kit pieces |
| Chip tap handler | stub (no action) | D day summary |
| `ConceptTheme.Ui` tokens, `UiCoin`, reserved title sub-pill slot | yes | B UI motion, D level pill and "Next" card, all later panels |
| Tween/ease helper | **not** in A | B owns it |
| Hotel level, goals, save changes | **not** in A | D owns them with a save migration |

## Out of scope for Phase A

Point lights, particles, easing and squash animation (B); new geometry, garden dressing, floor and wall detail (C); hotel level, goals, persistent income pops, save schema changes (D); weather; seasons; per-destination lighting curves; a player-facing time lock.
