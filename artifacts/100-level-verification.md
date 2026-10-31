# Hundred-level campaign verification

This report records verification on 30 October 2026 for the 100-level campaign. The earlier twelve-level report is historical evidence and does not establish completion of the checks below.

## Current verification status

- Full core suite: **29 tests passed, zero failures** in Release configuration. All 100 exact certificates passed after checking **250,489 networks in 35.088 seconds**; the slowest was level 68 at 2.596 seconds. See `campaign100-core-final.log`.
- All 100 fixtures complete their orders at the stated minimum, advance independently, and produce a 300-star campaign. The original twelve definitions and fixtures retain their golden fingerprints. A completed twelve-level save preserves its current plan, undo history, and 36 stars, then unlocks level thirteen without resetting progress.
- The appended 88 footprints are unique under rotation and reflection, including comparison with the original twelve. The five bands use 6, 6, 7, 8, and 9 buildings in their optimal plans, with rising average costs.
- `scripts/generate-level-catalog.sh --check` reproduced all 88 appended entries byte-for-byte and passed the full 29-test Release suite again. See `catalog-reproducibility.log`.
- Compact native coverage: **all seven scenarios passed**, combining six passing scenarios in the initial suite with the corrected representative-level rerun. This covers first-twelve-level play, chapters, levels 13/25/50/75/100, coin accounting, all scoring tiers, replay persistence, drag/stroke/restart, settings, interrupted completion, and largest accessibility text.
- Large native coverage: **all three selected scenarios passed, zero failures**: first-twelve-level/chapter play, representative later-level play, and largest accessibility text. The four other behavioral scenarios were verified on the compact simulator.

An independent Python audit checked all appended fixtures without importing the Swift rules: terrain and action legality, simple routes containing a road, delivered goods, piece limits, costs, thresholds, and canonical footprints all passed. It found legal two-star surplus plans on 88/88 appended levels and one-star surplus plans on 86/88. Levels 16 and 68 had no one-star witness under this bounded surplus-road/bridge/clearing search. The audit does not search all producer relocations or nonoptimal layouts, so those two results are inconclusive rather than proof that one star is impossible. See `catalog-independent-audit.py` and `catalog-independent-audit.log` for the reproducible checks and catalog hash. No game thresholds were changed for this audit.

## Native test scope

The first twelve levels are built sequentially through real taps and drags, yielding 36 of 300 stars and unlocking level thirteen. A separate test prepares preceding progress only in an isolated Debug test store, then builds levels **13, 25, 50, 75, and 100** through real touches. It verifies fresh budgets, optimal cost, three stars, unlock behavior, and final-level persistence.

The setup argument is `--uitesting --reset-progress --ui-start-level N`. Its handler is compiled only in Debug and cannot write the normal player's store. Earlier records in that late-level test are prepared by fixtures. A 300-star screenshot from this test is evidence of the final-level interface and persisted result, not a claim that all 100 levels were played through the UI.

| Simulator | Verified scenarios | Evidence |
| --- | --- | --- |
| iPhone SE (3rd generation), iOS 26.4.1 (23E254a), `C78F44B1-5F84-4859-915D-6F47B9C6C624` | Six initial scenarios passed, including the first twelve in 286.498 seconds and largest text in 37.456 seconds. The corrected representative test passed all five later levels and final relaunch in 347.728 seconds. | `ui-100-compact.log`, `ui-100-compact-later-fixed.log`, and matching `.xcresult` bundles |
| iPhone 17 Pro Max, iOS 26.4.1 (23E254a), `329508DF-7DA9-4F43-AB8B-D0FC7BE03F8C` | Three selected scenarios passed, zero failures: first-twelve-level/chapter play in 311.043 seconds, largest text in 35.276 seconds, and all five representative levels plus final relaunch in 324.495 seconds. | `ui-100-large.log` and matching `.xcresult` bundle |

This gives ten passing scenario/device combinations: seven on compact across the initial run and corrected rerun, and three on large.

The first compact representative run stopped after completing level 25 because the test queried the offscreen level 27 card before the lazy grid created it. The test helper now selects the chapter, scrolls the card into view, waits for it to exist, and checks the exact locked/unlocked state. The corrected test passed. Earlier preflight also exposed an ambiguous scroll-container lookup; explicit identifiers now distinguish the result sheet, map, and horizontal building tray. These were test-navigation failures, and the assertions remain intact.

Compact later-level screenshots are saved with the `screenshots/campaign100-compact-final-` prefix, including the level 100 plan, three-star result, and prepared-progress campaign map. The level 25/100 layouts and final result were visually inspected and fit the compact screen. Large-screen captures use the `screenshots/campaign100-large-` prefix. Result-summary JSON files accompany the native evidence.

Native verification used `build-for-testing`, then `test-without-building` against the exact generated `.xctestrun` file and an explicit simulator destination. This avoids a project/package-resolution hang observed after a preflight test run. `scripts/verify-ios.sh` now follows the same workflow for the complete suite, selects a unique current-SDK test artifact, and retains sequential execution and 180/600-second limits. Its shell syntax and repository whitespace checks pass; the final native runs exercised these build/test commands directly.

