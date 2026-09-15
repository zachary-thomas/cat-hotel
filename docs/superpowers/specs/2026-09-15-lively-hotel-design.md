# A livelier, cuter Purrington Hotel

**Date:** September 15, 2026

**Status:** Implemented, reviewed, and packaged.

**Goal:** Make watching the hotel rewarding through readable cat conversations, expressive shared moments, and furniture that visibly responds to use.

The user confirmed that the requested effects are fireplace sparks, fountain water spurts, and litter puffs when a cat uses the litter box.

**Implementation notes:** The delivered feature and rendered recordings are documented in [the lively hotel preview](../../creative-preview/lively-hotel/README.md). Compatible stationary cats briefly pause their existing activity timer and reservation to exchange lines, then resume. This adjustment made natural conversations possible in the starter layouts without adding visits or payments. The 20–35 second interval schedules opportunities; sparse hotels can take longer to produce a nearby eligible pair. New sound accents remain optional future polish. Desktop rendering includes phone-sized layouts; physical-device performance has not been measured.

## 1. Direction

Keep the current warm, block-built art style. Add character through deliberate poses, small rigid voxel particles, readable cream speech bubbles, and brief coordinated sequences. Give each moment a clear beginning, response, and ending, with quiet time between moments.

### Approaches considered

| Approach | Benefit | Tradeoff |
| --- | --- | --- |
| **Coordinated conversations and reactive furniture — recommended** | Connects visible effects to the cats and objects already in the hotel; can ship in focused phases. | Needs a small shared system for timing and identifying moments. |
| Bigger labels and ambient animation loops | A quick improvement to visibility and movement. | Does not deliver actual replies or coordinate cats with objects. |
| A broader relationship and story simulation | Supports longer stories and more complex social behavior. | Adds new gameplay rules and balancing work beyond this visual-life update. |

## 2. What is already available

The active game uses `scenes/creative_hotel.tscn` and the scripts under `scripts/creative`.

- `social_simulation.gd` already manages named guests, preferences, friend IDs, activity reservations, reception, ordering, service, seating, and housekeeping.
- `creative_world.gd` currently assigns short phrases such as “One shake, please” and “Coming right up” to a cat's floating `Label3D`. These are activity labels rather than scheduled back-and-forth conversations.
- `voxel_cat.gd` already provides head, ears, paws, tail, blinking, grooming, stretching, greeting, purring, and friendship poses. Much of the expressive vocabulary can be reused.
- `creative_water_motion.gd` already animates 56 cube droplets across the fountain's spillways. Enhance that effect instead of replacing it.
- Fireplace flames and the milkshake machine currently belong to static furniture geometry. Their moving pieces need independent animation roots.
- The litter nook already exists as an amenity, but needs a distinct digging action and a matching visual pose.
- The fountain is decorative and is excluded from activity venues. Nearby reactions need a proximity check; they should not turn the fountain into a new income-producing service.
- Existing settings include animated motion, sound effects, and text scaling through 150%.

## 3. Readable little conversations

### Bubble appearance

- Rounded warm-cream bubble, dark green text, soft shadow, and a short tail pointing to the speaking cat.
- Show the speaker's name as a small heading. Keep dialogue to one or two short lines.
- Render bubbles as a screen overlay anchored above the cat's head, so text stays readable as the camera zooms.
- Start with 16–18 logical-pixel dialogue text at normal text size, then apply the existing text-size preference.
- Use a quick, gentle entrance and fade out. Display the complete line immediately.
- Keep bubbles inside the usable hotel view and clear of controls, room warnings, and the cats' faces. If placement is impossible, skip the bubble.
- Bubbles let taps, drags, and pinch gestures reach the hotel underneath.
- Suppress decorative dialogue during furniture placement and when a full page or sheet covers the hotel. Hide bubbles for offscreen cats and cats covered by exterior roofs.

### Conversation rhythm

Initial tuning values, to be adjusted after watching the game:

