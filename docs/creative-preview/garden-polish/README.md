# Meadow, movement and voxel polish

The starting hotel now has two connected guest rooms, reception and a sunny hall, with no sofas. Thirty editable outdoor pieces form a fountain court, play and picnic garden, and planted arrival area. A road, sidewalk and crossing place the hotel in its neighborhood.

## Actual game captures

- [Phone opening](hotel-390x844-100.png)
- [Enlarged text](hotel-360x640-150.png)
- [Full property](meadow-overview.png)
- [Reception details](reception-close.png)
- [Fountain garden](fountain-garden.png)
- [Exterior](hotel-exterior.png)
- [Room warning on phone](room-warning-phone.png)
- [Movement recording](movement.webp)

These images come from the running Godot game. The original concept board remains the visual reference. All furniture and scenery use cuboid voxel parts, including the fountain's water volume and moving spillway droplets. Shadows and interface text use their normal rendering surfaces.

## Behavior and review

Navigation uses safe diagonal routes and straight visible segments, preserving walls, objects, owned land and constructed access. Arrivals, walking cats, housekeeping and activity positions stay physically separated. Idle cats and housekeeping can step aside. Rendered furniture positions account for real seat width; only height and facing ease between poses, so smoothing cannot cut through a wall.

Room problems use readable screen-space badges anchored above rooms, with safe-area placement and text scaling. The receptionist stands on a properly sized platform. Windows, beds, benches, plants, desks, rugs and picnic blankets have additional voxel details; animated water respects reduced motion.

Independent review found two issues, both fixed and regression-tested: replacing a model with an equal revision could retain the old world geometry, and idle housekeeping did not execute its yielding route. The final full suite and native captures verify their corrections.

Existing saves retain their layouts. **Settings → Start fresh** offers a confirmation before resetting preview progress to this new opening. Failed saves retain the prior hotel.

See [verification results](../verification.md) for coverage, measurements and platform limits.
