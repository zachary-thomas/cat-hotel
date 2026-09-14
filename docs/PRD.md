# Purrington Hotel — Mobile Idle Game PRD

Version 0.3 • September 8, 2026 • Concept proposal

**Confirmed direction:** mobile first, voxel isometric cat hotels, idle Cat Coin income, successive hotels to build up through levels, and a world inhabited and operated entirely by cats. Dogs, bunnies, and other animals are possible visitors in later-game events. This document and the generated screenshots describe a concept, not a playable game. Names, tuning values, and release scope are proposals.

## 1. Vision and audience

Grow a little cat hotel into a collection of cozy destinations. Cats arrive, play, eat, and sleep automatically. Players return to Cat Coins, choose improvements, watch the hotel transform, and unlock another location.

**Player promise:** Your hotel keeps earning while you are away; every return gives you something satisfying to improve.

The design hypothesis is that casual mobile players and cat lovers will enjoy visible renovations and short check-ins. No research has yet validated the hypothesis. Target sessions are 1–5 minutes, with a longer optional first session.

### Assumptions
- Portrait phones, iOS and Android; the first shipping platform remains a decision.
- Fixed orthographic isometric camera, touch pan, pinch zoom, large bottom-sheet menus.
- Automatic online income plus 100% offline income for up to eight hours; cap is tunable.
- A shared Cat Coin wallet; previously unlocked hotels keep earning.
- Local play without a required account for the initial release.
- Business model undecided. Prototype progression requires no ads or purchases.
- No engine, team size, budget, or delivery date has been committed.

## 2. Goals and non-goals

Proposed validation targets:
1. 80% of new testers buy their first upgrade within two minutes without facilitator help.
2. 80% can explain Cat Coins/min and offline earnings after the tutorial.
3. 70% complete three upgrade purchases within five minutes.
4. 80% notice the world change after a major visual-tier upgrade.
5. 60% voluntarily return within 48 hours during an opt-in playtest.
6. Zero duplicated rewards, double charges, or negative balances in specified lifecycle checks.

These are targets, not results or market benchmarks. Begin with 8–12 formative testers and report counts with percentages; use a larger validation round before commercial conclusions.

Outside MVP: freeform room building, manual cat feeding/cleaning, staff shifts, individual booking calendars, recurring operating expenses, multiplayer, trading, prestige resets, premium currencies, ad multipliers, and mandatory accounts. These would complicate the core idle loop before it is proven.

## 3. Core experience

**Collect Cat Coins → upgrade rooms and services → increase income → raise hotel level → unlock a new hotel → repeat.**

| Timescale | Player reward |
| --- | --- |
| Seconds | Cats animate and the wallet grows |
| Minutes | Another useful upgrade becomes affordable |
| Sessions | Offline earnings fund a visible renovation |
| Days and beyond | New hotel chapters and cat discoveries |

Baseline service is automatic from the start. Floating coins indicate income; tapping them is not required to receive it. Care appears through service upgrades and animation, with no neglected-cat penalties while away.

### Experience pillars

| Pillar | Rule |
| --- | --- |
| Progress while away | Explain earnings and the cap clearly |
| Visible upgrades | Major tiers change furniture, rooms, and activity |
| New chapters | Each hotel has a distinct setting and goals |
| Memorable cats | Personalities add charm without mandatory chores |
| Comfortable mobile play | Keep the main action reachable and detail in sheets |

### First session
- Tap Play, enter Meadow House, and see automatic income.
- Follow a prompt to buy the first affordable suites upgrade.
- Watch the bed improve and see the new rate.
- Unlock a service zone and complete another upgrade.
- Open the map to understand the next hotel requirement.
- Introduce offline earnings with a short explanation; do not force the player to close the app.

## 4. Hotel journey and levels

| Hotel | Theme | Role |
| --- | --- | --- |
| Meadow House | Sage-roof cottage, sunny garden, cozy rooms | First playable hotel and tutorial |
| Seaside Suites | Blue roofs, sandy paths, breezy verandas | Second playable hotel in MVP |
| Forest Lodge | Timber, autumn leaves, climbing furniture | Later content |
| Snowcap Spa | Snowy chalet, amber windows, warm lounges | Later content |

