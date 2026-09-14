**Purrington Hotel: gameplay, cat interactions, and monetization brainstorm**

Implementation update: the user selected a free game with cat/hotel DLC and removal of all ads after any real-money purchase. The previous monetization recommendation below is historical. See [the implemented expansion and remaining mobile setup](EXPANSION-IMPLEMENTATION.md).

September 8, 2026. Recommendations for discussion, based on the current source, existing design documents, and saved prototype screenshots. These are proposals, not implemented features or validated commercial results. This expands the original feature brainstorm; it does not replace the approved scope.

The opportunity is a hotel management game where understanding cats makes you a better hotelier. The player should want to discover what a favorite guest likes, try a new room combination, and watch the resulting little story unfold. Automatic earnings support that experience.

**What the prototype already gives us.** Meadow House and Seaside Suites, service upgrades, room wings, automatic and offline earnings, named cat portraits, walking/eating/sleeping/play routines, staff, tap-to-meow, music, evening lighting, and reduced motion are already present. Each ordinary service upgrade currently adds the same 10 coins/minute. Cat discovery is derived from upgrade and wing purchases; individual friendship histories are not stored. The cat animation code follows predefined routines. Those are useful foundations, but they leave room for more consequential choices and more individual behavior. This assessment is from source and saved images, not a new playtest.

