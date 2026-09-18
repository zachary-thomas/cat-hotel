# Build furniture preview — inventory

Sources checked 2026-09-18 (America/Chicago):

- Unity SoT runtime list: `unity/PurringtonHotel/Assets/Resources/Content/GodotReference.json` → `Catalog.All` (**38** items; EditMode asserts length 38)
- Unity presentation overrides: `Assets/Resources/Content/Catalogue.asset` (**26** items; `ItemCatalogDefinition.Apply` patches matching ids)
- Godot placeable catalogue: `scripts/creative/creative_content.gd` `CATALOGUE` (**38** — same ids as Unity Catalog.All)
- Godot fixture extras (not Build catalogue placeables): `scripts/core/furniture_catalog.gd` → `room_nightstand`, `suite_sofa`, `suite_table`
- Art PNGs: `Assets/Resources/Art/` — **18 menu/activity boards only**; **zero** furniture-specific thumbs
- Unity thumbs today: `HotelUI.CatalogCard` → `VoxelIcon(role)` procedural uGUI blocks (“native block illustrations”)
- Godot thumbs today: `scripts/ui/furniture_thumbnail.gd` procedural `_draw` per id

## Legend

| Column | Meaning |
|---|---|
| Unity? | In `Catalog.All` / GodotReference |
| Cat.asset? | Present in `Catalogue.asset` (category may be remapped) |
| Godot? | In `creative_content.gd` CATALOGUE |
| Existing thumb? | Dedicated illustrated PNG for this id |
| Needs prompt? | Requires illustration brief for Construction Parity |
| First pack? | Furniture briefs in `prompts.md` (Furniture section) |
| Outdoors pack? | Outdoors briefs in `prompts.md` (Outdoors section) |

## Full catalogue table

| id | name | category (Catalog.All) | Cat.asset category | Unity? | Cat.asset? | Godot? | existing thumb? | needs prompt? | first pack? | outdoors pack? |
|---|---|---|---|---|---|---|---|---|---|---|
| mat | Linen mat | Furniture | Beds | Y | Y | Y | No (procedural) | Y | Y | N |
| sun_cushion | Sunshine cushion | Furniture | Beds | Y | Y | Y | No (procedural) | Y | Y | N |
| cave | Sheltered cat bed | Furniture | Beds | Y | Y | Y | No (procedural) | Y | Y | N |
| heated | Heated cloud bed | Furniture | Beds | Y | Y | Y | No (procedural) | Y | Y | N |
| box | Delivery box | Furniture | Play | Y | Y | Y | No (procedural) | Y | Y | N |
| perch | Window perch | Furniture | Play | Y | Y | Y | No (procedural) | Y | Y | N |
| tunnel | Play tunnel | Furniture | Play | Y | Y | Y | No (procedural) | Y | Y | N |
| tower | Climbing tower | Furniture | Play | Y | Y | Y | No (procedural) | Y | Y | N |
| table | Picnic table | Furniture | — | Y | N | Y | No (procedural) | Y | Y | N |
| plant | Leafy planter | Furniture | Decor | Y | Y | Y | No (procedural) | Y | Y | N |
| rug | Whisper-soft rug | Furniture | Decor | Y | Y | Y | No (procedural) | Y | Y | N |
| scratch | Rope scratcher | Furniture | Play | Y | Y | Y | No (procedural) | Y | Y | N |
| lamp | Amber lantern | Furniture | Decor | Y | Y | Y | No (procedural) | Y | Y | N |
| flowers | Welcome flowers | Furniture | Decor | Y | Y | Y | No (procedural) | Y | Y | N |
| blanket | Friendship blanket | Furniture | — | Y | N | Y | No (procedural) | Y | Y | N |
| cloud_sofa | Cloud sofa | Furniture | — | Y | N | Y | No (procedural) | Y | Y | N |
| adventure_tree | Adventure tree | Furniture | Play | Y | Y | Y | No (procedural) | Y | Y | N |
| canopy_bed | Canopy bed | Furniture | Beds | Y | Y | Y | No (procedural) | Y | Y | N |
| reception_counter | Welcome counter | Furniture | Hotel | Y | Y | Y | No (procedural) | Y | Y | N |
| milkshake_counter | Milkshake counter | Furniture | — | Y | N | Y | No (procedural) | Y | Y | N |
| cafe_stool | Café stool | Furniture | — | Y | N | Y | No (procedural) | Y | Y | N |
| cafe_table | Café table | Furniture | Hotel | Y | Y | Y | No (procedural) | Y | Y | N |
| lounge_sofa | Lounge sofa | Furniture | Hotel | Y | Y | Y | No (procedural) | Y | Y | N |
| fireplace | Fireside hearth | Furniture | — | Y | N | Y | No (procedural) | Y | Y | N |
| garden_planter | Garden planter | Outdoors | Garden | Y | Y | Y | No (procedural) | Y | N | Y |
| shrub | Round shrub | Outdoors | Garden | Y | Y | Y | No (procedural) | Y | N | Y |
| flower_bed | Flower bed | Outdoors | Garden | Y | Y | Y | No (procedural) | Y | N | Y |
| garden_lamp | Garden lamp | Outdoors | Garden | Y | Y | Y | No (procedural) | Y | N | Y |
| bench | Garden bench | Outdoors | Garden | Y | Y | Y | No (procedural) | Y | N | Y |
| tree | Shade tree | Outdoors | Garden | Y | Y | Y | No (procedural) | Y | N | Y |
| cat_statue | Little cat statue | Outdoors | Garden | Y | Y | Y | No (procedural) | Y | N | Y |
| fountain | Paw fountain | Outdoors | Garden | Y | Y | Y | No (procedural) | Y | N | Y |
| fence | Picket fence | Outdoors | — | Y | N | Y | No (procedural) | Y | N | Y |
| gate | Garden gate | Outdoors | — | Y | N | Y | No (procedural) | Y | N | Y |
| pool | Kitty splash pool | Outdoors | — | Y | N | Y | No (procedural) | Y | N | Y |
| litter | Private litter nook | Outdoors | — | Y | N | Y | No (procedural) | Y | N | Y |
| playpen | Rainbow playpen | Outdoors | — | Y | N | Y | No (procedural) | Y | N | Y |
| picnic | Catnip picnic garden | Outdoors | — | Y | N | Y | No (procedural) | Y | N | Y |