MVP contains **two fully playable hotels**, so the transition to a different hotel is tested as part of the product. Later map locations must say “Coming later” when they are unavailable content, rather than imply an achievable gate.

### Level rules
- Each hotel has suites, kitchen, lounge, and reception zones.
- Suites starts at zone level 1; other zones start locked at level 0. Every zone caps at level 10.
- Each paid zone-level increment, including a 0→1 unlock, counts as one upgrade purchase.
- Hotel level = min(10, 1 + floor(purchased zone-level increments / 2)).
- Thus 18 purchases reach hotel level 10. Cosmetics, rewards, and cat discoveries do not increase this count.
- The next-level card shows progress such as “1 / 2 upgrades to level 5.”
- Meadow House level 10 plus **10,000 Cat Coins** enables the purchase of Seaside Suites.
- Unlocking deducts 10,000 exactly once after an explicit action. Display level and coin requirements separately.
- The new hotel starts with basic suites and fresh zone levels. Existing hotels and the wallet remain.
- All owned hotels contribute income regardless of the hotel currently displayed.
- Gates and rate scaling for later locations require balancing; they are not fixed in this draft.

### Upgrades and layout
Zones use fixed footprints and furniture sockets. The player chooses where to invest; there is no freeform building grid in MVP. Zone levels 1–3, 4–6, and 7–10 use three distinct visual tiers, with small changes on intermediate upgrades.

Beds, perches, and room service are themed stages within the suites track. The concept sheet's cards illustrate these stages; the production UI should present them as a track with the current upgrade selected, not three purchases that all advance the same level.

## 5. Cat Coin economy

Cat Coins are the only MVP currency. Store exact fractional accrual using fixed-point values or an equivalent remainder scheme, display whole coins, and preserve the remainder across saves. The wallet cannot become negative.

Each zone contributes its configured Cat Coins/min. Total network income is the sum across all owned hotels. The top HUD displays the network rate; a detail sheet breaks it down by hotel and zone.

Income depends on owned upgrades, not rendered occupancy, animation cycles, or cats physically reaching objects. Hidden hotels need only their rate data.

### Proposed starting values

| Parameter | Value |
| --- | --- |
| Starting wallet | 1,000 Cat Coins |
| Starting suites | Level 1, earning 10/min |
| Other zones | Level 0, earning zero |
| Baseline zone income at level L | 10 × L Cat Coins/min |
| Upgrade cost from L to L+1 | round(240 × 2^(L/3)), for L=0…9 |
| Example costs | 0→1: 240; 1→2: 302; 2→3: 381; 3→4: 480 |
| Income added per baseline upgrade | +10/min |
| Construction wait | Instant |
| Wages, maintenance, supplies | No recurring deductions in MVP |

The suites screenshot's level 3→4 upgrade costs 480 and increases its rate from 30/min to 40/min. Its unboosted payback is 48 minutes. A 120/min network can arise from different owned-zone combinations.

The baseline formula applies to the first two prototype hotels; location scaling is a later balance decision. Target three early purchases within five minutes and a second-hotel unlock after roughly 1–3 days of short check-ins. These are hypotheses requiring progression simulation, not proof the starting values meet the targets.

### Foreground accounting
Accrue against elapsed time rather than frame count, including time in menus. Before an upgrade or hotel unlock changes the rate, settle through its timestamp at the old rate. Apply the new rate only afterward. Each purchase atomically debits, updates progress, and saves. Repeated taps cannot duplicate an operation.

A fresh installation starts earning only after Play creates its hotel. Returning launches reconcile saved earnings before purchases become available.

## 6. Offline earnings and saving

Proposed default: 100% of saved network income for up to eight hours of eligible away time.

For an unchanged offline segment:
**earned = rate per minute × min(nonnegative elapsed minutes, 480)**

At 120/min:
- Two hours earns 14,400 Cat Coins.
- Ten hours earns 57,600, with only eight hours credited.

