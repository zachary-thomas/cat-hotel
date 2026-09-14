# Neighborhood and manager play

The whole property remains visible in the overview. The garden now has colored amenity terraces, an orchard, flower boxes and a paved front street with a crossing, lamps, four passing cats and the striped Paw Mart kiosk. Fit all returns to the overview after exploring.

## Isometric views, doors and boundaries

Both views use a fixed orthographic isometric camera. **Outside** shows full walls, windows, a tiled roof, dormers and a chimney. **Inside** reveals the rooms. The preference persists across saves and hotel visits. Watch mode temporarily reveals its cat; leaving Watch restores the preference. Entering manager control or focusing a service switches inside.

Each open room has a hinged door; the hotel also has double front doors and a rear garden door. Tap a visible door to hold it open for four seconds. Nearby cats automatically open doors, and they close after the cats pass. Reduced motion changes door poses instantly. Guest visits, manager cleaning and maid routes use the door openings. Hidden room controls cannot be tapped through the exterior roof; outdoor labels remain interactive.

Dragging and wheel, trackpad or pinch zooming share the property bounds. Zooming out stops at Fit all, while zooming in allows exploration within those bounds. The road ends at the front property edge. Each completed wing repair moves the rear fence 2.5 world units and opens one colored garden strip, up to three. The manager can walk on newly opened land using side paths. Locked plots and boarded central corridors cannot be entered.

## Amenities

Tap a labeled outdoor site, or choose Hotel life → Amenities & garden. These purchases use earned Cat Coins, are permanent at the current hotel, and do not count as real-money purchases. Each open facility has cats using it.

| Amenity | Coins | Hotel level | Added income |
| --- | ---: | ---: | ---: |
| Kitty splash pool | 250 | 1 | 5/min |
| Private litter nook | 120 | 1 | 3/min |
| Rainbow playpen | 350 | 2 | 7/min |
| Catnip picnic garden | 450 | 2 | 9/min |

## Playing as the manager

The coral-vested cat marked You is your manager. Tap a bush, mouse or untidy room to send the manager over. The Manager menu lists available jobs and their rewards; Control the manager also enables tapping garden paths, the front pavement or the center aisle to walk. The character follows routes around the building, then uses shears or a broom when working. One job runs at a time.

- Trim a bush: four seconds of work after arrival, 15 coins. It regrows 90 seconds after completion.
- Chase the mouse: three seconds after arrival, 12 coins. The mouse scampers away and returns after 75 seconds.
- Tidy an open room: five seconds after arrival, 10 coins. Rooms gradually become untidy; there are no income penalties for leaving chores alone.
- Loose yarn: tap to collect five coins immediately. Each of three yarn spots has an independent saved 35-second cooldown.

Travel time depends on the manager's position. Rewards are granted on completion and cannot be collected twice. Existing room upgrades and wing repairs remain available.

## Housekeeping

At hotel level 3, hire Daisy in Manager for 600 coins. This is a one-time purchase per hotel. She automatically reserves an untidy room, walks to it and sweeps. The manager cannot clean a room already assigned to Daisy. Hired housekeeping leaves rooms tidy after a long absence and does not generate repeat coin rewards.

## Paw Mart

Tap the front kiosk or open Hotel life → Visit Paw Mart. The shop links to garden amenities and housekeeping. A 30-coin treat picnic brings passing cats over for 25 seconds and gives the favorite guest three friendship. It has a two-minute cooldown. This shop uses earned coins; the separate expansion Shop retains its existing purchase behavior.

## Persistence and verification

Amenities, yarn cooldowns, bushes, mouse visits, dirty rooms, manager location and in-progress jobs, maid employment and work, and treat timers are saved. Older saves without neighborhood data receive a fresh neighborhood without losing hotel progress. Failed transactions restore both currency and gameplay state. Assigned manager work finishes while away; its one-time reward remains in the collection envelope, including after the passive-income cap.

The ninth suite, tests/test_views.gd, checks isometric projection, the actual view button, save migration, roof hit blocking, door animation and automatic opening, reduced motion, bounded exploration, zoom limits, garden progression and saved garden walks. Both suites support rendered phone captures.

The eighth behavioral suite, tests/test_grounds.gd, covers purchases and duplicate prevention, real rewards, respawns, routes, work completion, legacy migration, invalid saves, offline behavior, UI taps, amenities in the scene, passing cats, housekeeping, reduced motion and phone screenshots.
