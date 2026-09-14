# Gameplay expansion and monetization implementation

Implemented September 8–9, 2026. Tested with Godot 4.7.2 and the Compatibility renderer on Windows.

## Delivered behavior

The eight gameplay areas are connected in the running game:

1. **Cat relationships and touch:** eighteen identities, preference discovery, favorite actions, friendship rewards at 20/50/100, touch/hold/stroke petting, purrs and toy interactions. Repeated touches remain expressive; bond rewards have a short cooldown. Happy automatic visits also build friendship.
2. **Furnishing discovery:** fifteen furnishings, bed/activity/decor slots in each open room, six combinations, discoverable clues and a pinned next goal. Purchases unlock unlimited reuse. Matching combinations improve appeal and income.
3. **Management choices:** suites improve comfort, kitchen and lounge upgrades help relevant guests, reception speeds arrivals, four hotel specialties and three staff members with two skill choices each.
4. **Guest journeys:** simulated visits select guests, score their preferences, record reviews and introduce another compatible free guest after a happy visit. Visible visit routes include a suitcase arrival, a preferred room/activity and departure. Simulation progresses independently of rendering.
5. **Travel-guide progression:** five cumulative star requirements, a timed critic visit and persistent hotel ratings. Requirements combine happy visits, furnishing combinations, staff, rooms and event preparation.
6. **Stories and memories:** friendship milestones, recommendations, invitations, playdates, souvenirs, shared animation sequences, a scrapbook and actual PNG photos in the local album.
7. **Events and destinations:** nap, cardboard and lantern gatherings plus beach, forest-trail and spa events; preparation determines medals. Forest Lodge and Snowcap Spa are playable expansion destinations with themed palettes, weather, furniture bonuses and guests. They currently share the core floor plan and service progression.
8. **Animation and presentation:** petting reactions, ear/head/tail movement, kneading, pouncing, yarn chase, loafing, circling to sleep, boxes, blankets, zoomies, a missed jump, grooming, stretching, yawning, paired greetings/shared naps, suitcase arrivals/departures, staff work, construction and celebration. Watch mode follows a favorite. Reduced motion and audio/background controls remain available.

This is a playable implementation of the proposed systems, not evidence of retention or commercial performance. Cat stories currently use authored milestone text and illustrated entries; larger narrative arcs, more distinct destination floor plans and long-term content balance remain areas for further development.

## Paid content contract

The user chose a free game with cat and hotel DLC. This replaces the earlier free-introduction/full-game-unlock proposal. Meadow House, Seaside Suites and twelve cats are free. Every successful real-money purchase adds its content and removes all ads across every hotel. There is no subscription, premium currency or purchase requirement for petting.

| Store ID | Type | Content |
| --- | --- | --- |
| `purrington.cat_club` | Non-consumable one-time product | Truffle, Ember, Captain |
| `purrington.forest_lodge` | Non-consumable one-time product | Forest Lodge, Juniper, forest event |
| `purrington.snowcap_spa` | Non-consumable one-time product | Snowcap Spa, Flurry, Pearl, spa event |

Products are defined in `scripts/core/game_content.gd`. UI prices come from the store. Successful purchase callbacks validate the known product and completed purchase state, then save content entitlements before acknowledgement. Pending, cancelled, unknown-product and failed-storage cases do not unlock content. Repeat fulfillment is idempotent. Restore queries owned non-consumables. Current entitlement persistence is local; there is no server receipt verification or refund/revocation service.

## Ads

Only hotel changes and completed events are placements. Eligibility begins after 180 seconds, with a 240-second interval and a three-ad session cap. Launch, petting and upgrade actions are not placements. Ads stop as soon as any paid entitlement is saved, including after restoration. UMP consent precedes SDK initialization/requests; unknown consent does not request ads. Settings exposes privacy options when required by the SDK. Full-screen ad/consent presentation pauses game audio. Failed ad loads do not block play.

