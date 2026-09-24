# Target Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iOS squat counter keep one explicitly selected person in a multi-person scene, abstain when identity is uncertain, and establish a portable event contract for Android.

**Architecture:** Keep MediaPipe and AVFoundation behind the iOS adapter. A pure Swift target tracker receives all pose candidates and produces selected/uncertain/lost decisions; a separate squat counter consumes only selected observations. Persist source and evaluation provenance outside Git. Android will later implement the same contract in Kotlin against shared fixtures, after the iOS beta gate.

**Tech Stack:** Swift 6, SwiftUI, MediaPipe Tasks, AVFoundation, Swift Package tests; Android Kotlin/CameraX/MediaPipe in a later tranche.

**Spec:** User-approved plan in this task, reflected in `roadmap.md` and `docs/decisions.md`.

## Global Constraints

- No facial recognition, persistent cross-session identity, or claim of exercise correctness.
- On uncertain identity, retain completed count, invalidate partial cycle, abstain and prompt reselection if automatic recovery is not confident.
- Keep personal video, appearance descriptors and model files outside Git.
- M0 and M2 gates require manually annotated holdout evidence, not only unit tests or synthetic clips.
- iOS beta precedes Android beta; Android must pass the same behavioral fixtures and independent device QA.

## Review Focus

- A crossed athlete must not complete the selected athlete's partial repetition.
- Reordered pose arrays must not silently change the selected identity.
- A long occlusion must not become an automatic count on reappearance.
- Imported video timestamps and live camera timestamps must remain monotonic within a session.
- A detector returning no pose must yield an abstention, not a zero-angle squat sample.

---

### Task 1: Baseline evidence and private corpus inventory

**Files:** Modify `docs/qa-status.md`, `docs/m0-annotation-protocol.md`; private recordings stay outside this repository.

**Interfaces:** Produces an inventory of copied, authorized recordings, a status of manually annotated cycles and explicit M0 gaps.

- [x] Copy the existing app's history index and recordings without removing device originals; record counts and hashes privately.
- [x] Verify the codebase test and simulator build baselines.
- [x] Update QA status with observed facts only; do not promote app counts to ground truth.
- [x] Verify `git status --short` contains no personal media.

### Task 2: Pure target association and abstention

**Files:** Create `ios/Sources/SquatCounterCore/TargetTracker.swift`; create `ios/Tests/SquatCounterCoreTests/TargetTrackerTests.swift`.

**Interfaces:** Produces `PoseCandidate`, `TrackingDecision`, `TargetTracker.select(_:at:)`, and `TargetTracker.update(_:at:)`; Task 3 consumes them.

- [x] Write tests for selection, pose-list reordering, crossing ambiguity, disappearance, and recovery only after fresh confirmation.
- [x] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter TargetTrackerTests`; observed expected missing-type failure.
- [x] Implement minimal association with normalized geometry and conservative ambiguity rejection; no appearance embedding in this tranche.
- [x] Run the targeted tests and full `swift test`; 29 tests green.
- [x] Commit only code and tests.

### Task 3: Reset partial repetition on identity loss

**Files:** Modify `ios/Sources/SquatCounterCore/SquatCounterCore.swift`; modify `ios/Tests/SquatCounterCoreTests/SquatCounterTests.swift`.

**Interfaces:** Produces `SquatCounter.interruptTracking(at:)` so the app can discard a partial cycle without resetting completed counts; Task 4 consumes it.

- [x] Write a test where descent belongs to one person, identity is interrupted, and another person's ascent cannot produce `+1`; prior completed count remains.
- [x] Run targeted test; observed failure for missing interrupt API.
- [x] Implement interruption and require a fresh standing observation before another cycle.
- [x] Run targeted and full Swift tests; 30 tests green.
- [x] Commit code and test.

### Task 4: iOS multi-pose adapter and explicit selection

**Files:** Modify `ios/Sources/SquatCounter/PoseDetector.swift`, `ios/Sources/SquatCounter/WorkoutSession.swift`, and `ios/Sources/SquatCounter/ContentView.swift`; add UI/integration tests where feasible.

**Interfaces:** Consumes Tasks 2–3. Detector returns all candidates; live UI shows selectable people and selected/uncertain state. No count is produced before selection in a multi-person scene.

- [ ] Add integration/UI tests for no selection, tap selection, lost target, and reselection; watch failures.
- [ ] Set MediaPipe `numPoses`, map each pose to geometry and knee angle, and feed only the selected observation to the counter.
- [ ] Add on-screen warning and optional audible warning; never count an uncertain candidate.
- [ ] Run Swift tests, simulator build and UI tests; document any physical-device-only checks.
- [ ] Commit code and tests.

### Task 5: Android contract preparation and QA handoff

**Files:** Add shared fixture format and update `roadmap.md`, `CLAUDE.md`, `docs/architecture.md`, `docs/decisions.md`, `docs/qa-status.md`.

**Interfaces:** Produces versioned observable behavior for the later Kotlin implementation; does not assert Android runtime validation.

- [ ] Add cross-platform fixture(s) for count, lost ID and safe restart; Swift test must read them.
- [ ] Update documentation with pending real-corpus gate, Android native implementation path, device prerequisites and privacy boundaries.
- [ ] Run full Swift suite, iOS simulator build, and check that no private files are tracked.
- [ ] Commit docs and fixtures; request one final whole-branch review.
