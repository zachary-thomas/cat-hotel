# A little more life at Purrington

Cat conversations now use cream speech bubbles with names, replies, and coordinated paw, ear, head, and tail gestures. Nearby cats occasionally pause together and then resume their reserved activity. Short authored exchanges reflect sunshine, naps, snacks, play, friends, and nearby fountains or fireplaces.

The fireplace has flickering voxel flames and rising embers. The fountain has a pulsing spout and splashes. Cats kick up brief litter puffs while digging, and the milkshake machine vibrates and foams during service. Boxes, scratchers, toys, cushions, foliage, lanterns, and reception bells also have small animations.

## See it

- [Cat conversation animation](conversation.webp) — a natural exchange found by running the ordinary starter hotel simulation.
- [Furniture animation demonstration](furniture.webp) — the actual world renderer and activity bridge, with a controlled arrangement demonstrating the four main objects.
- [Phone conversation](phone-conversation.png), [closer view](phone-conversation-close.png), and [reply](phone-reply.png).
- [Large text](phone-large-text.png) and [desktop](desktop-conversation.png).
- [Furniture in use](furniture-in-use.png).

Captures use disposable test profiles. They do not modify a player's save.

## Behavior

- Bubbles keep a readable screen size when the camera zooms, avoid nearby labels and faces, and allow hotel gestures to pass through them.
- A conversation has two or three lines, with a short response pause. Each cat and pair has a cooldown. Sparse hotels have fewer encounters because cats need to be near one another in the same open area.
- Compatible stationary cats preserve their current activity timer and reservation during a short shared pause, then resume. Conversations award no extra visit or payment.
- Digging and service effects read the real activity of their placed object. Furniture movement, rotation, storage, undo, and reload retain the correct effects.
- Animated motion off keeps readable static bubbles and resting objects. Build mode and covered hotel pages suppress chatter. Background pauses stop decorative animation.
- Existing purchased objects gain their effects automatically.

## Implementation and verification

The implementation lives in the active creative game. Dialogue and moment scheduling are separate from the screen overlay and the reusable furniture animation controller. New tests cover conversation ordering and cancellation, wall separation, real simulation integration, bubble layout/input, gesture root positions, per-object activity, particle lifetime, and reduced motion.

The complete creative suite passed (22 suites), along with shared legacy cat collision, experience, and app checks. A rendered dense property with 24 rooms, 98 objects, and 18 guests measured 17.96 ms/frame on the local desktop GPU; its simulation measured 0.647 ms/frame. These are local measurements, not physical-phone performance claims.

Reproduce the captures with `tools/capture-lively-preview.gd` and `tools/capture-lively-objects.gd`. `tools/check-lively-simulation.gd` reports actual conversation opportunities across all four starter maps. The original [approved design](../../superpowers/specs/2026-09-15-lively-hotel-design.md) records the feature scope.

Optional new sound accents remain a future polish choice; this update uses the existing sound settings and assets.

Both Windows preview packages were rebuilt with these changes. The packaged game passed direct launch, rendered save/reopen, and legacy-save isolation checks. Launch the updated game with [Play.cmd](../../../builds/windows/Play.cmd).
