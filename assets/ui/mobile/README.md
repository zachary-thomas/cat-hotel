# Mobile interface artwork

Status: all eighteen sources are consumed by the final interface. The exported-pack smoke checks each imported texture and verifies that design boards are excluded.

All PNGs are original text-free illustrations generated for this overhaul with the built-in image-generation tool, using the approved Purrington concept boards as style references. Sources remain at full resolution; paired Godot `.png.import` files limit the imported longest dimension to 1024 pixels. Display images with linear filtering and preserve aspect ratio. Every interactive label, price, timer and control is native UI driven by game state.

| Source | Screen use |
| --- | --- |
| care-toys.png | Six distinct toy-button illustrations, three columns by two rows |
| cats-01.png, cats-02.png, cats-03.png | Eighteen guest portraits, three columns by two rows per atlas |
| welcome-hotel.png | Welcome hotel illustration |
| world-map.png | Continuous four-destination journey; normalized native destination controls |
| reward.png | Pending offline earnings |
| upgrade-lounge.png | Lounge service upgrade |
| garden.png | Garden activity |
| staff.png | Staff/manager activity and three individual portrait crops |
| scrapbook.png | Scrapbook hub and empty memories |
| paw-mart.png | Paw Mart activity |
| nap-gathering.png | Great Nap gathering |
| gatherings.png | Cardboard gathering |
| lantern-gathering.png | Lantern gathering |
| beach-gathering.png | Seaside gathering |
| trail-gathering.png | Forest gathering |
| spa-gathering.png | Snowcap gathering |

Regular object and portrait slots use 64–88 phone units; full-scene banners, welcome and map use responsive image areas. Reduce optional art before shrinking controls at larger text sizes. Known guest portraits and the six care toys use the assigned atlases. Unknown guests use native hidden silhouettes. Furniture previews and the interactive care stage use native drawing and actual 3D.

Exact prompts: `docs/mobile-ui-redesign/production-art-prompts.md`.
Source dimensions and SHA-256 inventory: `docs/mobile-ui-redesign/production-art-inventory.json`.
Final verification and before/after evidence: `docs/mobile-ui-redesign/implementation-review.md`.

## Runtime bindings

`MenuArt.SCENES` caches fourteen scene PNGs. `GuestArt` preloads the three portrait atlases plus the toy atlas and caches imported-dimension regions. No prepared illustration is unused, and no source was regenerated during final verification. The eighteen source hashes match the inventory. Import limits are 1024; Journal photo thumbnails are capped at 640 pixels with at most 80 cached entries. Refresh prunes undisplayed photos before loading a new newest-first album.

| Required art family | Native binding and display treatment |
| --- | --- |
| Five dock icons | `GameIcon`: Hotel house, Cats face, Build hammer, Life plant, Map folded map; 30-unit slots |
| Coin / Settings | `GameIcon.coin` paw coin; `GameIcon.settings` gear; live native labels and 48-unit Settings target |
| View / Back / Close | Native labelled Hotel view / Inside / Outside / Fit controls; GameSheet back chevron; Build Play and Cancel labelled controls |
| Rotate / Undo / Redo / Adjust | Native rotation arrow, history arrows and adjustment glyph with full accessible captions in BuildPanel |
| Six toys | `GuestArt.toy(0..5)`: pink paw, brush, feather, yarn, cushion, box in labelled native buttons |
| Six Life activities | Garden, Staff, Scrapbook and Paw Mart PNG scenes; native Manager and Discoveries dioramas |
| Four destination postcards | `MenuArt.HOTEL_CENTERS` crops the reviewed world map at Meadow(.27,.70), Seaside(.79,.48), Forest(.30,.29), Snowcap(.74,.12) |
| Shared gatherings | Nap, cardboard and lantern scene PNGs |
| Destination gatherings | Beach, trail and spa scene PNGs |
| Three staff portraits | `MenuArt.staff_portrait` caches individual crops from staff.png |
| Welcome / Reward / Upgrades | Welcome hotel, reward concierge and lounge PNGs; other service cards use native isometric scenes |
| Empty / locked | Scrapbook empty illustration and copy; hidden guest silhouettes/locks; native catalogue empty copy; native disabled controls explain their live requirements |
| Live Hotel / Care | Runtime voxel hotel, cats, rooms, props and gesture-driven care stage; no concept board used as a background |

All illustrated decorations ignore pointer input; controls and prices remain native. Every PNG is paired with its committed import metadata. Export presets exclude docs, tests, tools, tmp, .tools and Markdown; only gameplay resources enter the PCK. Composite concept boards remain in documentation.
