# Purrington Hotel: Main Street, shops, and town square

September 22, 2026 · Unity (`unity/PurringtonHotel`) · design from the September 22 brainstorming conversation.

## Purpose and scope

Turn Meadow House's existing front street into a place the player's cat manager can visit. Both Paw Mart and a separate clothing store are open from the start. The first release is Meadow House only. The manager can be renamed, dressed with the shared wardrobe, and customized with six coat colors and four marking patterns. Matching streets at the other hotels and a restaurant with recipes are later expansions.

The hotel remains an idle game. Shop visits, quests, and square events offer new cats and memorable scenes; supplies do not deplete during ordinary hotel operation. All purchases use earned Cat Coins. The Godot game and its saves are separate.

## Player journey

1. From Hotel or Life, choose **Explore Main Street**. The manager appears at the hotel's front entrance; the camera follows or can be panned manually. Tap accessible pavement or a destination to send the manager there. The manager panel offers a live preview and choices for name, coat, markings, and owned clothes. **Fit hotel** and **Follow manager** restore useful framing. A **Skip walk** control completes a valid route without waiting.
2. Main Street is continuous with the existing road. The square is a short walk to the east, with Paw Mart on one side and the clothing store on another. Two kiosks and a small event space face the square. Existing street cats still pass by, but walkable paths and storefront approaches do not intersect their routes.
3. Outside, each shop has an opaque roof and walls. Tapping its sign or door routes the manager to the entrance. The interior is shown only after the manager reaches that door. The exterior and interior use distinct camera modes; neither is visible through the other.
4. Inside, the player taps the cashier. The manager walks to the counter, and a named shop owner opens a sheet with **Talk**, **Quest**, **Buy**, and **Leave**. The player does not pick up each item from an aisle. On Leave, the manager appears at the same street door. Back closes the dialogue before exiting the shop.
5. Paw Mart sells optional hotel specials. A shopper and the manager can push voxel carts in short, coordinated store routines. The cart's wheels and contents animate. Reduced motion keeps the route and purchase accessible while removing bobbing and wheel animation.
6. The clothing store offers a live try-on on the manager or a selected known cat. Purchased items enter the shared hotel wardrobe and can later be equipped from Cats. Existing friendship-gift items remain gifts. The manager's chosen name and outfit appear in the world and UI.
7. The first square event is **Market Day**. It is started by an optional Paw Mart market bundle, runs for 90 seconds of active game time, places two kiosks and visiting cats in the square, and produces a short hotel arrival/reaction afterward. Leaving the game pauses the visible event; returning resumes the remaining time. It never penalizes hotel income.

## Initial content

| Place | Owner/interaction | First purchase or quest | Result |
| --- | --- | --- | --- |
| Paw Mart | Grocery cashier | 30-coin Welcome Basket quest; 80-coin Market Day bundle | The basket invites Biscuit (existing cat id 5) to visit the hotel. If already known, Biscuit visits and the player receives 40 coins once. The bundle starts Market Day. |
| Clothing store | Clothing cashier | Free First Look quest; existing wardrobe catalogue | Trying on and equipping a complimentary store ribbon completes First Look. The ribbon is an additional neck item, owned once, usable by any known cat. |
| Town square | Event notice board | Market Day, available whenever no event is active and a bundle is owned | Two kiosks, shoppers, and a hotel reaction. No forced daily schedule. |

The manager defaults to **Manager** until renamed, with a honey coat and solid markings. Names are trimmed, 1–24 visible characters, and displayed as plain text (no rich-text tags). Rename and appearance changes are always available from the manager panel and cost no coins. The six coat choices are honey, cream, ginger, cocoa, gray, and charcoal; the four marking choices are solid, tuxedo, tabby, and patchwork. Coat and markings combine on one cat rig rather than requiring 24 separate meshes. The manager has a separate equipped-outfit record but uses the same hotel-owned wardrobe as the other cats. Shop purchases and quest rewards are transactions: insufficient coins, duplicate claims, and save failures leave the state unchanged. Accepting First Look grants the complimentary ribbon; equipping it completes the quest.

## New voxel asset and animation inventory

