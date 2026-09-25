# Single-target robustness and evidence plan

**Goal:** Keep one explicitly selected squat trainee in focus amid bystanders, pause safely on uncertainty, and establish reproducible private evidence before any beta claim.

**Spec:** User-approved plan in the 2026-09-25 Codex conversation (single-target tracking, 20-clip recording matrix, independent holdout, mobile comparison, private validation video).

**Constraints:** No face recognition, cross-session identity, technique judgment, public use of private footage, or accuracy claim without independent human annotations. iOS first; Android physical validation requires real devices.

**Review Focus:** wrong-person rep credit, resumption after crossing/occlusion, selection loss in clutter, unobservable low-contrast target, accidental leakage of personal footage.

### Task 1: Dataset and evaluation protocol

**Interfaces:** Recording manifest and annotation contract consumed by later evaluation; 12 adjustment and 8 acceptance clips, split by session.

- [x] Document exact capture matrix, independent annotations, failure taxonomy and measurement denominators.
- [x] Implement a pure-core target evaluation input/result format and tests (RED then GREEN), including zero-denominator and wrong-person cases.
- [x] Run targeted and full `swift test`; document baseline limits without invented ground truth.

### Task 2: Safe target continuity

**Interfaces:** `PoseCandidate`, `TargetTracker` and `TrackingDecision` consumed by live and imported-video paths.

- [x] Add failing tests for short detection gaps, ambiguous crossing, no unsafe substitution, and strong-evidence recovery.
- [x] Add session-local appearance evidence only where measurable; keep fallback conservative and clear after the session.
- [x] Run targeted and full `swift test` plus simulator build and UI tests where possible.

### Task 3: Existing private-corpus evaluation

**Interfaces:** Private reports outside Git, public aggregate QA status inside Git.

- [x] Re-run supported simulator clip diagnostics on the supplied videos; separate detector absence, tracker uncertainty and no count.
- [x] Compare baseline and revised behavior on the same clips, without calling automated output ground truth.
- [x] Run full core tests and iOS simulator tests; record observed results and physical-device gaps.

### Task 4: Validation video and handoff

**Interfaces:** Private evidence video; docs for future iPhone/Android work and optional sharing.

- [x] Render an honest private video from actual test media and trace with explicit simulator/annotation limitations.
- [x] Update roadmap, `CLAUDE.md`, model/weight and license decisions, privacy/sharing limits.
- [x] Verify no private media is tracked; request one final whole-branch review with GPT-6 Astra and address important findings.
