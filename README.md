# Afterworks

A native, offline iPhone puzzle game about building efficient delivery routes. One hundred independent islands are arranged in ten chapters. Start with one orchard and one road, then work toward combined production networks. Spend gold coins on construction, fulfil the order, and earn up to three stars for an economical solution.

## Run

1. Open `Afterworks.xcodeproj` in Xcode.
2. Select the shared **Afterworks** scheme and an iPhone simulator.
3. Run. No server, account, external dependencies, or configuration is required.

The project targets iOS 17 or later and uses Swift 5 language mode. The available toolchain is Xcode 27.1. For a physical iPhone, select your development team under **Afterworks → Signing & Capabilities**, choose a unique bundle identifier if needed, select the connected device, and Run.

```sh
xcrun simctl list devices available
scripts/verify-ios.sh <simulator-udid>
```

The verification script runs the complete core suite in Release configuration so the exact minimum-cost searches use optimized code, then uses `build-for-testing` followed by `test-without-building` with the generated `.xctestrun` file. It selects only the current simulator SDK's unique test-run artifact and stops if that choice is ambiguous. No tests are skipped; the native suite runs sequentially on the explicit simulator destination. The script keeps the Mac awake only while building or testing and applies bounded native test timeouts. The first-twelve-level touch smoke and representative later-level test each have a 600-second allowance; ordinary tests use the shorter default. Logs and result bundles go into `artifacts/`.

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
- The level map shows ten chapters of ten fixed puzzles, completed stars, locked levels, and a maximum of 300 stars. Browse chapters with the chapter picker or arrow controls; Continue opens the current plan directly.
- Inspect any tile for its terrain, output, connection status, and actual delivery route. The tile-list interface provides equivalent accessible building and inspection actions.
- The menu includes restart, level selection, sound, and haptic settings. Restarting preserves earned stars and unlocked levels. System Reduce Motion disables environmental movement and shortens visual delivery effects.

## Rules and balance

Costs, outputs, per-level piece limits, budgets, star thresholds, terrain, and orders are centralized in `Sources/AfterworksCore/`. Every level includes a reproducible optimal fixture. Core tests cover the full catalog; native tests translate the first twelve and representative later fixtures into ordinary taps on the app.

Fields need adjacent water or wetland beneath them. A field on wetland, or within two orthogonal steps of a connected reservoir, gets a food bonus. Bonuses do not stack. A reservoir must be beside water and have its own road connection. Woodland supplies adjacent lumber camps; clearing it produces no timber. Cliffs are impassable and cannot be built on or cleared.

Coordinates use columns **A–G** from west to east and rows **1–7** from north to south. The optimal action sequences are in `SolutionFixture.primary`. For each island, `MinimumCostProof.verify` first plays the fixture, then exhausts every cheaper connected infrastructure network that could still afford enough production. It checks woodland clearing choices, every legal reservoir site, and producer assignments. The optimistic production bound ignores placement restrictions, so it cannot exclude a cheaper successful layout. The core tests require both a successful fixture at the stated cost and no cheaper completion. Costs and outputs come from `Balance`; the verifier supports the authored rules, positive delivery orders, and at most one reservoir per level.

The original twelve introduction levels keep their boards, solutions, and scoring thresholds:

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

Levels 13–100 are built offline and included as fixed data. Their fixtures and minimum costs are checked before shipping. The game does not search for or generate a new puzzle when a player opens a level.

| Levels | Buildings in optimal plans | Minimum coin costs | Additional budget |
| --- | ---: | ---: | ---: |
| 13–24 | 6 | 32–33 | 9 |
| 25–40 | 6 | 35–36 | 9 |
| 41–60 | 7 | 39–40 | 8 |
| 61–80 | 8 | 44–47 | 8 |
| 81–100 | 9 | 50–53 | 7 |

These bands combine irrigation, quarry choices, preserved woodland, clearing, and crossings while gradually tightening the spare budget. The appended island footprints are distinct even when rotated or reflected. `scripts/generate-level-catalog.sh --check` recreates the catalog from its fixed seed recipe, compares it byte-for-byte, and runs the full core suite. Running the script without `--check` writes the rebuilt catalog before validating it.

## Saving and architecture

- `Sources/AfterworksCore/`: level definitions, placement and connectivity, deterministic evaluation, star scoring, campaign progress, undo, validation, optimal fixtures, and minimum-cost checks.
- `Afterworks/App/`: SwiftUI presentation, controller, versioned persistence, and sound/haptics.
- `Afterworks/Rendering/`: original SpriteKit terrain/buildings, matching tray artwork, touch input, and presentation-only animations.
- `Tests/AfterworksCoreTests/`: focused rules and campaign tests.
- `AfterworksUITests/`: actual touch progression, stars, replay, drag gestures, settings, accessible interaction, and interrupted dispatch/relaunch.

Campaign saves use version 2 JSON in `campaign.json` under the app's Application Support directory. They include the active plan, remaining coins, current evaluation, undo history, best level results, and settings. Writes are atomic and decoded state is validated. Completion is saved before delivery animation, so quitting cannot duplicate a reward or lose an already committed unlock.

The hundred-level catalog retains compatibility with the twelve-level campaign: existing plans and earned stars remain valid, and completing level twelve unlocks level thirteen. Expanding the catalog does not reset progress.

The earlier prototype's `journey.json` is preserved. Its settings can be carried forward; its era terrain is not converted into completed independent levels. Test launches use a separate `Afterworks-Testing` save directory. `--uitesting --reset-progress` resets only campaign test data. Debug UI tests can additionally pass `--ui-start-level N` to complete preceding fixtures and start a clean target level. This setup requires `--uitesting`, writes only the test store, and is omitted from Release builds. The representative late-level UI test prepares earlier progress this way, then builds levels 13, 25, 50, 75, and 100 through actual touches.

The app uses SwiftUI, SpriteKit, AVFoundation, and local Swift code. Original assets and audio are bundled, with reproducible generators under `scripts/`. There are no network requests, tracking, purchases, or runtime level generation.

## Evidence and limits

See `artifacts/100-level-verification.md` for the hundred-level campaign's verification and release status, and `artifacts/screenshots/` for running-app captures. The earlier `artifacts/campaign-verification.md` describes the twelve-level revision and is retained as historical evidence. Native coverage is the first twelve levels plus representative later levels; it does not claim that all one hundred levels were played through the UI.

The 29-test Release core suite passes, including exact minimum-cost certificates for all 100 levels. All seven native scenarios pass on the compact simulator; the first-twelve-level/chapter, representative later-level, and largest-text scenarios also pass on the large simulator. Both use iOS 26.4.1 (23E254a). The report records the initial test-navigation failures and corrected reruns separately.

Physical-device feedback and human difficulty calibration still benefit from hands-on playtesting. Challenge progresses through production and route choices; individual players may experience the difficulty curve differently. Simulator verification, archive validation, upload, processing, and TestFlight availability are recorded separately.