Kairosoft's own description of Hot Springs Story 2 connects facility placement with guest interests, local investments with new visitor groups, and hospitality goals with travel-guide rankings. Dream Town Island connects development with individual residents' lives. My design interpretation is to borrow those relationships between systems: what the player builds changes who comes and what happens. Sources: [Hot Springs Story 2](https://store.steampowered.com/app/2089450/Hot_Springs_Story_2/) and [Dream Town Island](https://store.steampowered.com/app/2488340/Dream_Town_Island/).

**Ten directions worth exploring before choosing the release scope.**

1. **Cats who remember you.** Give each regular a persistent identity, favorite furniture, preferred interaction, and a short friendship story. Miso seeks sunshine; Bean loves moving toys; Mochi likes quiet corners. Familiarity progresses from visitor to regular to hotel favorite, unlocking a new behavior, furnishing recipe, or scrapbook entry. Meeting preferences during automatic visits should also grow familiarity, so petting remains optional. A favorite may greet the player near reception or bring a souvenir. Personalities should influence choices, rather than just provide profile text.

2. **Furniture combinations to discover.** Start with the existing room sockets instead of requiring a complete freeform building system. A room could hold a bed, an activity item, and a decoration. A window perch plus warm cushion becomes a Sunbeam Suite; a tunnel plus scratching tower becomes a Tiny Adventure Club; a sheltered bed plus soft rug becomes a Quiet Retreat. Show a clue before discovery, explain the benefit afterward, and let players rearrange freely. Combinations should change guest preferences or unlock behaviors as well as provide modest bonuses. Avoid one objectively best arrangement for every guest.

3. **Distinct hotel businesses.** Offer meaningful specializations at milestones: a quiet retreat, a playful social hotel, or a food destination. Suites increase capacity, kitchens improve dining appeal, lounges provide entertainment, and reception opens visitor groups. Show each choice's practical effect in plain language. Begin with positive bonuses and tradeoffs over limited space; complicated operating expenses are unnecessary for the first experiment. Preserve reliable baseline offline earnings and calculate simulation outcomes independently of visible animation.

4. **Guest journeys and recommendations.** A guest arrives with a little suitcase, chooses an activity suited to its personality, visits a room, and leaves a short review. A pleased guest recommends the hotel to a friend. A shy visitor finding a quiet room might return with another quiet traveler, leading to a new guest group. The player manages what the hotel offers, with check-in, food, and housekeeping handled automatically. Use visible mood and preference cues, not a row of critical care meters.

5. **Ranks earned through accomplishments.** Add hotel stars earned through varied achievements: host several guest types, discover combinations, develop a specialty, and earn repeat visits. Introduce a feline travel writer who visibly inspects relevant facilities. Review results explain the next improvement: "Wonderful pillows. I would love somewhere to play." Keep star reputation distinct from the existing upgrade level, or deliberately redesign the level system with clear migration; do not silently make the same meter mean two things. Retry inspections when ready.

6. **A collection built around discoveries.** Expand the Cats screen into a field guide with preferences, bonds, favorite rooms, and moments seen. Let players pin one discovery to pursue. Silhouettes can have useful clues such as "Someone who loves warm windows." Earn guest invitations through visible conditions, with a dependable path after the condition is met. Build collections around photographs, furnishings, recipes, postcards, and guest stories. The reward is learning about the world; avoid multiplying currencies.

7. **Staff with small career stories.** A concierge cat learns how to welcome shy travelers; a chef invents a new dish; an attendant gets a comically oversized towel trolley. At a milestone, choose one of two specialties, such as attracting food enthusiasts or making dining more efficient. Skills change an automatic service and its animation. Staff do not need shift scheduling or repetitive manual assignments. A small named team can create attachment without simulating an entire workforce.

8. **Events the player can look forward to.** Host a nap championship, a cardboard architecture festival, a lantern evening, or a feline travel club visit. Choose an event, prepare relevant rooms, then enjoy the show and earn a trophy or guest invitation. Use a game calendar and repeatable, player-started events before considering real-world schedules. Guests can gather and react together. A missed real-world day should not remove a unique cat or reset progress.

9. **A tiny sitcom that emerges from the hotel.** Cats become friends after sharing preferred activities; one regular always sits in delivery boxes; another supervises construction. A towel thief can lead staff on a harmless chase and then fall asleep on the prize. These scenes should follow observable conditions and recur with variation. Let players initiate a playdate by inviting compatible regulars. Begin with a few authored pairs rather than an unrestricted relationship simulation.

10. **The opposite experiment: make doing less satisfying.** Remove persistent floating income labels after the player understands them, and offer a watch mode with a quiet HUD and a follow-favorite camera. Automatically save rare moments to the scrapbook, so noticing a scene is delightful rather than a compulsory collection task. Test an entire session where the player watches the hotel without buying anything. If that is enjoyable, we have a stronger foundation for both gameplay and promotion.

Everyday guests, staff, critics, and neighbors remain cats, consistent with the existing world direction. Other species are optional future event content, not required by these ideas.

**The signature interaction: pet, listen, learn.**

Make touching a cat feel like a tiny relationship, with a clear beginning and end:

- Tap a cat to select it, show its name, and bring up an unobtrusive Pet action. This avoids confusing world panning with stroking. Keep larger touch targets than the visible voxel body and provide a close view.
- In pet mode, a slow stroke makes the head follow the touch, the eyes soften, and the body lean in. A simple tap/hold alternative should give the same meaningful result.
- After a few gentle strokes, a short purr fades in, the paws knead, a little heart appears, and optional haptics give a light response. Mix purring clearly against the music, respect sound settings, and avoid overlapping many purr loops.
- Each personality has a variation: Bean rolls onto a side; Miso arches into the scratch; shy Olive starts with a slow blink and approaches more confidently as familiarity grows.
- End with a natural response: a stretch, head bump, or return to the previous activity. Repeated interaction can stay expressive, but should not become the optimal way to farm unlimited income or friendship.
- Reveal a small preference or story milestone when appropriate. Do not add a separate spendable heart currency in the first version.
- Purring, basic affection, and access to the core interaction belong in the free introduction. They demonstrate why the game is worth buying.

Other direct interactions: drag a feather wand for a crouch-wiggle-pounce sequence, roll a yarn ball for a chase, brush a cat for visible relaxation, tap a cushion to invite a regular, ring a small dinner bell for an optional gathering, and place an empty box to see which cat claims it. Keep staff care automatic. Gesture play is a bonus experience, with an accessible button alternative.

**Animation ideas, grouped by what they communicate.**

| Situation | Animation and sound | Gameplay purpose |
| --- | --- | --- |
| Quiet idle | Ear turns, slow blink, tail curl, breathing, paw wash, occasional yawn | Distinguish relaxed cats without constant screen motion |
| Petting | Head follows touch, lean, closed eyes, alternating kneading paws, fading purr | Immediate response and emotional attachment |
| Playing | Track toy, crouch, rear wiggle, spring, land, proudly carry toy | A satisfying interaction with anticipation and payoff |
| Settling down | Circle cushion, knead, tuck paws, curl, breathe | Make comfort upgrades visible through use |
| Furniture discovery | Sniff new object, test with a paw, climb or claim it | Explain that building changes cat behavior |
| Friendship | Nose greeting, mirrored lounging, grooming, shared nap | Make relationships visible without opening profiles |
| Arrival/departure | Suitcase wobble, welcome bow, room key handoff, farewell wave | Show the hotel operating as a business |
| Staff service | Stir a pot, plate food, push trolley, stack towels, wipe counter | Make service improvements legible |
| Renovation | Construction hats, quick assembly, ribbon fall, first guest tests furniture | Give purchases a memorable payoff |
| Hotel milestone | Sign changes, window lights turn on, staff gather, short musical phrase | Mark progress with a visible world change |
| Weather/evening | Rain on windows, puddle ripples, moving sun patches, lantern sway | Give revisits atmosphere and new photo compositions |
| Comic surprise | Missed jump onto a low cushion, box too small, blanket burrow, sudden zoomies | Create moments players want to watch and share |

Prefer authored sequences with anticipation, contact, and recovery over making every character bounce continuously. Use several idle variations and stagger their timing. Cat size and visibility matter: the current saved portrait image shows a detailed hotel but small cats, so a close petting view and less world-overlay clutter are especially valuable.

**How the loops connect.**

The main chain is: observe a preference -> choose a furnishing -> discover a combination -> host a delighted guest -> earn a review or invitation -> unlock a new possibility -> improve another part of the hotel.

The emotional chain is: meet a cat -> enjoy an interaction -> recognize a habit -> see a new story moment -> look forward to its next visit.

Offer something at several scales: a reaction in seconds, a useful decision in minutes, a story or room milestone during a session, and a distinct destination over multiple sessions. These are pacing hypotheses to test. Keep a visible next discovery and a comfortable stopping point. Filling every second with prompts would interfere with enjoying the cats.

A sample session: the welcome-back screen shows earnings and a saved picture of Bean asleep in a new box. The player pets Miso, learns about a warm-window preference, and rearranges a room into a Sunbeam Suite. Miso uses it and brings a friend on a later visit. That guest helps complete a travel-guide objective, which unlocks a new furnishing choice. The player leaves with progress and something specific to anticipate.

**Monetization recommendation: a free introduction and one permanent base-game unlock.**

For this direction, I would test a $6.99 US full-game unlock delivered as a one-time in-app purchase. The price is a hypothesis, not an established optimum. The free introduction should include a satisfying Meadow House arc with petting, a furniture combination, a memorable guest, and a real milestone. Disclose the paid unlock before players invest heavily, and present it naturally at a chapter boundary. Players should retain their save and be able to enjoy the unlocked portion if they decline. Define exactly which completed hotels and content the base purchase includes.

The current two-hotel prototype needs deeper gameplay and content validation before it becomes a commercial full-game offer. Forest Lodge and Snowcap Spa are already future concepts; do not promise them in a purchase until their inclusion and delivery are concrete. Do not call an offer "all future content" if expansions may later be sold separately.

Kairosoft uses different models: its US App Store listing for Dream Town Island currently shows $6.99, while Dream Town Story is free with in-app purchases. These demonstrate available approaches, not evidence that either will maximize Purrington's revenue. Sources checked for this brainstorm: [Dream Town Island](https://apps.apple.com/us/app/dream-town-island/id6446826650) and [Dream Town Story](https://apps.apple.com/us/app/dream-town-story/id1320716777).

| Model | Why choose it | Main tradeoff | Fit for Purrington |
| --- | --- | --- | --- |
| Paid upfront | Simple offer; complete game can be balanced around enjoyment | A new audience must commit before trying it | Strong alternative if a demo or existing audience establishes demand |
| Free introduction + permanent unlock | Players can experience the cats before deciding; one clear purchase | Free installs only generate revenue if enough players convert | First model to test |
| Free game + rewarded ads | Players can choose to contribute attention instead of money | Adds ad operations and interrupts the experience; actual revenue depends on reach and repeat use | Alternative if testing supports a broader free game |
| Free game + recurring purchases | Cosmetics or content can support ongoing development | Requires enough desirable content and sustained demand; more store and balance work | Consider only after the core audience is established |
| Forced ads or subscription | Recurring monetization opportunities | Strong interruption or recurring value burden for this concept | Poor starting fit |

Do not launch all models together. My preferred sequence is the permanent unlock first, then substantial optional destination expansions if demand supports them. A later decor pack could test $1.99-$3.99, but the paid base game should already offer generous decoration and collection. Cosmetics must not secretly provide the strongest room bonuses. Keep new expansion stories separate enough that the base game feels complete.

If we deliberately choose a fully free business model instead, start by testing optional rewarded ads at natural breaks, such as a small extra delivery after a completed event. Show the exact reward before viewing, place a modest frequency limit, and leave baseline progression satisfying without ads. Do not interrupt petting or gate rare cats behind ad viewing. Remove-ads purchases must state exactly which ads they remove and how voluntary reward opportunities behave afterward. Avoid selling coin skips until the unmonetized progression is demonstrably enjoyable; selling shortcuts can undermine the management decisions we are trying to create.

**Commercial reality to test.** A pleasing model still needs enough revenue to fund the game. With 10,000 free installs, a hypothetical 3% conversion at $6.99 produces $2,097 gross purchase revenue; at 8%, it produces $5,592. If we assume a 15% store fee only, those become approximately $1,782 and $4,753 before other costs and adjustments. Those conversion rates are illustrative scenarios, not forecasts or industry benchmarks. This corresponds to roughly $0.18 or $0.48 per free install after that assumed fee, before taxes, refunds, development, support, and marketing. Paid acquisition can be uneconomic even if players like the product.

The 15% example is not a universal store fee: Apple offers 15% for qualifying, approved Small Business Program participants, and Google fees depend on program, market, transaction, and install conditions. Check the actual launch account and markets when building the financial model. Sources: [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/) and [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622?hl=en).

Compare purchase conversion and revenue per store visitor as well as per install: paid-upfront and free-demo installs come from different funnels. Measure satisfaction, return behavior, and refunds alongside money. Short petting and comic hotel clips are promising creative ideas to test for attracting players; their effectiveness is unknown until measured.

**What I would prototype first.**

| Order | Small, connected experiment | Biggest unknown | Cheapest useful check |
| --- | --- | --- | --- |
| 1 | Three memorable cats, persistent familiarity, petting/purring, and six expressive animation sequences | Will people care about individual cats? | Observe whether testers voluntarily interact again and remember a favorite |
| 2 | Three furnishing choices, two combinations, preference-driven visits, and one new guest invitation | Does building create understandable decisions? | Ask players what changed and why the guest responded; observe a second deliberate build choice |
| 3 | One hotel review, a small repeatable event, and a scrapbook | Does the loop give players a reason to return? | Follow an opt-in playtest across several days and ask what they anticipated |
| 4 | A clearly labeled free chapter and a mock $6.99 unlock offer | Is the proposed package worth paying for? | Start with comprehension and willingness feedback; later validate with actual sales in a limited release |
| 5 | A mechanically distinct Seaside chapter and richer staff stories | Does the game stay interesting after Meadow House? | See whether players use a new strategy rather than repeat the same purchases |

An early formative round with 8-12 people can reveal confusing controls and weak choices; it cannot establish a reliable purchase-conversion forecast. Keep a small connected slice before commissioning a large animation catalog, building several new hotels, or integrating an ad platform.

Implementation should preserve the current separation of economy from rendering. Persistent cat identities and friendship records need versioned saves. Input needs to distinguish petting from panning, and animation must support interrupted actions and safe returns to routines. Reuse the existing cat body/head/tail structure for early reactions, then add more complex shared animation pieces if the prototype warrants them. Test visible actor and effect budgets on physical phones; the current Windows preview does not establish phone performance. Before charging, validate purchase restoration, save continuity, and access to purchased content.

The first milestone should feel like this: the player recognizes Miso, makes a room Miso loves, hears a satisfying purr, discovers something new, and understands how to improve the hotel next.
