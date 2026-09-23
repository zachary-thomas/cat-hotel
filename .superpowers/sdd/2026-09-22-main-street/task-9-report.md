# Task 9 — Market Day in the square

## Output

Implemented an optional Market Day at Meadow. Starting it consumes one owned Market Day bundle in the existing save transaction. The event lasts 90 seconds of active model time, persists its remaining time, and increments a durable completion reaction token exactly once. A failed start keeps the bundle; a failed completion save restores the event timer and token for retry. The ordinary hotel rate and income path are unchanged. The event can be purchased and hosted again after completion.

The quiet square retains paving, benches, lamps, and planters. During the event it shows two kiosks, temporary awnings, signs, string lights, two visiting cats with conversation, and a live countdown. Its board shows available, ready, running, and completed states. The Town panel exposes the Start Market Day action and event status. Event fixtures are hidden outside Meadow and when the event ends. Reduced motion stops shopper animation.

## TDD evidence

- RED: `dotnet run --project tests/unity-domain/Purrington.Domain.Tests.csproj -- town` failed because `StartMarketDay`, `MarketDayRemaining`, and `MarketDayReactionToken` did not exist.
- GREEN: Focused town run passed 167 checks before final additional edge cases. The full domain run passed 676233 checks after those additions.
- Compile-only Unity EditMode project: `dotnet build unity/PurringtonHotel/Purrington.EditModeTests.csproj --no-restore -v:q` succeeded with 0 warnings and 0 errors. This compiles the new `MarketDayViewTests` but does not execute them.
- `git diff --check` found no whitespace errors.

## Changed files

- Domain: `TownEvent.cs`, `HotelTown.cs`, `HotelLife.cs`, `StrictSaveJson.cs`.
- Presentation: `TownSquareArt.cs`, `MainStreetArt.cs`, `VoxelWorldTown.cs`, `HotelTownUI.cs`.
- Tests: `TownEventSuites.cs`, `MarketDayViewTests.cs`, domain runner and project entries. New Unity scripts and tests include `.meta` files. Unity generated project compile entries were refreshed locally and are ignored by Git.

## Remaining gates and concerns

- Unity EditMode execution and portrait/landscape screenshots of quiet, running, and ended square with reduced motion are deferred. The original checkout has an active Unity Editor; this worktree was not opened in another Editor or built.
- The timer saves each active tick to preserve exact reload progress. This is correct for recovery but can write frequently during a 90-second event; measure on device before release and consider a checkpoint cadence if needed.
