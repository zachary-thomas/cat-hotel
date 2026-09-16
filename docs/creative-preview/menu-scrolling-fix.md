# Android menu scrolling

Menu buttons, category tabs, settings switches and inset panels stopped pointer
events before their enclosing ScrollContainer could receive a drag. Swipes over
cards could activate them instead of moving the list. These controls now pass
events to the enclosing container, whose native scroll-begin notification cancels
the pending button action. Settings switches wait for release before toggling.

The shared scroll deadzone is 12 viewport pixels, allowing small finger movements
during a tap without starting a scroll. Outer menu panels still block world input.

`tools/test-creative.ps1 -Suites test_creative_menu_scroll` exercises actual GUI
event dispatch with touchscreen emulation at 360×640 and 150% text size. It covers
vertical card lists, the horizontal Build rail, Settings, Cats, Map and Life;
swipes must move the list without activating buttons. It also checks taps with
slight movement, setting changes, desktop wheel scrolling and isolation from world
gestures. It can also run with `-Rendered` and is in the default headless suite.

Before the fix the original five swipe scenarios remained at offset zero (eight
assertion failures including unintended activations). The corrected six scenarios
scroll 50 pixels after passing the deadzone, with no unintended activations.

Android test.3 includes this change and the test.2 lighting correction. Physical
Android touch behavior still needs confirmation on a device.
