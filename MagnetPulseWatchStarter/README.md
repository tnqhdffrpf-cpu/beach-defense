# MagnetPulse Watch Starter

Separate watchOS app starter that vibrates when a strong magnetic field is nearby.

## What it does
- Monitors magnetometer data using CoreMotion.
- Triggers rapid repeated haptics when field strength exceeds threshold.
- Stops haptics when field drops below threshold.
- Uses a decoy watch-face style UI.

## Threshold
- Default threshold: `130 uT` in `MagneticFieldMonitor.swift`.
- You can tune `thresholdMicrotesla` up/down based on how strong your magnet is.

## Xcode setup (new app)
1. In Xcode, create a new project: `watchOS > App`.
2. Product Name: `MagnetPulseWatch` (or any name you want).
3. Delete generated `ContentView.swift` and generated app file.
4. Copy these files into the **watch app target**:
   - `MagnetPulseWatchApp.swift`
   - `ContentView.swift`
   - `MagneticFieldMonitor.swift`
5. Ensure Target Membership is checked only for your watch app target.
6. Run on your physical Apple Watch.

## Notes
- Haptics on watchOS are pulse-based (not true continuous motor control), so this uses rapid pulses.
- Real-time sensing is most reliable while the app is active in foreground.
