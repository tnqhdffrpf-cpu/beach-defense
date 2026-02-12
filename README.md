# Beachwatch Bastion

A beach-themed mobile tower defense game in a single static `index.html` file, ready for GitHub Pages hosting.

## Theme and Visuals

You defend the shoreline with lifeguard-themed towers:

- **Lifeguard Post**: cheap, fast single-target shots.
- **Water Cannon**: splash damage crowd control.
- **Coast Chopper**: expensive heavy burst support.

Enemies arrive in waves as sea creatures:

- Crabs (basic)
- Squids (faster)
- Sharks (tanky and dangerous)

The game now uses sprite-style artwork (image-based rendering in canvas) instead of basic geometric units, plus a richer top-down beach map:

- Top-down sand texture with tide pools and surf patterns
- Curved enemy channel/path with foam and flow detail
- Decorative scenery sprites (lifeguard stand, beach grass, palms, umbrella, rocks)
- Build pads auto-spaced a consistent distance from the lane
- Seagull flyovers with random bomb drops

## Gameplay Loop

- Place towers on sandy build pads.
- Start each wave when ready.
- Earn funds by defeating enemies and clearing waves.
- Tap a tower to select it, then tap again to sell.
- With a tower selected, tap **Upgrade** to level it up (if affordable).
- Survive all 12 waves to win.

## Seagull Support Mechanic

Each wave now includes 3 seagull flyovers:

- Seagulls cross the map from right to left at random times.
- Each seagull drops a random bomb strike location.
- Bombs damage enemies in an area, acting as a lucky bonus event.

## Mobile Controls

- Tap tower cards to select what to build.
- Tap a sandy build pad on the map to place selected tower.
- Tap a placed tower to select it.
- Tap selected tower again to sell it.
- Tap the wave button (**x1/x2**) to toggle fast-forward.
- Use **Start Wave**, **Upgrade**, **Pause**, and **Restart** buttons.

## Run Locally

Open `index.html` directly in a browser.

## Host on GitHub Pages

1. Push this repo to GitHub.
2. Open repository **Settings** -> **Pages**.
3. Under **Build and deployment**:
   - Source: **Deploy from a branch**
   - Branch: `main` (or your default branch), folder: `/ (root)`
4. Save and wait for deployment.
5. Open your Pages URL on your phone and play.
