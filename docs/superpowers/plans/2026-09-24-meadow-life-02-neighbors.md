# Meadow Life phase 2: neighbors and friendship

September 24, 2026 · Unity only · Meadow (map 0) · [roadmap](2026-09-23-meadow-life-00-roadmap.md)

**Goal:** six named neighbors live along Main Street and follow daily routines. The manager walks up to one, chats about topics (the phase 1 chat system), gives gifts from Paw Mart, and moves through friendship tiers that pay out real rewards.

## Decisions

- **Neighbors walk the authored street graph.** New nodes cover both sidewalk ends, the south sidewalk and the plaza benches. A neighbor's position comes from the game clock and its schedule: each slot starts at a minute of the day and names a street node. At the start of a slot the neighbor walks along `TownRoute` from the previous place. Nothing about position is saved.
- **Home is off-screen.** Each neighbor's home is a sidewalk end ("lives past the bakery"). Once a home slot's walk is over, the neighbor is indoors: hidden and can't be tapped.
- **Chatting pauses the neighbor.** A transient delay pushes back that neighbor's schedule within the current slot, and it resets when the slot changes.
- **Friendship** runs 0–100 per neighbor.
  - Reactions: love +5, like +3, meh +1, dislike −2.
  - Only 3 chats per neighbor per game day count.
  - Tiers: Stranger 0, Acquaintance 15, Friend 40, Best Friend 75.
- **Likes are learned.** A topic's reaction becomes known once you've seen it. The Neighbors page shows "?" until then.
- **Gifts** are consumables bought at Paw Mart, stored in `HotelState.gifts` (id → count). One gift per neighbor per game day counts: the favorite gives +10, anything else +3.
- **Tier rewards** are granted once, in the same transaction as the friendship change:
  - Acquaintance: introduces a specific not-yet-known guest cat (the cat becomes known). If that cat is already known, 60 coins instead.
  - Friend: a furniture piece goes into storage.
  - Best Friend: a signature wear item (a `giftNeighbor` entry in `Wardrobe.json`). It's owned once that tier has been reached.
- **Save:** `HotelData.neighbors` holds `id`, `friendship`, `chatDay`, `chatsToday`, `giftDay`, `tier` (the highest reward claimed) and `learned` (topic ids). Validation covers all of these.

## Tasks

1. **Content.** `Neighbors.json`: neighbors, gifts and the per-neighbor lines (2 per topic, greetings, sign-offs, a chatted-out line, three tier-up lines, gift lines). New street nodes and links go in `MainStreet.json`, and 6 signature wear items in `Wardrobe.json`.
2. **Domain.** `NeighborContent` loader; `HotelNeighbors.cs` for positions, presence, friendship, gifts and rewards; chat support for neighbors (`ChatOffer.neighbor`); manager orders `ChatNeighbor` and `GiftNeighbor`, with walking to street nodes from the hotel or the street; save validation; domain tests.
3. **Presentation.**
   - Neighbor rigs on the street (`ManagerCatArt` recipes with the signature wear once it's earned), which can be tapped in Life and show a pie menu with Chat, Gift and Cancel.
   - A gift picker in that pie menu.
   - Gift shelves in the Paw Mart Buy panel.
   - A Neighbors page in the Cats tab.
   - A tier-up banner.
4. **Verification.** Domain suite, EditMode tests and bridge screenshots of a neighbor chat and the Neighbors page.
