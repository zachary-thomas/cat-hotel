# Meadow Life phase 1: the manager in Life

September 23, 2026 · Unity only · Meadow (map 0) · [roadmap](2026-09-23-meadow-life-00-roadmap.md)

**Goal:** in the Life tab, the player controls the manager cat. Tapping the ground walks the manager there. Tapping a guest opens a pie menu of icon bubbles. Chat works like Animal Crossing: pick a topic, the guest answers with a witty line, and bond goes up or down. The hotel keeps earning throughout. The manager has no needs.

## Player experience

1. **Life tab:** the manager is visible on the Meadow map, whether in the hotel, on the lawn or on the street. A small **manager chip** in the Life HUD shows the manager's name and portrait, a **Follow** toggle and the **action queue** (up to 3 icons; tap one to cancel it).
2. **Tap the ground.** Inside the hotel (any built floor) or on the lawn, the manager walks to that spot. On Main Street, the tap snaps to the nearest street node, as in town mode today. If the spot can't be reached, a toast says "Can't get there from here." and the tap point wiggles.
3. **Tap a guest cat.** Three or four round **icon bubbles** pop out in an arc above the cat: 💬 **Chat**, 🤚 **Pet**, 👣 **Follow**, ✖ **Cancel**. Tapping anywhere else closes them.
   - **Pet:** the manager walks to the cat, then the existing care mode opens (`SetCareMode`). This replaces today's direct tap-to-care. Care stays available from the Cats tab.
   - **Follow:** the manager trails the cat until you give a new order.
4. **Chat:**
   - The manager walks up. The guest pauses whatever it's doing and turns to face the manager, and a name tag appears.
   - The guest opens with a greeting line that types out, with a soft blip for each letter. Each cat has its own blip pitch, like Animal Crossing's animalese. Tapping skips the typing.
   - **Three topic bubbles** fan out beside the manager (a random 3 of Snacks, Naps, Play, Gossip, Weather, Hotel), plus a small **Bye** bubble.
   - Picking a topic plays the guest's line and a reaction icon pops over its head: ❤️ love, ✨ like, 💭 meh, 💢 dislike. A heart burst follows on love.
   - Up to **3 exchanges per chat**. Then, or on Bye, the guest says a sign-off line and goes back to what it was doing.
5. **Bond:**
   - Love +4, like +2, meh +1, dislike −1. Bond is clamped to 0–100.
   - Only the first **3 counted chats per cat per game day** change bond. Later chats still play lines, and the chip reads "Chatted out for today".
   - The guest's `preference` sets which topics it likes; see the mapping below.
   - Existing bond-gated items and friends benefit automatically.
6. **Explore Main Street** stays where it is. It now queues "walk to the gate" and turns on Follow, so town mode is just the manager out on a walk. Shops and Market Day work as before.
7. **Build tab:** the manager is hidden from picking, and orders are paused but not dropped. Switching back to Life resumes the queue.

## Topic preferences for guests

The mapping is in content (`Chatter.json` → `guestLikes`), not in code. Each guest `preference` loves 1 topic, likes 2, and dislikes 1. The other 2 are meh. Example: `food` loves Snacks, likes Gossip and Hotel, dislikes Play. Write the table for all seven `preference` values in `GodotReference.json` `cats`: `explore`, `food`, `play`, `quiet`, `social`, `sunny` and `warm`. For example, `quiet` loves Naps and dislikes Gossip, `sunny` loves Weather, `social` loves Gossip, and `explore` loves Hotel.

## Domain (`Runtime/Domain`, tested in `tests/unity-domain`)

