# PitchPal iOS MVP

This folder contains a starter iPhone app for:

- Listening to hummed melodies with the microphone
- Detecting note names in near real-time
- Saving captured melodies
- Suggesting 4-chord progressions that fit the melody

## What You Need

- A Mac with Xcode 15+
- An iPhone (or iOS Simulator for basic UI testing)
- iOS 17 target recommended

## Setup (Non-Developer Friendly)

1. Open Xcode.
2. Create a new project:
   - iOS -> App
   - Product Name: `PitchPal`
   - Interface: `SwiftUI`
   - Language: `Swift`
3. Close Xcode once project is created.
4. In Finder, open your new Xcode project folder and replace its generated Swift files with all files from `AppSource/`.
5. Open the project in Xcode again.
6. In your app target's `Info` tab, add:
   - `Privacy - Microphone Usage Description`
   - Value example: `PitchPal needs microphone access to detect sung notes.`
7. Build and run on iPhone.

## Notes About Accuracy

- Humming detection uses a lightweight autocorrelation pitch estimator.
- It works best for one clear voice at a time in a quiet room.
- Very noisy environments and breathy humming reduce accuracy.

## Suggested Next Improvements

- Quantize notes to tempo/beat grid
- Add audio playback and guitar chord voicings
- Use Core ML/CREPE-style model for stronger pitch detection
- Export melodies/chords as MIDI