### Required lifecycle behavior
1. Persist wallet, fractional remainder, rate, last accrual timestamp, hotel progress, and any pending reward on backgrounding and regular checkpoints.
2. On resume, reconcile only the interval after the persisted timestamp. Time already accrued cannot be paid again.
3. Create or extend a pending reward with an ID, amount, and credited duration. All unclaimed away segments share an eight-hour credited-duration allowance until collection; reopening does not reset it.
4. Keep previous reward segments at their original rates. An upgrade cannot retroactively increase existing offline rewards.
5. Collect atomically transfers the pending reward to the wallet and marks its ID claimed. Retry, rapid taps, or process termination cannot pay twice.
6. Foreground time on the reward screen accrues normally and is excluded from away calculations.
7. Dismissing the sheet preserves the reward and shows a “Collect earnings” chip.
8. Gaps under one minute settle silently only when no pending reward exists. Longer gaps show the summary.
9. Once the cap is reached, preserve the amount until collected. The panel shows actual time away and credited time separately.
10. Local saving must survive process termination without relying only on a graceful shutdown callback.

Use a monotonic timer in-session and a persisted high-water timestamp across launches. Negative clock changes grant zero away time until the clock catches up. UTC elapsed time must not change with time-zone settings. A local-only prototype cannot fully prevent deliberate clock manipulation; authoritative time is a separate decision if future monetization requires it.

Manual/cloud synchronization is outside MVP. A versioned local save and recoverable backup must retain all earned progress. A storage failure reports that saving failed and prevents further monetary transactions until state can be durably committed.

## 7. Cats and automatic hotel life

### World and character rule

The everyday world is a cat society. Hotel managers, receptionists, chefs, attendants, guests, and background residents are all cats. Cats travel and check themselves in; there are no human owners dropping off pets. Buildings, props, signs, portraits, and character icons reflect a world built by and for cats.

Staff may stand upright and wear a small apron, cap, or bow tie, but retain unmistakably feline heads, ears, paws, and tails. Guests can walk on four paws and lounge naturally. Human heads or bodies with cat ears added are not the character design. Use feline silhouettes for staff icons, too. Human-directed slogans such as “better people” must be replaced with cat-world language.

The base game and ordinary locations contain only cat characters, including ambient inhabitants. Other living species are reserved for possible later events; decorative animal-shaped toys are props rather than residents. No dogs, bunnies, or other guest species are included in the MVP.

Initial collection target: 12 named cats with several voxel coat patterns and flavor traits such as sleepy, playful, shy, and curious. Milestones introduce new guests; the first encounter adds the identity once. Duplicates never block progression. MVP collection rewards are cosmetic, keeping income easy to understand.

Cats arrive, explore unlocked zones, play, eat, and sleep automatically. Cat staff provide automatic service, without schedules or wages. Profiles show a name, trait, preferred activity, and discovered locations. There are no critical need meters or offline neglect consequences.

Core animations: arrival, walking, loafing, eating, sleeping, stretching, and play. Cap visible actors and decouple animation from earning.

## 8. Mobile screens and interactions

Four persistent bottom tabs: **Hotel, Upgrades, Map, Cats**. Settings is a top-corner control. The global coin balance and network rate remain consistent on economy screens.

| Screen | Primary content/action | Edge states |
| --- | --- | --- |
| Main menu | Hotel vignette, Play, Settings | Fresh save versus returning save |
| Active hotel | Dollhouse, coins/min, hotel level, next objective | No affordable upgrade, max level, pending earnings |
| Upgrade sheet | Current→next level, rate increase, cost, Upgrade | Locked zone, shortfall, max level, retry |
| Hotel map | Destinations, open/locked state, unlock requirements | Level gate, coin gate, future content |
| Welcome back | Away duration, credited reward, cap, Collect | Zero reward, cap reached, unclaimed reward, repeated taps |
| Cat collection | Discovered portraits, silhouettes, profiles | Empty collection and newly discovered cat |
| Settings | Audio, haptics, reduced motion, text options, save status | Local save error and persisted preferences |

Touch design target: controls at least 48×48 logical units with spacing and safe-area padding. Validate the actual platform layouts and accessibility during implementation. Pinch zooms; dragging empty space pans; tapping selects. A drag must never trigger a purchase. Tappable markers remain usable at minimum zoom.

Use large bottom sheets with one main action. Opening a zone sheet centers that zone; closing restores the previous view. Avoid hover-only information. Pair status colors with labels and icons. Provide screen-reader labels and logical navigation for menus, large-text behavior, optional haptics, and reduced animation. Exact values remain accessible when the visual HUD abbreviates large numbers as K/M.