**Task D1: Manager orders.** New file `ManagerOrders.cs` (partial `HotelModel`).
- A transient `ManagerOrder {kind: Walk|Chat|Pet|Follow|Street, point, catId, streetTarget}` queue, max 3. It isn't saved. After a reload the manager stands at its saved position.
- `CommandResult OrderManagerWalk(LotPoint p)` validates with `ActivityRoute` from the manager's position (floor-aware). A route of length 0 fails with "Can't get there from here."
- `OrderManagerStreet(string target)` wraps the existing `SendManager`.
- `OrderManagerChat(int catId)` and `OrderManagerPet(int catId)` need the cat to be a present `ActorKind.Guest`.
- `OrderManagerFollow(int catId)`, `CancelManagerOrder(int index)` and `ClearManagerOrders()`.
- Add `int floor` to `TownState` (hotel-phase position only). Update `ValidTown`: when `phase=="hotel"`, `floor` must be a built floor and the point must be clear on that floor; when `phase=="street"`, `floor` must be 0.
- `AdvanceManager` gains a hotel-phase walk for Walk, Chat and Pet orders. It re-plans to a moving target cat when the target has moved more than 1 unit, at most every 0.5 s. It arrives within 1.2 units of a cat. It reuses `ManagerSpeed`.
- **Saving:** today `AdvanceManager` runs a `Transaction` (a save) on every tick while walking. For hotel walks, write the position to state each tick but only persist on arrival or order completion, and every 5 s while walking. Check that the street walk still survives reloads.
- Events: `ManagerArrivedAtCat(catId, kind)` and `ManagerOrderFailed(message)`.

**Task D2: Chat state and bond.** New file `ManagerChat.cs`.
- `CommandResult BeginChat(int catId)`. Requires the manager to be within 1.2 units. The guest actor gets `phase="chat"` and its `remaining` is saved so the activity resumes afterwards. Any reserved slot is kept. The actor turns to face the manager.
- The chat has a hard timeout of 45 s of game time and then ends by itself, so a guest can't be stuck forever.
- `ChatOffer CurrentChat` returns the guest id, greeting line, 3 offered topic ids, exchanges left and whether it's "chatted out".
- `CommandResult Talk(string topic)`. Requires an open chat and one of the offered topics. It resolves the reaction from `guestLikes`, applies the bond change (daily cap), picks the line, rolls the next 3 topics, and returns `ChatReply {line, reaction, bondDelta, bondAfter, ended}`. It's transactional.
- `EndChat()` gives the sign-off line and resumes the guest.
- The chat also ends if the guest leaves, the tab changes or the game loads. It never blocks check-out.
- **Save:** add `chatDay` and `chatsToday` to `CatState`, with the day taken from `DayCycle`/`HotelClock`. Add both to `StrictSaveJson`, and make `Valid` check that `chatsToday` is between 0 and 3 and `chatDay` is at least 0.
- **Line choice:** deterministic, from `StableHash(day, catId, topic, chatsToday, exchange)`, picking among variants for that (preference, topic, reaction). Offered topics come from the same hash, and the same topic never appears twice in a row within a chat.

**Task D3: Chatter content.** New file `Resources/Content/Chatter.json` plus a `ChatterContent` loader in the Domain folder, in the same style as `TownContent`. Loading is strict: unknown topics, missing reactions and lines over 80 characters throw.
- `topics`: `[{id, label, icon}]`, the 6 topics.
- `guestLikes`: `{preference: {love, like[], dislike}}`.
- `lines`: `[{who:"guest", preference|"*", topic, reaction, text}]`, 3 variants per (topic, reaction) for the `*` pool, with preference-specific overrides where the joke is better.
- `greetings`, `signoffs` and `busy` pools (8 each).
- Follow the roadmap's writing guide. About 100 lines in total for phase 1. Write every line and read them aloud. Cut any line that isn't funny or doesn't show who the cat is.

**Task D4: Domain tests** in `tests/unity-domain`:
- Walking to a hotel point on floor 0 and on floor 1 (through the stairs). Unreachable points fail.
- The queue caps at 3, cancels work, and Build pauses orders without dropping them.
- The manager chases a moving guest and arrives within 1.2 units.
- `BeginChat` pauses the guest. `EndChat` and the timeout resume it with its original `remaining` and slot.
- Each reaction gives the right bond change. The 3-per-day cap resets on the next game day. Bond is clamped.
- The same inputs give the same line and topics. Every `preference` in the reference content has a `guestLikes` entry.
- Income still accrues during walks and chats: coins after `Tick(60)` match a run with no manager.
- A save while the manager is on floor 1 reloads and validates. A bad `floor`, `chatsToday` or `chatDay` fails `Valid`.
- Chatter content: all loader error cases, and no line longer than 80 characters.

