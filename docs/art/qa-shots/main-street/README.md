# Main Street — Windows acceptance captures

Captured 2026-09-22 in Unity 6000.3.24f1 on `codex/main-street`. These are actual Windows player renders. See the full [Task 10 report](../../../../.superpowers/sdd/2026-09-22-main-street/task-10-report.md) for commands, failures, fixes and limits.

## Scope and method

- Viewports: 360x640, 390x844, 430x932 and 1280x800, each at 100% and 150% UI text.
- Main Street exterior, Paw Mart entrance/cashier, cart pushing/parking, Thread & Paw entrance/cashier/try-on, and quiet/running/ended Market Day.
- Pointer acceptance uses queued mouse/touch through the actual Input System UI module. It covers sign taps, drag/pinch, camera Back restoration, placement cancellation, shopping/quests/outfits, blocked journal writes, Retry and journal reload. Rename text and starting coins are fixtures.
- Art-only captures use programmatic scene setup; they do not stand in for the separate pointer results. The ended event is a 95-second clock fixture.
- Hidden-window backbuffers were unreliable. Retained images render the same camera, world and Canvas through a URP offscreen request at the target resolution. Nothing is painted over or synthesized.

## Results

Fresh-save pointer run: **completed, 409 checks, zero failures and runtime errors**. Each performance sample contains 60 frames during Market Day; these short Windows samples are not device benchmarks.

| Viewport / text | Checks | Failed | Average ms | Worst ms |
| --- | ---: | ---: | ---: | ---: |
| 360x640-text100 | 56 | 0 | 16.91 | 31.38 |
| 360x640-text150 | 53 | 0 | 16.92 | 32.04 |
| 390x844-text100 | 50 | 0 | 16.93 | 32.39 |
| 390x844-text150 | 50 | 0 | 16.9 | 30.51 |
| 430x932-text100 | 50 | 0 | 16.9 | 30.14 |
| 430x932-text150 | 50 | 0 | 16.9 | 30.56 |
| 1280x800-text100 | 50 | 0 | 17.06 | 40.33 |
| 1280x800-text150 | 50 | 0 | 16.96 | 34.25 |

See [input-results.json](input-results.json). [Legacy v3 journey](legacy-results.json): **56 checks, zero failures/errors**, 390x844/100%. Art and final smoke results follow below.

## Visual review

Interiors face display fronts with the near wall cut away. Cashiers stand on timber steps behind the counters, exposing faces without changing exterior opacity. Cart handles meet the manager's paws; baskets and loaded groceries remain distinct. Boutique hats and ribbon are visible in the fitting preview. Main Street stays warm timber, cream, stone and moss under an orthographic camera.

At 360x640, figures remain small; the visible cashier choices are the primary way to navigate. Neckwear is subtler than hats and backwear. Selected captures retain the real UI rather than cropping away potential overlap.

Shared wardrobe review is in [hotel-growth](../hotel-growth/README.md): all 13 items across three explicit size fixtures, outfit persistence, care portrait/landscape and roaming views.

## Open gates

Physical Android/iOS, device lifecycle, keyboard interaction, thermal performance and mobile GPU compatibility were not tested. Windows dimensions and queued touch do not satisfy phone release sign-off. The current roster shares one body size, so the wardrobe fixture review does not establish a real kitten/Miso/largest-roster-cat pass. Builds, full local raw capture sets and test logs stay untracked under `builds/unity/main-street`.

Phone catalogue captures can show pale strips at the viewport edges: these are masked portions of neighboring item cards while the list is scrolled to Try on/Buy. The full title/price is visible when scrolled into view (see the landscape catalogue capture). Lower Main Street rows are similarly scrollable inside the sheet, not actionable behind navigation; the pointer journey reaches the destination and Back controls at both phone text scales.

## Retained evidence

Art run: **124 checks passed, zero failures/errors**, including 122 nonblank renders and saved/reloaded outfits. See [art-results.json](art-results.json). Final Windows [smoke result](smoke-result.txt) passed; [performance sample](smoke-performance.txt) is retained.

Each contact sheet contains ten actual renders: exterior, both store entries/cashiers, cart push/park, boutique outfit, running and ended Market Day. Complete originals remain locally in `builds/unity/main-street/art-reviewed`; selected originals are retained here.

| Viewport | 100% | 150% |
| --- | --- | --- |
| 360x640 | [matrix](matrix-360x640-text100.png) | [matrix](matrix-360x640-text150.png) |
| 390x844 | [matrix](matrix-390x844-text100.png) | [matrix](matrix-390x844-text150.png) |
| 430x932 | [matrix](matrix-430x932-text100.png) | [matrix](matrix-430x932-text150.png) |
| 1280x800 | [matrix](matrix-1280x800-text100.png) | [matrix](matrix-1280x800-text150.png) |

Selected full-resolution views: [Paw Mart](360x640-text100-paw-mart-cashier.png), [Thread & Paw](360x640-text100-boutique-cashier.png), [boutique outfit at 150%](390x844-text150-boutique-outfit.png), [cart pushing](1280x800-text100-cart-push.png), [cart parked](1280x800-text100-cart-park.png), [quiet street](1280x800-text100-exterior-quiet.png), [Market Day running](1280x800-text100-market-running.png), [Market Day ended](1280x800-text100-market-ended.png).

The landscape event capture shows the complete MARKET DAY title and timer. Some narrow event captures are scrolled below the title; that clipping is a recorded scroll state. Pointer catalogue context: [full item name/price](input-1280x800-boutique-catalogue.png), [phone action row](input-360x640-boutique-try-on.png), [phone 150% action row](input-360x640-text150-boutique-try-on.png).

Unity results: [94-test EditMode XML](editmode-results.xml). Full domain result: `PASS 676240 checks` (see Task 10 report).
