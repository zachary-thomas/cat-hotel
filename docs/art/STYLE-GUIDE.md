# Purrington Hotel — concept-derived art direction

Updated 2026-09-22. Unity is the primary implementation; Godot remains the behavior reference.

## Visual source of truth

The original images in `docs/concept-art/02-hotel-overview.png` and `docs/concept-art/06-cat-world-revision.png` take precedence over this guide, runtime illustration cards, and existing color constants. These images show a miniature timber-and-plaster hotel surrounded by a layered flowering garden. Match their materials, silhouettes, lighting, and quiet UI rather than merely increasing saturation. The earlier “locked colorful pass” is superseded.

## Materials and color

These are practical approximations interpreted from the original concepts, not claimed pixel samples. Use shade variation within each material family.

| Material / role | Target | Application |
| --- | --- | --- |
| Warm cream paper | `#F8F3E3` | Panels and speech bubbles |
| Forest ink | `#244335` | Text, signs, icons |
| Selected sage | `#DCE5C5` | Quiet selected surfaces |
| Moss action | `#789B58` | Primary actions |
| Cream plaster | `#EFE2C9` | Walls and warm trim |
| Honey timber | `#B3824C` | Furniture, exposed beams, fences |
| Pale timber | `#D2AD77` | Floor planks |
| Moss upholstery | `#738448` | Beds, runners, plants |
| Deep foliage | `#425C35` | Leaf shade, green painted joinery |
| Terracotta | `#BF7958` | Accent beds, upholstery, pots |
| Clay UI accent | `#D6A182` | Secondary actions |
| Honey | `#D7AE55` | Gold upholstery, rewards, lamps |
| Warm stone | `#BBB6A5` | Paths and masonry |

Keep individual fur markings and readable face contrast. Do not blanket-desaturate the entire scene. Legacy geometry is recolored through `ConceptTheme`, preserving its underlying constructors and mesh details. Authored water remains a separate material.

## World and lighting

- Retain orthographic isometric voxel geometry, with layered cubic foliage and readable furniture silhouettes.
- Use golden daylight, warm cream fill, and soft grounded shadows. Evening remains cooler with warm lamps.
- Room walls are cream plaster over quiet moss painted paneling; floors read as staggered timber planks rather than a pastel checkerboard.
- Exterior paths use warm stone variation, including the authored village sidewalk. This is a path-specific material role: furniture and room floors keep timber even where the legacy export reused the same color.
- Garden greens vary from deep foliage to sunlit moss, with small cream/honey flowers and terracotta touches. Keep entrances and walking routes clear.
- Avoid neon mint, bubblegum wall bands, uniformly orange wood, and bright cyan sky as the Meadow's dominant look.

## UI and catalogue

Use compact cream panels, dark forest text, sage selection, rounded shapes, subtle shadows, and restrained clay/honey accents. Follow the layout and softness of the source screenshots without copying their baked-in labels. Maintain touch targets and legibility at 360×640 and enlarged text.

Catalogue previews must show each item's actual Unity geometry and the same concept materials as the placed object. Regenerate using **Purrington → Art → Regenerate catalogue previews** after geometry or material changes. The Editor captures consistent orthographic views into `Assets/Resources/Art/build-previews`; gameplay only loads these imported sprites.

## Review

Compare world and UI captures directly against the two original concept images. Runtime `Resources/Art` illustrations remain optional content cards, not palette authority. Check portrait sizes 360×640, 390×844, 430×932 and landscape 1280×800; confirm cats remain visible against furnishings and speech is readable over gardens.