## Presentation (`Runtime/Presentation`)

**Task P1: Life input.** In `VoxelWorldInput`, when in Life and not in care, build or a store interior:
- A tap on a guest raises `CatTapped(catId, screenPoint)` instead of opening care directly.
- A tap on the manager raises `ManagerTapped`, which opens the existing manager panel.
- A tap on hotel ground or the lawn calls `OrderManagerWalk`. The picked floor comes from the current floor view.
- A tap on the street calls `OrderManagerStreet`, using `MainStreetArt.StreetTarget`.
- Show a small voxel paw marker at the destination until the manager arrives.
- `FloorPickAcceptance` and `ParityInputAcceptance` still need to pass. Update them where the tap-cat-to-care path has moved behind Pet.

**Task P2: Manager in the hotel.**
- `SyncManager` places the rig at `(x, floor height, z)` when `phase=="hotel"`, and hides it on floors above the one being viewed, the same way guests are hidden.
- The walk animation and squash follow the order state.
- Follow mode reuses `townFollowing`, now allowed outside town mode. The camera follows smoothly, and any manual pan turns Follow off.

**Task P3: Pie menu.** New file `ManagerPieMenu.cs`, a uGUI overlay anchored to the cat's screen position and clamped to the safe area.
- 56 px round bubbles (larger with text scale), using icon sprites and the concept-art tokens (cream fill, deep-green ink, leaf-green ring).
- They pop in with a `Tween` stagger of 40 ms; with reduced motion they fade in.
- Icons: Chat, Pet, Follow, Cancel. Each has an accessible label that shows as a tooltip on long-press.

**Task P4: Chat view.** New file `ManagerChatView.cs`.
- **Guest line:** in a world bubble via `CatSpeechOverlay`, with a larger variant and a name tag. Text types out at about 45 characters per second and blips through `HotelAudio.Blip(pitch)`, with the pitch seeded from `catId`. Sound respects `settings.sound`. A tap completes the text.
- **Topic bubbles:** fan out from the manager's screen position, each an icon with its label underneath, plus Bye.
- **Reactions:** icons pop above the guest's head. A love reaction plays `VoxelFx` hearts, and bond changes show as a "+2 💗" chip using the existing `VoxelFx.Pop` path.
- **Camera:** eases so both cats are in frame, capped so it never zooms in more than one step, and returns to where it was afterwards.
- **Back/Escape** ends the chat.

**Task P5: HUD.** In the Life panel, add the manager chip (portrait, name, Follow toggle, queue icons). "Explore Main Street" now means an order to walk to the gate plus Follow. The existing town-mode entry stays only as a camera framing mode, for the square fit and store interiors.

**Task P6: EditMode tests and QA.**
- EditMode tests: a pie menu opens on a guest tap; Chat → topic → reply updates the chip; Pet opens care; the queue icons match the domain state; reduced motion skips the tweens.
- Screenshots: `.\tools\unity-bridge.ps1 capture -Tab Life` with the pie menu open, mid-chat (line typing, topic bubbles shown), at 390×844 and 360×640 @150%, and with the manager on floor 1.

## Done when

- `dotnet run --project tests/unity-domain` ends with `PASS <n> checks`, and `.\tools\unity-bridge.ps1 test` passes.
- In Play: walking the manager from the upstairs lounge out to the square and back works without opening any menu. Chatting with three different guests shows three distinct, funny exchanges. Coins keep counting the whole time.
- The user has read the Chatter lines and approved the tone before merge.

## Out of scope (later phases)

Neighbors, gifts, requests, rumors, the outskirts, the general event system, and all B-track build tools. Other maps: orders fail with "Choose a Meadow destination." when `currentHotel != 0`, and the manager isn't shown there.