## Counts

| Set | Count |
|---|---:|
| Unity Catalog.All | 38 |
| Godot CATALOGUE | 38 |
| Catalogue.asset overrides | 26 |
| Furniture (first pack briefs) | 24 |
| Outdoors (outdoors pack briefs) | 14 |
| Existing illustrated furniture PNGs | 0 |
| Placeables needing illustrated PNG | 38 |
| Covered by briefs (Furniture + Outdoors) | **38** |
| Placeable brief gap remaining | **0** |
| Optional fixtures still out of scope | 3 (`room_nightstand`, `suite_sofa`, `suite_table`) |

## Unity vs Godot clarity

- **Placeable id parity:** Unity `Catalog.All` and Godot `CATALOGUE` share the **same 38 ids**. No Unity-only / Godot-only placeable skew in the reference content.
- **Category naming skew:** Runtime JSON uses `Furniture` / `Outdoors`. `Catalogue.asset` remaps a **26-id subset** to Build chips `Beds` / `Play` / `Hotel` / `Decor` / `Garden` and does **not** list six Furniture ids (`table`, `blanket`, `cloud_sofa`, `milkshake_counter`, `cafe_stool`, `fireplace`) nor six Outdoors amenity/fence ids (`fence`, `gate`, `pool`, `litter`, `playpen`, `picnic`). Those twelve still exist in `Catalog.All` and appear under `All` / their JSON category when Build browses `Catalog.All`.
- **Fixtures (Godot only extras):** `room_nightstand`, `suite_sofa`, `suite_table` are included room fixtures, not catalogue shop rows — omit from Build preview pack unless Construction requests fixture cards later.

## Thumb technology note

| Engine | Today | Parity target |
|---|---|---|
| Unity | Role-shared uGUI block icon (`VoxelIcon`) | Per-id Image sprite at `Art/build-previews/{kebab-id}` |
| Godot | Per-id procedural draw (`furniture_thumbnail.gd`) | Optional mirror PNG under `assets/ui/mobile/build-previews/` |

**Geometry/procedural thumb vs needs illustrated preview:** every row above is procedural today → **needs illustrated preview** for the colorful illustrated catalogue cards called out in migration UI briefs.