- A conversation contains two lines, with an occasional third line for a short punchline.
- Each line remains for about 3–4 seconds, with a 0.3-second response pause. Three-line exchanges can run up to 12 seconds.
- Allow one featured exchange at a time. Show the current speaker's bubble, then hand attention to the reply. Permit at most one additional small, non-text reaction icon.
- Look for a new eligible exchange roughly every 20–35 seconds; aim for the first within 15–30 seconds once two suitable cats are nearby.
- Give each participant at least 45 seconds before another ambient conversation, and a pair at least 90 seconds before speaking together again.
- Keep the last eight conversation IDs in a recent-history list to avoid repetition. If all eligible lines are cooling down, wait.
- Select cats in the same open area, within roughly three lot cells, with no wall between them. Use compatible stationary activities with enough time remaining, or a short idle window that can be reserved safely.
- Prefer existing friends sometimes, while allowing any eligible pair to greet one another. Existing personality and preference data influences topic and gesture choice.
- Store the dialogue locally in an authored collection. Begin with about 30 short exchanges covering naps, sunshine, snacks, play, friends, the fountain, and the fireplace, plus service responses.

### Example moments

| Context | Exchange | Acting |
| --- | --- | --- |
| Sunny resting place | Miso: “I saved you a sunbeam.” Clover: “The warm bit?” Miso: “Obviously.” | Miso turns and lifts a paw; Clover tilts their head; both settle. |
| Beside the fountain | Bean: “I almost caught the water.” Clover: “Try asking it to stay.” | Bean tracks a droplet and bats a paw; Clover gives a slow blink. |
| Milkshake service | Guest: “Extra foam, please!” Attendant: “One cloud in a cup.” | Attendant reaches for the machine; the mixer runs; the guest perks up. |
| Fireside | Mochi: “Five more minutes.” Friend: “You said that three naps ago.” | Sleepy blink, small yawn, tucked paws. |

Names in these examples illustrate the tone. Actual lines use the participating cats' names and context.

## 4. Cat animation and shared moments

Build a small set of coordinated actions:

1. **Greeting:** face the other cat, lift a paw, and answer with an ear perk or head tilt.
2. **Talking and listening:** restrained head and mouth movement for the speaker; blinking, ear movement, and a small nod for the listener.
3. **Happy agreement:** a brief happy bounce or shoulder wiggle, followed by one small heart.
4. **Friend moment:** a gentle head bump or paw touch when safe positions already exist; otherwise use a wave and matching happy expressions.
5. **Shared rest:** two nearby resting cats settle together, followed by a small sleep symbol.
6. **Curiosity:** look at an object, lean in, lift a paw, and react to its motion.

Play gestures on the cat's visual body, head, and limbs. Preserve the authoritative ground position and collision spacing. Contact poses require enough space; fall back to non-contact gestures near narrow furniture or paths.

Give paired moments control of facing while they play, since the current world renderer normally turns cats toward their furniture. Cancel a moment cleanly when an activity changes, a participant leaves, or the layout changes. A reaction must not leave a cat frozen or override its next walk.

## 5. Furniture animation catalogue

| Object | Ambient animation | Cat or staff interaction |
| --- | --- | --- |
| **Fireside hearth** | Small voxel flames change height and warmth; a few embers rise and fade inside a bounded area. | A nearby resting cat warms its paws, slow-blinks, and settles. |
| **Paw fountain** | Retain the spillways; add a pulsing central spout, impact droplets, and blocky ripple accents. | A nearby stationary cat watches a spurt, bats a paw, and gives a tiny surprised reaction. |
| **Private litter nook** | Quiet at rest. | Brief sniff, turn, two or three digging motions, a small burst of tan litter cubes tied to each kick, then a satisfied exit. Keep the effect stylized and confined near the tray. |
| **Milkshake counter** | The blender rests between orders. | During actual service, the machine gently vibrates, its contents churn, and foam rises. The attendant reaches toward it, then presents the drink as service completes. |
| **Delivery box** | An occasional subtle flap twitch when occupied. | Curious peek, crouch, little pop-up, and a flap wobble. |
| **Rope scratcher** | Quiet at rest. | Alternating paw scratches, slight rope movement, and two or three tiny fibers. |
| **Play tunnel / playpen** | Sparse toy motion while occupied. | Paw swat or peek-out, followed by a small toy bounce. Use the placed toy instead of spawning a duplicate carried toy. |
| **Beds / cushions / sofas** | Subtle existing resting-cat breathing. | Kneading paws and a shallow cushion dip, then settling. |
| **Plants / flowers / trees** | Very slight, staggered movement of foliage groups. | A passing or nearby cat occasionally sniffs an accessible plant. |
| **Lanterns / garden lamps** | Slow, subtle changes in warm brightness. | May provide the context for a cozy resting reaction. |
| **Reception counter** | Quiet at rest. | A small bell bounce and attendant wave during a real check-in. |