`commerce.cfg` has empty Android/iOS interstitial IDs, so no live ad requests occur in this workspace. The vendor plugin defaults to Google sample application IDs; replace them before a release. Use provider test IDs/test devices during mobile testing.

## Mobile setup still required

1. Confirm the target mobile platforms. The implemented billing adapter is Android/Google Play. iOS purchase support needs a StoreKit adapter and Apple export/signing work; having the AdMob iOS libraries does not provide billing.
2. Install matching Godot Android export/build templates, Android SDK and Java, and configure their paths. The Android preset uses Gradle, arm64 and package `com.purrington.hotel`; confirm the package identity before creating a store app.
3. Create and activate the three one-time non-consumable products with exactly the IDs above, select prices/regions and add license testers in the Play Console. The client selects an eligible permanent purchase option, displays that option's localized price and passes its identifiers into checkout; rental offers are excluded.
4. Configure the AdMob application ID in Godot's AdMob project settings and interstitial unit ID in `commerce.cfg`. Set up the corresponding consent/privacy message in the provider console.
5. Supply release signing outside source control, upload a signed internal-test build and test on physical devices: purchase approval/cancellation/pending completion, process death before acknowledgement, reinstall/restore, poor connectivity, consent choices, ad dismissal and ad removal after every product.
6. Measure mobile frame rate, memory/battery use and session pacing. Desktop GPU tests cannot establish phone performance or real retention. Complete the store listing and its actual privacy/data disclosures based on the configured SDKs and target audience before submission.

No store product, live ad campaign, store release or real-money charge was created in this task. No signed Android or iOS binary has been built on this host.

## Installed dependencies

Both editor plugins are enabled in `project.godot`; native plugin files are vendored under `addons`.

| Dependency | Installed version | Source |
| --- | --- | --- |
| Godot Google Play Billing | 3.3.0; declares Billing KTX 9.1.0 | [Official repository](https://github.com/godot-sdk-integrations/godot-google-play-billing) |
| Poing Studios AdMob | 5.0.0; Android/iOS Godot 4.7.2 packages | [Official repository](https://github.com/poingstudios/godot-admob-plugin) |

Downloaded archive SHA-256 hashes (for provenance):

```text
billing-3.3.0.zip  20D75623D6F337F08D8283C83098B73678D5F575E39247AF5A8EB80588B18568
admob-5.0.0.zip    93E9AAA8422B00F783C6B8C06A9E2AE3A81DB071515517BB061BBB2D202D5FDF
android-4.7.2.zip  0D504A40B92DB1ABFDF839724C3A962A56569DEF93DBC608C9537FA38710E65A
ios-4.7.2.zip      87741F12255CE831D49194A5C9875110682028DBD2077F7D4677F3C12E1B5D9C
```

The billing adapter follows the plugin's documented [signals](https://godot-sdk-integrations.github.io/godot-google-play-billing/api/signals.html) and [purchase/acknowledgement methods](https://godot-sdk-integrations.github.io/godot-google-play-billing/api/methods.html). AdMob calls were checked against the installed 5.0.0 GDScript sources, including consent and full-screen callback classes.

## Validation

Seven suites cover the economy, save journal, hotel life, commerce, audio, base application and expanded experience. Coverage includes legacy-save migration, JSON numeric normalization, preference effects, combination income, cooldowns, staff skills, event completion, stars, DLC persistence, purchase-state handling, failed-save rollback, ad caps/removal, UI pet gestures, purr audio, all reaction transforms, real photo output and quiet Watch mode.

Rendered UI checks passed at 450×900 and 360×800 during development. New screenshots are generated in `tmp/20-petting.png` through `tmp/31-photo-album.png`. The host reports inability to read the Windows root certificate store; local gameplay tests pass, but no live network commerce validation is inferred from them.

The packaged preview includes normal and test-expansion launchers. Test purchases are explicitly labeled, never charge money and use `user://commerce-preview-save`, separate from the player's normal progress.
