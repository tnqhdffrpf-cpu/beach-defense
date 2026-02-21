# BeeBuzz Watch App Starter

This is a local-testing starter for a watchOS app where tapping the screen:
- starts buzzing sound (or haptic fallback)
- animates a bee flying out, then back to center
- shakes briefly, then stays large at center

When the app goes inactive (including covering the watch face to sleep), it stops buzzing.

## Setup in Xcode (local only)
1. Open Xcode and create a new project: `watchOS > App`.
2. Name it `BeeBuzzWatch`.
3. Delete the generated `ContentView.swift` and app file.
4. Copy these files into your watch app target:
   - `BeeBuzzWatchApp.swift`
   - `ContentView.swift`
   - `BuzzSoundPlayer.swift`
5. In target settings, make sure `AVFoundation` and `WatchKit` are available (default in watchOS app).
6. Run on your paired Apple Watch.

## Optional louder audio file
If you want a real buzzing sound instead of haptic fallback:
1. Add a short looping file named `buzz.wav` to the watch app target resources.
2. Keep the filename exactly `buzz.wav`.

Without `buzz.wav`, the app still works using repeated haptic buzz.
