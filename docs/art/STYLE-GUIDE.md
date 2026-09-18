# Purrington Hotel — Art Style Guide

**Status:** locked for colorful pass (2026-09-18)  
**Game:** Purrington Hotel (cat-hotel) — cozy mobile idle / hotel-management sim  
**Engines:** Unity (primary, migrating from Godot)  
**North star:** the illustrated voxel cards in `Assets/Resources/Art/` (welcome-hotel, world-map, garden, beach-gathering, lantern-gathering, and siblings)

This file is the source of truth for audits, prompt sheets, and Unity color work. Prefer this over older UI specs when hexes disagree.

---

## 1. Look in one sentence

Bright cozy **orthographic isometric voxels** — soft blocks, sunny light, pastel-leaning with punchy accents — plus soft illustrated menu cards that match that world. Colorful first; never muddy, never harsh black.

---

## 2. Medium and perspective

| Layer | Medium | Notes |
|---|---|---|
| World | Code-built voxel 3D (`VoxelWorld`, unit `1.1`) | Small cubes, slightly soft edges, readable silhouettes at phone size |
| Menu / activity cards | Illustrated PNGs (voxel-look renders) | Same warmth and saturation as the world boards |
| UI chrome | uGUI + TMP | Cream paper, mint/coral buttons; must not mute the world |

- **Perspective:** orthographic isometric (fixed).
- **Not:** crunchy 2D pixel art, realistic PBR, dark horror lighting, flat grey blockouts as final look.

---

## 3. Locked palette

Roles are fixed. Hexes below are the Unity / art target set. Spec variants that drift should be updated to match this table.

### Core UI

| Role | Hex | Use |
|---|---|---|
| Ink | `#173D32` | Body text, icons on light, strong outlines |
| Cream | `#FFF8E9` | Panels, cards, sheet backgrounds |
| Mint | `#60D6A6` | Primary actions, success, fresh accents |
| Coral | `#FFAB97` | Secondary warmth, alerts soft, cheeks / cozy accents |
| Gold | `#FFD16F` | Rewards, stars, lantern glow UI |
| Lilac | `#DFD2F5` | Soft tertiary panels, night / spa calm |

### World & illustration (colorful pass)

| Role | Hex | Use |
|---|---|---|
| Paper sand | `#F0D8C0` | Warm ground fill under scenes, beach sand cousin |
| Sky | `#A8D8F0` | Day skies, water highlights |
| Water | `#30D8F0` | Sea / pools (keep bright; foam reads white) |
| Grass | `#60A830` | Meadows, lawns (lift toward map greens, not olive mud) |
| Deep leaf | `#186030` | Tree clusters, shadow greens (still saturated) |
| Blossom | `#F078A8` | Flowers, pink room accent, cherry bloom |
| Lantern | `#F0A830` | Glow sources, golden hour, reward sparkle in-world |
| Wood | `#A86030` | Furniture, fences, trunks |
| Clear (Godot legacy) | `#EDE8D9` | Neutral clear color / empty stage |

### Room accent triad (from welcome-hotel)

Keep guest rooms clearly color-coded:

| Room | Accent | Bed / rug / tree |
|---|---|---|
| Clover | green | mint–grass family |
| Sun | yellow | gold–lantern family |
| Heart | pink | blossom–coral family |

**Do:** push saturation toward the Resources/Art boards.  
**Don't:** crush the world down to the quieter cream-mint chrome; don't invent new hero hues without updating this table.

---

## 4. Lighting and mood

- Day default: bright midday, soft colorful shadows, clear blue or cream sky.
- Accent moments: golden-hour lantern gatherings, spa pastels, beach high-key sun.
- Glow: small lamps and lanterns are warm (`#F0A830`), never harsh white.
- Avoid: heavy vignettes, desaturated fog, pure black `#000000` fills.

---

## 5. Characters

- Chibi voxel cats: large heads, simple closed-eye smiles, readable fur blocks.
- Coat variety: orange tabby, grey/white, tuxedo, calico, cream — keep contrast high on cream grounds.
- No realistic fur shaders; no scary teeth.

---

## 6. UI illustration cards (runtime art)

**Count today:** 18 PNGs, mirrored Godot `assets/ui/mobile/` ↔ Unity `Assets/Resources/Art/`.

| Kind | Canvas | Examples |
|---|---|---|
| Wide boards | 1536×1024 | welcome-hotel, cats-01..03, care-toys, nap-gathering |
| Square activities | 1254×1254 | gatherings, garden, beach/spa/trail/lantern, paw-mart, staff, scrapbook, reward, upgrade-lounge |
| Tall map | 1024×1536 | world-map |

- Godot import historically caps longest side at **1024**; author at the canvases above, then validate in-engine.
- Naming: kebab-case (`welcome-hotel`, `beach-gathering`).
- **Do not** bake prices, soft currency amounts, or localization strings into the art.
- Portrait / toy atlases: keep readable cells (legacy slots ~64–88 phone units).

Fonts: **Fredoka** (headings), **Nunito** (body).

---

## 7. Target resolutions

Phone portrait first.

| Context | Size |
|---|---|
| Godot reference viewport | 450×900 (override tests 1280×800) |
| Unity default | ~430×932 |
| Design test set | 360×640, 360×800, 390×844, 430×932, 1280×800 |

World scale: lot cells; `VoxelWorld.Unit = 1.1`; half-cell furniture / nav where already used.

---

## 8. Do / don't

**Do**

- Match saturation and warmth of the Resources/Art vibe boards.
- Color-code rooms and biomes so destinations read at a glance.
- Keep paw-print motifs consistent on props and signs.
- Leave world visible under UI; chrome is paper and mint, not a flat takeover.

**Don't**

- Ship grey / brown blockouts as final meadow or hotel look.
- Mute voxel materials to match old quiet UI tokens.
- Trace or lift character designs from other games.
- Add UI text into illustration PNGs.
- Recolor production assets without updating this guide and noting the hex.

---

## 9. Source of truth order

1. This style guide  
2. Production art inventory / prompts under mobile-ui-redesign docs  
3. Playful mobile UI design spec (layout, hit targets ≥48/56)  
4. In-code `HotelUI` / voxel color constants — must be updated to match §3 when they drift  

---

## 10. Colorful pass — bot handoff

Work that applies this guide:

1. **Unity color pass** — `HotelUI` tokens + voxel / biome materials → §3 hexes; Meadow and hotel interiors first.  
2. **Asset / prompt sheets** — new or replacement cards use §3 + §6 canvases; say “illustration brief,” never “finished art,” when handing to an image tool.  
3. **Audit** — any new PNG or material: check hex roles, canvas size, kebab name, no baked text.

When in doubt, open welcome-hotel and world-map and match their energy.
