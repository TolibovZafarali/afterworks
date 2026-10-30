# Campaign verification

This report applies to the twelve-level campaign revision. Results from the earlier three-era prototype are historical and do not establish verification of the new campaign.

## Test environment

Both simulators used iOS 26.4.

| Size | Device | Simulator identifier |
| --- | --- | --- |
| Compact | iPhone SE (3rd generation), Afterworks Compact | `C78F44B1-5F84-4859-915D-6F47B9C6C624` |
| Large | iPhone 17 Pro Max, Afterworks Large | `329508DF-7DA9-4F43-AB8B-D0FC7BE03F8C` |

## Confirmed integration checks

- `xcodebuild build-for-testing` succeeded for the integrated app and native test target.
- The final build after the woodland icon correction succeeded in `campaign-build-final.log`. The final app was installed and launched normally on both simulators; `screenshots/campaign-large-ready.png` records the ready state.
- A normal launch on the large iPhone simulator preserved the earlier `journey.json` byte-for-byte while creating a version 2 `campaign.json` with zero completion records and matching imported settings. The preserved legacy file's SHA-256 was `5e0901e83b1504d551e964b41d0d226ed7d285b47a5c21bad7048f067c3e14c0`.
- The initial twelve-level map was inspected in `screenshots/campaign-large-level-map.png`.
- `swift test` passed all 23 core tests with zero failures; see `campaign-core-final.log`. The checks include independent level resets, coin accounting, all star tiers, replay records, unlocks, saved-state validation, irrigation, woodland, and simple road-containing delivery routes.
- All twelve optimal fixtures complete their orders. Exhaustive minimum-cost certificates checked 151 potentially cheaper infrastructure networks, including legal woodland clearing, reservoir, and producer choices. None completed the order below its target: **5, 6, 9, 11, 11, 13, 14, 12, 13, 19, 25, 33 coins**.
- The compact simulator smoke test for direct depot contact, invalid placement, refunds, and undo passed; see `campaign-compact-smoke.log` and `.xcresult`.
- Five compact simulator behavior tests passed in `campaign-compact-final.log` / `.xcresult`: direct-contact and refund behavior; the largest accessibility text size; piece drag, atomic road stroke, restart, and clean next level; settings, accessible placement, backgrounding, and interrupted completion; and one-, two-, three-star replay with persistent best results. Screenshots use the `campaign-compact` prefix.
- The final compact verification bundle passed both selected tests with zero failures; see `campaign-compact-verified.log` / `.xcresult`. The twelve-level touch test finished in 201.447 seconds: it built every optimal solution through ordinary touches, verified each fresh budget and three-star result, unlocked every island, and reached **36 of 36 stars**. The corrected largest accessibility text size also passed from map through level one, scorecard, and level two.
- Exported compact captures of the largest text size, mixed final board, final scorecard, and all twelve completed map cards were visually inspected. Coin counts, objectives, board, and primary controls remain readable and reachable.
- The complete large iPhone suite passed **all six tests with zero failures** in 416.316 seconds; see `campaign-large-verified.log` / `.xcresult`. Its twelve-level playthrough finished in 202.026 seconds with 36 stars. The remaining cases verified direct-contact rejection and refunds, largest accessibility text size, drag/stroke/restart, settings and interrupted completion, and all scoring tiers with replay persistence.
- Large gameplay, completed map, and final scorecard captures were inspected. The final board spends 33 coins, its result shows 36 of 36 campaign stars, and all twelve map cards display three stars. Large screenshots use the `campaign-large` prefix.

## Native coverage

All six native test scenarios passed on both phone sizes. Compact evidence combines the five behavior passes with the final progression and largest-text-size run; the large evidence is one complete six-test bundle. Tests use ordinary taps, piece drags, and road gestures, rather than injecting a completed game state. They verify:

- All twelve optimal solutions, fresh level budgets, required roads, unlocked levels, and 36 stars.
- Invalid placement without spending, removal refunds, and atomic undo.
- One-, two-, and three-star results, replay improvements, and preservation of a better prior result.
- Independent next levels, restart without losing best results, saved settings, and accessible tile actions.
- Relaunch and background behavior, including termination immediately after dispatch and after advancement.
- The largest accessibility text setting, visible board and primary controls, and reachable scorecard actions.

Representative captures include [compact final board](screenshots/campaign-compact-12-level-12-plan.png), [large final board](screenshots/campaign-large-12-level-12-plan.png), [final scorecard](screenshots/campaign-large-12-level-12-three-stars.png), and [completed level map](screenshots/campaign-large-13-campaign-complete-36-stars.png).

## Boundaries

Level generation is deferred. Physical-device signing, tactile feedback, speaker quality, and a full VoiceOver user session require separate device checks. Automated solution validation establishes solvability and cost targets; human playtesting is still needed to calibrate perceived difficulty.