The four bold objects are the first furniture milestone. Additional objects are a second pass using the same system.

Animations attach to the placed object ID and local transform, so moving, rotating, copying, storing, and restoring furniture all behave correctly. Existing purchased items receive the appropriate effect when rendered.

For the litter nook, reserve one usable approach and define a safe visual working pose near the tray. The digging kick and litter burst must share a timeline marker. Do not independently fire particles on a random timer.

For the blender, read active guest service at that specific counter. Multiple counters operate independently; overlapping service at one counter keeps its machine running until the last active service finishes. Show the final handoff only for a completed service.

## 6. Technical shape

Keep game rules and visual presentation separate, with a small bridge for timed moments.

| Area | Planned responsibility |
| --- | --- |
| New `scripts/creative/creative_moments.gd` | Own short-lived moment IDs, pair eligibility, timing, cooldowns, recent dialogue history, and cancellation. Consume actual actor and venue state. |
| New `scripts/creative/creative_dialogue.gd` | Local dialogue records: stable ID, topic, participant requirements, lines, speaker roles, gestures, and durations. |
| New `scripts/creative/creative_speech_overlay.gd` | Project head anchors to the screen, size and place bubbles, apply text scaling, manage overlap and visibility, and ignore pointer input. |
| New `scripts/creative/creative_object_motion.gd` | Reusable bounded particle bursts and moving furniture parts, with a motion switch, activity state, and reset behavior. |
| `scripts/creative/social_simulation.gd` | Expose real activity starts/ends, actors and source object IDs; integrate short eligible social windows and the litter-specific activity. |
| `scripts/creative/creative_model.gd` | Provide correct litter action/approach data and access to decorative objects for proximity reactions. Keep moment state transient. |
| `scripts/creative/creative_world.gd` | Connect moments to visible actors and object instances; resolve facing priority; supply camera and roof visibility; clear references after rebuilds. |
| `scripts/creative/creative_objects.gd` | Split movable parts from static batched geometry; add local anchors for flames, blender, litter, flaps, and later object effects. |
| `scripts/creative/creative_water_motion.gd` | Extend the existing fountain with spout and splash timing while retaining batched cube rendering. |
| `scripts/world/voxel_cat.gd` | Add paired gesture poses and explicit reset/priority handling without changing pathfinding. Preserve shared legacy behavior. |
| `scripts/creative/creative_ui.gd` and `creative_app.gd` | Supply usable view bounds and UI visibility; pass existing motion, text-size, sound, and application pause state. |

Each moment records its ID, participant IDs, optional object ID, line/gesture sequence, elapsed time, and expiry. Both bubbles and animations read the same timeline. Re-rendering an object or a cat must not replay a completed event.

Ambient effects can animate locally. Activity effects derive from the active state of their object. One-shot bursts use a unique moment ID and timeline marker so repeated scene updates cannot duplicate them.

## 7. Pacing, compatibility, and performance

- Apply the existing Animated motion setting to every new effect. With it disabled, show static bubbles and meaningful still poses; disable decorative shakes, bounces, and particles. Reset moving parts to their resting transforms when switching it off.
- Keep game simulation and activity rewards independent of the bubble animation. A conversation or cosmetic reaction does not award an additional visit or payment.
- Short-lived dialogue, particles, and reaction history are runtime state. Clear them on map changes, fresh starts, and reloads. Do not replay missed moments after returning to the app.
- Stop decorative animation in the background and during blocked simulation states. Drop expired events rather than queueing a burst of catch-up chatter.
- Build bubble controls and particle batches once and reuse them. Avoid one node per spark or rebuilding meshes every frame.
- Initial per-object budgets: up to eight fireplace sparks, twelve cubes per litter burst, and twelve additional fountain splash cubes alongside its existing droplets. Limit visible one-shot bursts to four at a time; reduce distant/offscreen decorative work.
- Use small, staggered timing differences so every flame, plant, and cat does not move together.
- Start visually. A later polish step may add a soft chirp, water plip, litter rustle, and blender hum through the existing sound-effects preference, with local audibility and concurrency limits.