| Set | Assets to author | Motion/poses |
| --- | --- | --- |
| Street and square | Widened walkable paving, plaza pattern, crosswalk, curb transitions, fountain or planter centerpiece, two benches, two lamps, event board, two kiosk shells, market awnings, flags and flower/produce stall dressing | Kiosk opening, flags/leaves, cats browsing and chatting |
| Paw Mart exterior | Distinct grocery storefront, Paw Mart sign, opaque roof, door, display window, crates and awning | Door open/close, arrival/exit |
| Paw Mart interior | Shelves, produce bins, chilled cabinet, checkout counter, register, basket stacks, three readable grocery product groups, one reusable four-wheel cart prefab with handle and swappable basket contents | Manager and NPC cart push, turn, stop/park, checkout handoff; wheels spin during travel |
| Clothing store exterior | Distinct boutique storefront, sign, opaque roof, door, display windows and mannequins | Door open/close, arrival/exit |
| Clothing store interior | Head/neck/back displays, two racks, mirror, try-on platform, checkout counter, register, folded-clothes stacks | Shop owner greeting, try-on pose, turn for preview, happy reaction, checkout handoff |
| Cats and wear | Manager rig using the existing cat skeleton and six coats/four marking recipes; coat/pattern preview swatches; two distinguishable shop-owner cats; two shopper looks; complimentary store ribbon; planned 12 wardrobe pieces reused rather than duplicated | Manager walk/idle/talk, owners talk/gesture, shoppers browse, outfit follow-through on head/body bindings |
| UI and feedback | Main Street entry/follow/skip controls, storefront labels, owner portraits or live closeups, conversation choices, quest cards, price and ownership states, event timer, outfit preview thumbnails | Reduced-motion equivalents for every required cue |

All new geometry follows `docs/art/STYLE-GUIDE.md`: block-built silhouettes, cream plaster, honey timber, moss, stone, and restrained terracotta. Shops and carts need identifiable silhouettes at normal portrait zoom. Catalogue previews for new wear pieces show their real geometry.

## System boundaries

- **Town content** holds Meadow street nodes, store entrances, shop stock, quests, and event data. The same coordinates drive navigation, colliders, labels, and camera bounds. No hand-edited changes to the exported Godot geometry JSON are required; additive Unity art replaces specific decorative neighborhood homes around the square.
- **Town domain** owns manager name/coat/markings/outfit/location/destination, store purchases, quests, optional specials, and event state. It extends the current version-3 save with optional fields and validates them on load. Old version-3 saves receive defaults. Movement, rewards, and cooldowns are authoritative here; presentation never grants coins or cats.
- **Town navigation** joins the existing hotel entrance route to a small, authored pedestrian graph on the street and inside each shop. Invalid or blocked destinations fail visibly. Layout edits replan the hotel portion of a route. Manager movement does not alter guest reservations.
- **Town presentation** builds the square, two opaque storefronts, and one interior at a time. It uses the existing `GodotCatRig` bindings for the manager, shop owners, wear, and cart-push pose. Switching views preserves hotel camera state; leaving a shop returns to its door.
- **Town UI** offers touch-accessible destination buttons in addition to scene taps, a cashier dialogue sheet, and live try-on. Hotel construction input is disabled during street/store control, then restored.
- **Wardrobe integration** depends on the existing `2026-09-22-hotel-growth-05-wardrobe.md` plan. The clothing store is a second entry to that single catalogue and purchase transaction; it does not introduce a second clothing inventory.

## Recovery, accessibility, and verification

Manager name, last safe position, destination, quest completion, purchases, owned event bundles, and remaining event time survive save/reload. A route is recomputed from the saved position rather than storing raw waypoints. If the manager is in a shop when loading, the shop reopens at its entrance. A blocked route leaves the manager at the last safe point with a clear message. Store and quest actions roll back on save failure using the existing Retry flow.

Touch targets remain usable at 360×640 through 430×932, 100–150% text, and 1280×800 landscape. Reduced motion, focus, back, tab changes, app pause/resume, and an unavailable store interior must have explicit behavior. The first release is verified on Windows and through simulated touch; physical Android/iOS verification is a release gate, not assumed from desktop results.

## Sequencing and later work

The hotel-growth shell and wardrobe plans are already under way. Finish their domain and wardrobe interfaces before the clothing-store task. Main Street work splits into manager/navigation, storefront/interior framework, Paw Mart and carts, clothing-store integration, and square events. The restaurant can later reuse the cashier conversation, optional ingredient purchases, and event invitation systems, with authored dishes and no required recurring stock in the first release.
