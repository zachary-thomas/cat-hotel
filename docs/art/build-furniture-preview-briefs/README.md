# Build furniture PREVIEW — illustration-brief pack

**Side of line:** illustration briefs / prompt sheets only.  
**Not finished art.** Do not generate or overwrite production PNGs from this pack until Construction / Card & Asset Producer explicitly commissions image generation.

**Game:** Purrington Hotel (cat-hotel)  
**Owner:** Card & Asset Producer  
**Style SoT:** `cat-hotel-scan/docs/art/STYLE-GUIDE.md` (locked colorful pass, 2026-09-18)  
**Prompt voice:** same “Use case: stylized-concept…” pattern as `docs/mobile-ui-redesign/production-art-prompts.md`, updated to **1254×1254** and STYLE-GUIDE §3 hex roles.

---

## Purpose

Produce paste-ready illustration briefs for **Build catalogue card previews** so Construction can bind Image sprites instead of (or in addition to) the current procedural “native block illustrations” in Unity `HotelUI.VoxelIcon` / Godot `furniture_thumbnail.gd`.

These briefs are for **catalogue thumb dioramas**: single centered furniture item, cream ground, no baked UI text/prices/numbers.

UI layout reference for card framing only: `docs/mobile-ui-redesign/01-hotel-build-cat-care.png` and after/current Build catalogue shots under `docs/mobile-ui-redesign/`. `Assets/Resources/Art/` menu boards are **north-star vibe**, not live Build UI screenshots.

---

## Canvas

| Field | Value |
|---|---|
| Author canvas | **1254×1254** (square) |
| Aspect | 1:1 catalogue thumb |
| Ground | Cream `#FFF8E9` with generous empty margin |
| Perspective | Orthographic isometric soft voxels / clay-papercraft |
| Text | Forbidden in PNG (prices, names, coins, UI chrome) |

If Construction later wants smaller runtime sprites, still **author square at 1254** and downscale; do not author non-square.

---

## Naming / path convention (Construction binding)

**Chosen convention:**

```
Assets/Resources/Art/build-previews/{kebab-id}.png
```

Rules:

1. `{kebab-id}` = catalogue `id` with underscores → hyphens (e.g. `sun_cushion` → `sun-cushion.png`).
2. Flat folder under Art: **`build-previews/`** (keeps menu boards and Build previews separable).
3. Do **not** use a `build-` filename prefix; the folder already scopes the set.
4. Sprite load key for Construction: Resources path  
   `Art/build-previews/{kebab-id}` (Unity Resources, no extension).
5. Godot mirror (when needed): `assets/ui/mobile/build-previews/{kebab-id}.png`.

Examples:

| Catalogue id | Filename | Resources path |
|---|---|---|
| `mat` | `mat.png` | `Art/build-previews/mat` |
| `sun_cushion` | `sun-cushion.png` | `Art/build-previews/sun-cushion` |
| `adventure_tree` | `adventure-tree.png` | `Art/build-previews/adventure-tree` |
| `cafe_table` | `cafe-table.png` | `Art/build-previews/cafe-table` |

**Rejected alternative:** `Assets/Resources/Art/build-{kebab-id}.png` (pollutes the Art root next to menu boards).

---

## Gap status summary

| Bucket | Count | Illustrated PNG thumb today? | Brief in `prompts.md`? |
|---|---:|---|---|
| Unity `Catalog.All` (GodotReference.json) | **38** | No — procedural role blocks only | **Yes — all 38** |
| Godot `creative_content.gd` CATALOGUE | **38** (same ids) | No — `furniture_thumbnail.gd` draws | **Yes — all 38** |
| Unity `Catalogue.asset` presentation override | **26** | No | Covered (Furniture + Garden subset) |
| **Furniture** category | **24** | Needs illustrated preview | **Yes — done** |
| **Outdoors** category | **14** | Needs illustrated preview | **Yes — done** |
| Existing `Assets/Resources/Art/*.png` | **18** | Menu / activity boards only — **not** furniture thumbs | N/A |

**Covered by briefs:** Furniture **24** done + Outdoors **14** done = **38 / 38** placeables.  
**Placeable gap remaining:** **0**.  
**Still out of scope (optional):** room fixtures `room_nightstand`, `suite_sofa`, `suite_table` from Godot `furniture_catalog.gd` (not in placeable CATALOGUE).

Unity Build cards currently call `VoxelIcon(role)` — shared geometry-by-role placeholders (bed/seat, play, reception, default plant). That is **geometry/procedural thumb**, not per-item art. All placeables **need illustrated preview** for Construction Parity catalogue polish — briefs are ready; PNGs not generated from this pack.

---

## Pack contents

| File | Role |
|---|---|
| `README.md` | This file — purpose, canvas, naming, gap summary |
| `inventory.md` | Full id table + Unity vs Godot + thumb status |
| `prompts.md` | Paste-ready illustration briefs for Furniture (24) + Outdoors (14) |

---

## Style lock (brief reminder)

- Orthographic isometric soft voxels; colorful; sunny; soft beveled clay/papercraft.
- Hex roles: Ink `#173D32`, Cream `#FFF8E9`, Mint `#60D6A6`, Coral `#FFAB97`, Gold `#FFD16F`, Lilac `#DFD2F5`, Paper sand `#F0D8C0`, Sky `#A8D8F0`, Water `#30D8F0`, Grass `#60A830`, Deep leaf `#186030`, Blossom `#F078A8`, Lantern `#F0A830`, Wood `#A86030`.
- North-star vibe: welcome-hotel, garden, gatherings boards.
- Chibi voxel cats **optional only** on bed/seat items when a cat improves readability; prefer **item-as-hero**.
- Say “illustration brief,” never finished art, when handing to an image tool.