## 8. Delivery order and review points

### Phase 1 — Conversations that are easy to see

- [x] Build the transient moment timeline and authored dialogue collection.
- [x] Add readable, properly anchored speech bubbles.
- [x] Connect actual replies to paired turning, greeting, listening, and happy gestures.
- [x] Tune cadence, cooldowns, bubble overlap, and interruption behavior.

**Review result:** A short in-game recording shows two nearby cats exchanging lines and reacting to each other at ordinary phone zoom.

### Phase 2 — The four requested object effects

- [x] Animate fireplace flames and rising sparks.
- [x] Enhance existing fountain water and add a nearby cat reaction.
- [x] Give the litter nook a digging sequence with synchronized litter puffs.
- [x] Animate the blender during actual service and coordinate the attendant's handoff.

**Review result:** A recording demonstrates each object idle and in use, including independently operating milkshake counters.

### Phase 3 — Broader cute details

- [x] Add box peeking and flap movement, scratching, toy reactions, kneading, and settling.
- [x] Add restrained foliage and lamp movement, and reception bell animation.
- [x] Add locally authored context variations for rest, food, play, friends, fountains and warmth. Optional new sound accents are deferred.

**Review result:** Watching the hotel for two minutes reveals several different natural moments with breathing room between them.

### Phase 4 — Robustness and polish

- [x] Verify on phone and desktop layouts, across all four maps.
- [x] Check normal and 150% text, close and distant zoom, exterior walls, Build mode, and open sheets.
- [x] Verify motion disabled, application pause/resume, object edits, undo/redo, map changes, and existing saves.
- [x] Profile a densely furnished hotel with all 18 guests and several animated objects.
- [x] Run existing regression suites and package the verified preview. Both Windows packages rebuilt; rendered launch, save and reopen checks pass.

## 9. Verification plan

Meaningful new tests should cover paired eligibility, sequencing, cooldowns, cancellation, and once-only object triggers. Extend the existing social, movement, world, voxel-polish, UI, app, save-integrity, and dense-property suites for the changed behavior.

Specific cases:

1. A stationary eligible pair trades lines in order; a lone cat or a pair separated by a wall does not.
2. Removing either participant or the referenced furniture ends the moment and releases its temporary social lock.
3. Starting a new walk or service prevents a stale gesture or forced facing from continuing.
4. Repeated render updates, object rebuilding, undo, and map switching do not replay litter bursts or duplicate dialogue.
5. A blender runs only for its own active service, remains active while any service at that counter is underway, and stops/reset on completion or cancellation.
6. Motion off freezes decorative motion in a clean pose while dialogue remains readable and guest service still completes correctly.
7. Bubbles remain inside the usable view, avoid higher-priority labels, and do not consume world input.
8. Existing visit counts, rewards, reservation exclusivity, and minimum actor spacing retain their established behavior.
9. Existing saves load with the updated visuals and without requiring objects to be repurchased.
10. A rendered stress scene measures frame time, draw calls, and live effect counts before and after the change. Retain the current dense-suite CPU and rendered-preview thresholds and inspect the added cost directly.

Use short rendered clips for final review: still screenshots can verify readability, but cannot establish believable timing, synchronization, or an absence of visual jitter. Physical-device performance should be reported separately from local desktop rendering.

## 10. Definition of done

At normal phone zoom, the player can identify who is speaking, read a short reply, and see the cats acknowledge each other. The fireplace, fountain, litter nook, and milkshake machine visibly come alive in the appropriate context. The hotel remains comfortable to watch, furniture remains editable, and the existing guest routines and rewards keep working.
