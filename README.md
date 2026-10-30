# Afterworks

**Build for today. Shape tomorrow.** A native, offline iPhone strategy game built with SwiftUI and SpriteKit. Three connected eras unfold on one 7 × 7 island. Your connected quarries become lakes, orchards become woodland, and reservoirs become wetland at their exact coordinates.

## Run

1. Open `Afterworks.xcodeproj` in Xcode.
2. Select the shared **Afterworks** scheme and an iPhone simulator.
3. Run. No dependencies to download, server, account, or configuration required.

The project targets iOS 17 or later and uses Swift 5 language mode. It was built with Xcode 27.1. To run on a physical iPhone, select your development team under **Afterworks → Signing & Capabilities**, choose a unique bundle identifier if needed, select the connected device, and Run. Physical-device signing is intentionally left to your own team.

```sh
xcrun simctl list devices available
scripts/verify-ios.sh <simulator-udid>
```

The script runs the rules tests, builds the real application, and runs the native UI tests. Logs and result bundles go into `artifacts/`.
It keeps the Mac awake only while tests run and applies bounded test timeouts. Export the retained screenshots with `python3 scripts/export-screenshots.py artifacts/<result>.xcresult <device-name>`.

For a build without tests:

```sh
xcodebuild build -project Afterworks.xcodeproj -scheme Afterworks \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO
```

## Play

- Select a piece and tap a highlighted tile, or drag the piece from the tray onto the island. Scroll the tray for more pieces. Drag across neighboring board cells with Road selected to create one undoable stroke.
- The **BUILD** number is the only construction currency. New pieces refund their full cost when removed. Invalid placements spend nothing. Undo restores the preceding plan, budget, and valid dispatch result.
- Resource numbers show the output of the current plan against its order. Dispatch animates that exact result once. Repeating it cannot accumulate goods. Editing invalidates the previous check.
- Roads join orthogonally. Producers must touch the depot or a road/bridge network reaching it. Buildings never carry traffic. Lakes and wetland require bridges.
- **Preview next era** is read-only and uses the same transformation as actual advancement. Only valid, connected buildings receive their legacy. Inactive buildings disappear, leaving their underlying terrain. All built roads and bridges persist as free old routes.
- Use the pointer to inspect a tile’s output, actual route, and future. The question-mark button explains every rule and shows the last dispatch report.
- The journey menu has sound/haptic settings, restart, rewind, new journey, and home. New journey, restart, and rewind require confirmation. New journeys preserve settings.
- The **tile list** offers the same building and inspection actions as the visual board, with descriptive accessibility labels. System Reduce Motion disables environmental movement and shortens delivery/era effects.

## Balance

All numbers and piece availability live in `Sources/AfterworksCore/Balance.swift`.

| Piece | Build cost | Output | Limit per era | Legacy |
| --- | ---: | --- | ---: | --- |
| Quarry | 5 | 4 stone | 2 | Lake |
| Orchard | 4 | 3 food | 3 | Woodland |
| Lumber camp | 4 | 4 timber | 3 | Meadow; adjacent woods remain |
| Field | 3 | 3 food, sometimes +2 | 4 | Meadow, or preserves underlying wetland |
| Reservoir | 4 | Irrigates fields | 2 | Wetland |
| Road | 1 | Connection | 49 | Old route |
| Bridge | 3 | Water/wetland connection | 8 | Old bridge over unchanged terrain |

Fields need adjacent lake or wetland beneath them. Fields on wetland **or** within Manhattan distance 2 of a valid connected reservoir receive +2 food. These bonuses do not stack. A reservoir must touch a lake and connect to the depot. Clearing woodland costs 2 and yields no timber. Removing an inherited road or bridge costs 1 with no refund; lakes and wetlands cannot be moved or filled.

| Era | Construction | Order |
| --- | ---: | --- |
| First foundations | 22 | 4 stone, 6 food |
| What remains | 26 | 10 food, 4 timber |
| A lasting place | 26 | 4 stone, 8 food, 8 timber |

## Reproducible journey

Columns are **A–G**, rows are **1–7** from north to south. The depot is **D7** throughout. Place each era’s pieces, Dispatch, then Advance. `SolutionFixture.primary` contains the same sequence as executable Swift actions; `SolutionFixture.alternative` mirrors it for another complete journey.

| Era | Roads | Producers/support |
| --- | --- | --- |
| 1 | D6, D5, C5, D4, D3 | Quarry B5; orchards C3, E5 |
| 2 | C4, C6, A6, A7, B7, C7 | Reservoir B4; fields B6, A5; lumber camp E4 |
| 3 | E6, F6, D2 | Quarry F5; fields B4, B6; lumber camps C2, E4 |

Remaining construction is 4, 6, and 4. Era 1 leaves a lake at B5 and woodland at C3/E5. Era 2 leaves wetland at B4. The alternative first plan leaves its lake at F5; B6 can no longer host a field while F6 can. Tests verify both complete journeys and these different later opportunities.

## State and architecture

- `Sources/AfterworksCore/`: board and balance definitions, placement/connectivity, deterministic delivery, shared transformation, undo/checkpoints, reproducible fixtures. No rendering framework imports.
- `Afterworks/App/`: SwiftUI interface, controller, atomic versioned local persistence, optional sound/haptics.
- `Afterworks/Rendering/`: original layered vector scenery, matching tray glyphs, touch input, and presentation-only animation.
- `Tests/AfterworksCoreTests/`: focused deterministic rules tests.
- `AfterworksUITests/`: real touch journeys, drag gestures, invalid placement, preview, undo, restart/rewind, background/relaunch, settings, and accessible building.

Saves are version 1 JSON in the app’s Application Support directory. They include the current plan, construction, evaluation, undo states, checkpoints, completed-era results, tutorial progress, and settings. Available pieces are derived from the saved era and centralized balance. Saves are validated on load and written atomically. Unsupported/corrupt files are preserved until the player confirms a replacement. Advancement is committed and saved **before** its visual transition; animations never produce resources or mutate the journey.

UI tests use a separate `Afterworks-Testing` save directory. `--uitesting --reset-journey` clears only that test journey; production saves are unaffected.

Original art is drawn locally with SpriteKit shapes. The app icon and short audio cues are bundled, with reproducible generators under `scripts/`. There are no external packages, network requests, tracking, or purchases.

## Verification evidence

See `artifacts/verification.md` for the exact completed checks and limitations, and `artifacts/screenshots/` for captures from the running application. Human pacing and physical-device sound/haptics still benefit from a device playtest; the 3–5-minute-per-era target is a design goal, not a measured user study.
