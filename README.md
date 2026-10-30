# Afterworks

A native, offline iPhone puzzle game about building efficient delivery routes. Twelve independent, authored islands progress from one orchard and one road to a combined production network. Spend gold coins on construction, fulfil the order, and earn up to three stars for an economical solution.

## Run

1. Open `Afterworks.xcodeproj` in Xcode.
2. Select the shared **Afterworks** scheme and an iPhone simulator.
3. Run. No server, account, external dependencies, or configuration is required.

The project targets iOS 17 or later and uses Swift 5 language mode. The available toolchain is Xcode 27.1. For a physical iPhone, select your development team under **Afterworks → Signing & Capabilities**, choose a unique bundle identifier if needed, select the connected device, and Run.

```sh
xcrun simctl list devices available
scripts/verify-ios.sh <simulator-udid>
```

The verification script runs the rules tests, builds the app, and runs the native UI suite sequentially on the selected simulator. It keeps the Mac awake only while testing and applies bounded timeouts. The full twelve-level touch test has a 600-second allowance; ordinary tests use the shorter default. Logs and result bundles go into `artifacts/`.

```sh
xcodebuild build -project Afterworks.xcodeproj -scheme Afterworks \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO

python3 scripts/export-screenshots.py artifacts/<result>.xcresult <device-name>
```

## Play

- Select a building or road and tap a highlighted tile, or drag the piece from the tray onto the island. Drag across neighboring cells with Road selected to lay one undoable stroke.
- Every producer must reach the depot through an orthogonal infrastructure route containing at least one road tile. Standing beside the depot never gives an automatic connection. Buildings do not carry traffic. Bridges cross water and wetland.
- Gold coins are the construction budget for the current level. Removing a placed piece refunds its full price; invalid actions spend nothing. Undo restores the previous plan, coins, and valid dispatch result. Clearing woodland has an explicit coin cost and produces no timber.
- Stone, food, and timber are delivery objectives. Dispatch calculates each connected producer's output once and animates that exact result along the built route. Repeated dispatch does not accumulate goods, stars, or unlocks.
- Three stars require the verified minimum coin cost. Two stars allow the level's displayed additional spending; any successful plan within the budget earns one star. Score uses net coins spent on the plan. The highest star result and lowest successful cost are retained when replaying a level.
- A successful dispatch unlocks the next level immediately. Keep improving, retry, or move on. Every level starts with its own terrain, empty building layout, and full coin budget. Boards and goods never carry between levels.
- The level map shows twelve fixed puzzles, completed stars, locked levels, and a maximum of 36 stars. Level generation is intentionally deferred.
- Inspect any tile for its terrain, output, connection status, and actual delivery route. The tile-list interface provides equivalent accessible building and inspection actions.
- The menu includes restart, level selection, sound, and haptic settings. Restarting preserves earned stars and unlocked levels. System Reduce Motion disables environmental movement and shortens visual delivery effects.

## Rules and balance

Costs, outputs, per-level piece limits, budgets, star thresholds, terrain, and orders are centralized in `Sources/AfterworksCore/`. Every level includes a reproducible optimal fixture. Native tests translate those fixtures into ordinary taps on the app.

Fields need adjacent water or wetland beneath them. A field on wetland, or within two orthogonal steps of a connected reservoir, gets a food bonus. Bonuses do not stack. A reservoir must be beside water and have its own road connection. Woodland supplies adjacent lumber camps; clearing it produces no timber. Cliffs are impassable and cannot be built on or cleared.

Coordinates use columns **A–G** from west to east and rows **1–7** from north to south. The optimal action sequences are in `SolutionFixture.primary`. For each island, `MinimumCostProof.verify` first plays the fixture, then exhausts every cheaper connected infrastructure network that could still afford enough production. It checks woodland clearing choices, every legal reservoir site, and producer assignments. The optimistic production bound ignores placement restrictions, so it cannot exclude a cheaper successful layout. The core tests require both a successful fixture at the stated cost and no cheaper completion. Costs and outputs come from `Balance`; the verifier supports the authored rules, positive delivery orders, and at most one reservoir per level.

| Level | Island | Main lesson | Budget | 3 stars | 2 stars |
| --- | --- | --- | ---: | ---: | ---: |
| 1 | First delivery | One orchard and one road | 9 | 5 | 7 |
| 2 | A little farther | Extend the route | 10 | 6 | 8 |
| 3 | Better together | Share roads between orchards | 14 | 9 | 11 |
| 4 | Stone & supper | Deliver two resources | 17 | 11 | 14 |
| 5 | At the wood's edge | Keep woodland beside camps | 17 | 11 | 14 |
| 6 | Across the blue | Bridge between shores | 19 | 13 | 16 |
| 7 | The price of a shortcut | Compare crossing costs | 21 | 14 | 17 |
| 8 | Soft ground | Use productive wetland | 18 | 12 | 15 |
| 9 | Water within reach | Irrigate connected fields | 20 | 13 | 16 |
| 10 | Room for everyone | Clear a route while preserving woodland | 26 | 19 | 23 |
| 11 | A full manifest | Combine all three resources | 33 | 25 | 29 |
| 12 | Every coin counts | Plan clearing, irrigation, and a crossing together | 42 | 33 | 37 |

Star columns are maximum coins spent. Completing an order above the two-star threshold, but within its budget, earns one star.

## Saving and architecture

- `Sources/AfterworksCore/`: level definitions, placement and connectivity, deterministic evaluation, star scoring, campaign progress, undo, validation, optimal fixtures, and minimum-cost checks.
- `Afterworks/App/`: SwiftUI presentation, controller, versioned persistence, and sound/haptics.
- `Afterworks/Rendering/`: original SpriteKit terrain/buildings, matching tray artwork, touch input, and presentation-only animations.
- `Tests/AfterworksCoreTests/`: focused rules and campaign tests.
- `AfterworksUITests/`: actual touch progression, stars, replay, drag gestures, settings, accessible interaction, and interrupted dispatch/relaunch.

Campaign saves use version 2 JSON in `campaign.json` under the app's Application Support directory. They include the active plan, remaining coins, current evaluation, undo history, best level results, and settings. Writes are atomic and decoded state is validated. Completion is saved before delivery animation, so quitting cannot duplicate a reward or lose an already committed unlock.

The earlier prototype's `journey.json` is preserved. Its settings can be carried forward; its era terrain is not converted into completed independent levels. Test launches use a separate `Afterworks-Testing` save directory. `--uitesting --reset-progress` resets only campaign test data.

The app uses SwiftUI, SpriteKit, AVFoundation, and local Swift code. Original assets and audio are bundled, with reproducible generators under `scripts/`. There are no network requests, tracking, purchases, or generated levels.

## Evidence and limits

The campaign passed 23 core tests and all six native UI scenarios on both iPhone SE (3rd generation) and iPhone 17 Pro Max simulators running iOS 26.4. Both devices completed all twelve levels through touches for 36 stars; the suite also covers the largest accessibility text size, replay, persistence, and interrupted delivery. All twelve minimum coin costs are verified.

See `artifacts/campaign-verification.md` for the exact runs and `artifacts/screenshots/` for running-app captures. Physical-device feedback and human difficulty calibration still benefit from hands-on playtesting. All twelve puzzles are fixed and solvable; the increasing challenge is authored rather than a claim that every player will experience a strictly increasing difficulty curve.