## 9. User stories

- As a new player, I want my hotel to earn immediately so I understand what upgrades do.
- As a returning player, I want a clear offline summary so I know how much progress I made.
- As a casual player, I want to compare cost and extra income so a short session includes a useful choice.
- As a progressing player, I want a different hotel to develop so each chapter feels fresh.
- As an owner of several hotels, I want earlier work to keep earning so it remains valuable.
- As a cat lover, I want familiar guests without mandatory care chores.
- As a phone player, I want readable numbers and comfortable touch controls.
- As a player resuming after a crash, I want purchases and rewards applied exactly once.

## 10. Requirements and acceptance criteria

### P0 — First playable release

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| P0-01 | Portrait start/navigation | Play creates Meadow House on first use and resumes the last owned hotel thereafter; all tabs work by touch. |
| P0-02 | Automatic earning | Sixty seconds at 120/min adds exactly 120, preserving fractions; animation and selected screen do not affect earning. |
| P0-03 | Upgrade purchase | With funds, debit once and raise level/rate once. Without funds, preserve state and show the shortfall. |
| P0-04 | Visible renovations | Three tiers per zone; 3→4 visibly changes the zone and survives reload. |
| P0-05 | Hotel levels | Two paid increments raise hotel level once up to 10. Reward claims and reloads do not change purchase count. |
| P0-06 | Two hotels | Level 10 plus 10,000 coins unlocks Seaside exactly once, preserving Meadow's upgrades and income. |
| P0-07 | Network rate | Hotels at 120/min and 40/min earn 160/min combined on every screen; breakdown reconciles. |
| P0-08 | Offline earnings | Verify 14,400 at two hours and 57,600 at ten hours for 120/min; cap works across unclaimed segments. |
| P0-09 | Claim integrity | Rapid taps, retry, and termination before/after commit never duplicate a reward. |
| P0-10 | Hotel life/collection | Walking, sleeping, eating, and play appear; discoveries register once; culling actors never pauses income. |
| P0-11 | Objectives/tutorial | Guide earning, upgrades, levels, and map. Prompts are dismissible and cannot block navigation. |
| P0-12 | Save/recovery | Preserve wallet/fractions, hotels, zones, counts, cats, timestamps, rates, and claim IDs; recover a valid backup. |
| P0-13 | Lifecycle resilience | Backgrounding, interruptions, force-close during transactions, clock rollback, and storage failures cannot silently corrupt progress. |
| P0-14 | Mobile usability | Controls fit supported phone safe areas and target text scaling; audio/haptics/motion settings persist. |
| P0-15 | Cat-only world | All staff, guests, background residents, portraits, and character icons depict cats. No human characters or human-owner framing appear. Ordinary locations contain no other animal species; cat staff remain visibly feline even when dressed. |

### P1 — Follow-up
- Forest Lodge and Snowcap Spa: each needs its own art, goals, explicit gate, and correct network income.
- Cosmetic furniture themes: swaps preserve upgrade and earning state.
- Photo mode and scrapbook: save local images and milestones without UI.
- Optional playful bonuses: bounded rewards, never required for baseline progression.
- Hotel specialties: show every modifier in the rate breakdown.
- Cloud saves: resolve device conflicts without duplicating transactions.

### P2 — Future exploration
Seasonal hotels, cat friendships, manager collectibles, extra floors, events, and prestige. Each needs a separate specification; do not include all of them in the initial build.

**Possible later-game animal visitors:** a dog travel club, a bunny garden weekend, or another visiting animal group could arrive for an optional event after players establish their cat hotels. These are future ideas, not committed content or a permanent mixed-species population. Cat staff remain the hosts. Events must not block ordinary hotel unlocks or baseline idle income; exact gates, recurrence, rewards, and guest rules need a later specification.

## 11. Visual direction and screenshots

Clearly voxel-built cats with square heads, stepped ears, and chunky tails. Matte blocks, soft shadows, warm wood, cutaway rooms, and readable isometric depth. Prioritize silhouette and phone-scale readability over tiny decorative detail.

