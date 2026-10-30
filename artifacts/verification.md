# Verification

Verified locally on October 29, 2026 with Xcode 27.1 (27A9275), the shared `Afterworks` scheme, and dedicated iPhone simulators. No production data or another app's simulator was reset.

## Automated checks

- `swift test`: **23 tests passed, 0 failures**. Log: `core-tests-final.log`.
- App and native test target: **build-for-testing succeeded**. Log: `build-verified.log`.
- iPhone SE (3rd generation), iOS 26.4 simulator: **5 native UI tests passed, 0 failures**, 202.2 seconds. Result: `ui-compact-verified.xcresult`.
- iPhone 17 Pro Max, iOS 26.4 simulator: **5 native UI tests passed, 0 failures**, 204.8 seconds. Result: `ui-large-verified.xcresult`.
- After final welcome/preview layout refinements, the entire three-era touch journey passed again on the compact iPhone. Result: `ui-compact-layout.xcresult`. Curated compact screenshots come from this final run.

The rules suite covers orthogonal connectivity and rejected diagonals; actual road/bridge routes; direct depot adjacency; buildings not carrying roads; invalid edits spending nothing; repeatable dispatch; editing invalidation and undo restoration; exact-coordinate legacy; surplus/idle producer behavior; preview/advancement equality; grouped road undo; old-route removal and clearing costs; preserved wetland and non-stacking irrigation; disconnected reservoirs; save/load and validation; once-only advancement; restart/rewind; and two complete journeys with different later field/lumber opportunities.

The native suite uses ordinary taps and drags, not preloaded game-state shortcuts. It plays all three eras and checks preview inspection, invalid placement, budgets, successful evaluation invalidation/restoration, tray dragging, continuous roads, restart/rewind, backgrounding/relaunch, sound/haptic settings, accessible tile-list construction, and process termination immediately after Dispatch and Advance. Test saves are isolated from normal play.

## Visual checks

Running-app captures are exported from the native test result bundles. The compact layout was corrected so the full Dispatch button remains visible. Preview labeling was moved away from board coordinates. Original vector terrain, raised structures, inherited routes, connection indicators, selected pieces, and future terrain were inspected at native iPhone sizes.

## Boundaries

Earlier simulator runs were interrupted and subsequently stalled in accessibility/test-manager queries. Their partial results are excluded from the clean verification counts above. Dedicated simulators were restarted and the final suites run sequentially.

Physical-device installation, tactile haptics, device-speaker sound quality, and a full VoiceOver user session were not performed. The accessible tile-list interaction was exercised by native tests. Reduce Motion has an explicit rendering path but was not toggled in a device Settings session. The 3–5-minute-per-era pacing target still needs human playtesting.

The app is a local prototype. It has not been signed for distribution, submitted to the App Store, or published.