## Release status

| Stage | Result |
| --- | --- |
| Local archive and signature validation | Built at `release/Afterworks-1.0-1.xcarchive`; strict signature verification passed |
| Apple agreement and access | Agreement accepted with the user's explicit authorization; Apple account access restored |
| App registration | Bundle `com.afterworks.game` registered; App Store Connect app ID `6828880932`, listing **Afterworks: Island Puzzles** |
| Distribution export | Succeeded using the explicitly approved temporary team API key; exact uploaded package preserved at `release/Afterworks-1.0-1.ipa` |
| Upload | Succeeded at 09:04:35 CDT on October 30, 2026; `EXPORT SUCCEEDED`, exit 0 |
| Processing | Completed; Apple displayed **Ready to Test** |
| TestFlight group assignment and availability | Build **1.0 (1)** assigned to **Internal Testing**, with one tester (the current user); group build status **Testing**, expires in 90 days |

The listing uses **Afterworks: Island Puzzles** because **Afterworks** was unavailable in App Store Connect. The on-device app name remains **Afterworks**. The internal group ID is `d629b856-3cff-46a0-acdb-52ebdbfd9706`. Agreement acceptance and the prepared group are captured in `release/apple-agreement-accepted.png` and `release/internal-group-prepared.png`.

The first export attempt failed because the local Xcode account could not authenticate, and the Mac was locked. With the user's explicit approval, API terms were accepted and a temporary Admin team key was used for signing and upload. `release/export-upload-api.log` records upload success. The temporary key was revoked after upload, and its local private-key file was deleted; revocation is captured in `release/temporary-api-key-revoked.png`. The pre-existing team key was left unchanged. TestFlight processing completed and the build is now available to the internal group. The group shows one tester and one build with status **Testing**, captured in `release/testflight-internal-testing.png`. Build ID: `53663f08-5aeb-40ee-8547-5a5f0d67f0ff`. The current user's tester status is **Invited** (October 30, 2026), captured in `release/testflight-tester-invited.png`. Build-specific testing notes were saved. Installation on the physical iPhone remains the user's next action. This is internal TestFlight distribution; no public App Store submission was made.

The device archive contains `com.afterworks.game` version **1.0 (1)**, arm64 code, iOS 17 minimum deployment, and iOS SDK 27.1 metadata. It is signed with **Apple Development**, a cached wildcard development profile, and `get-task-allow = true`. The uploaded IPA was subsequently re-signed with Apple Distribution for C&F Studios, LLC. Its application and provisioning entitlements have `get-task-allow = false` and `beta-reports-active = true`; strict signature verification passed. The exact IPA SHA256 is `c655a631a8319f1ecc4e36a7fc2c2b34aa16d95e567e8f2de582136670acb271`; see `release/distribution-audit.json`. The Release executable contains the final catalog markers and no test-launch/setup strings. It has no bundled third-party frameworks or privacy manifests; the direct required-reason symbol scan found no matches.

The original archive executable and source-backup hashes in `release/release-evidence.json` remain unchanged. A read-only comparison confirmed the archive hash and all 43 source-backup content files before this release-status documentation update. Core and app source remain unchanged.

## Local release review

- `Info.plist` passes `plutil -lint`. The app icon is 1024 × 1024 with no alpha channel. The app targets iPhone and iOS 17 or later.
- The installed toolchain is Xcode 27.1 with iOS SDK 27.1, above the current iOS 26 SDK upload minimum. [Apple SDK requirements](https://developer.apple.com/news/?id=ueeok6yw)
- Source review found only the local core package and Apple frameworks, local JSON persistence, bundled audio playback, and haptics. No network, tracking, protected microphone/camera/location access, or listed required-reason API use was identified. There is no privacy manifest; its absence was not identified as a source-level upload blocker for the APIs currently used. Archive validation remains separate. [Required-reason API list](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- Release compilation omits test setup and treats test-store launch arguments as disabled. The non-exempt-encryption declaration is false, consistent with the current code's lack of custom encryption.
- TestFlight processing and assignment to a tester group must be confirmed separately from upload. External beta review also needs test information, including a beta description and feedback address. [Internal testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/), [test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/)

## Boundaries

All levels are fixed bundled data; generation does not run while playing. Full-catalog solvability and cost checks are separate from sampled native UI play. Physical-device tactile feedback, speaker quality, a full VoiceOver session, and human difficulty calibration require hands-on checks. Upload success alone does not establish TestFlight availability.

## External testing follow-up

Build **1.0 (2)** was uploaded with external TestFlight distribution enabled, assigned to the **Friends** external group, and submitted to Apple Beta App Review on October 30, 2026. Its status is **Waiting for Review**. The public invitation https://testflight.apple.com/join/R5s4aQjG is limited to one tester and is not yet installable pending approval. The signed game code and resources match build 1 exactly. Detailed evidence is in `release/external-1.0-2/release-report.md` and accompanying audit files. The temporary upload key was revoked and deleted locally. No public App Store release was submitted.