All future art prompts must explicitly describe a cat-run, cat-inhabited world, including feline workers and cat-only background characters. Earlier artwork with human staff or human-directed signs is superseded by this requirement; audit inherited art before production use.

Palette: ivory #F5F0E6, forest #294638, sage #8FAA8B, honey #C89A63, terracotta #C77D63, gold #D5AB53. Gold paw coins identify the currency. Ivory panels separate controls from the detailed world.

1. [Main menu](concept-art/01-main-menu.png)
2. [Hotel overview](concept-art/02-hotel-overview.png)
3. [Upgrade menu](concept-art/03-upgrade-menu.png)
4. [Hotel map](concept-art/04-hotel-map.png)
5. [Offline earnings](concept-art/05-offline-earnings.png)

Screenshots are separate illustrative states, not one continuous save. Decorative signs and coin bubbles are art exploration. The map previews later content. Generated screen labels, selectors, and incidental controls do not override the rules in this PRD. In particular, the offline artwork's wallet plus icon does not specify a shop, and production should include a visible way to dismiss the reward sheet. [Exact prompts](concept-art/prompts.md) document generation.

## 12. Engineering and performance boundaries

Keep economy/persistence separate from rendered cat behavior. Data-driven hotel definitions hold zone levels, costs, rates, visual tiers, and gates. Suggested state boundaries: wallet, hotel/zone progress, cat collection, accrual checkpoint, pending offline reward, and versioned transaction records.

Render only the selected hotel. Inactive hotels are rate data. Pool actors/effects, share materials, and reduce visual complexity before sacrificing economy accuracy. Never run offline pathfinding.

Provisional target: sustained 30 FPS on agreed midrange phones, optional 60 FPS, one visible hotel, 12 cats, four service zones. Reference Android/iPhone devices, memory/thermal budgets, startup time, and app size must be set during the prototype.

Critical checks: fractional accrual; rate changes; capped multi-segment offline rewards; force-close at purchase/claim boundaries; storage failures; low-memory reload; clock rollback; gesture collisions; safe areas; large text; large coin formatting.

## 13. Phasing and validation

No schedule is promised without team and budget context.

1. **Idle toy:** one portrait hotel, coins, upgrade, persistence, and background/resume. Exit when earning survives termination and an upgrade visibly changes a room.
2. **Vertical slice:** four zones, level progression, tutorial, upgrade sheet, cats, and offline summary. Exit when testers understand rates and buy three upgrades.
3. **MVP journey:** second hotel, map gates, global income, collection, settings, and recovery. Exit when P0 criteria pass.
4. **Balance/device validation:** simulate return patterns and upgrade choices; test reference phones; validate short-session targets.
5. **Content expansion:** add later hotels and selected P1 features based on observed engagement.

Dependencies: prove save/claim integrity before economy expansion; prove early pacing before mass-producing assets; establish visual scale before art production; validate the second-hotel transition before building four locations.

Potential opt-in events: first_upgrade, zone_upgraded, hotel_level_up, hotel_unlocked, offline_reward_claimed, cat_discovered, session_start/end, save_error. The game must function without telemetry.

## 14. Risks and open decisions

| Risk | Response |
| --- | --- |
| Upgrades feel like numbers only | Require world changes at major tiers |
| Early waits stall play | Fund the first purchase and simulate the first five minutes |
| Old income overwhelms later hotels | Tune aggregate rates and gates together |
| Locations feel repetitive | Distinct themes, objectives, and eventual service choices |
| Offline rewards disappoint or duplicate | Explain cap and use atomic reconciliation |
| Mobile battery/heat | Render one scene and decouple earning from frames |

| Decision | Owner | Needed by |
| --- | --- | --- |
| iOS/Android together or one first? | Product/user | Platform selection |
| Monetization direction? | Product/user | Before commercial economy commitments |
| Eight-hour cap or longer? | Product/game design | Return-session balancing |
| Team, budget, release target? | Product/user | Calendar planning |
| Engine, asset pipeline, reference phones? | Engineering/art | Production commitments |
| Later gates and rate scaling? | Game design | Third/fourth hotel production |

Next implementation step: prototype the idle toy. This package delivers the requested visual concept, feature brainstorm, and PRD.

