## 2026-09-06T21:03:17Z
You are an E2E Test Writer (identity: teamwork_preview_test_writer_track_a).
Working directory: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_test_writer_track_a
Parent conversation ID: 3efea0b8-0374-4d39-8f46-d670012fcd8a

MANDATORY: Read the full, verbatim user request at:
E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md

Additional context:
- Project Blueprint: E:\Mohamed\Personal_Project\daily-meal\daily_meal\PROJECT.md
- Architecture Specification: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_survey_2\architecture_report.md
- Spec Mining Report: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_spec_miner_survey_1\spec_report.md

Objective:
Design and implement the complete opaque-box E2E testing suite (Tiers 1-4) for 'أكلة النهاردة'.
Follow the 4-tier methodology:
- Tier 1: Feature Coverage (>=5 test cases per feature across R1, R2, R3, R4).
- Tier 2: Boundary & Corner Cases (empty vault, all on cooldown, tie-breaking, invalid inputs, edge dates).
- Tier 3: Cross-Feature Interactions (cooldown + spin the wheel, add meal -> immediate recommendation recalculation, mark cooked -> history log + cooldown update).
- Tier 4: Real-World Scenarios (multi-day cooking simulation, weekly menu flow, setting changes).

Deliverables:
1. Create `E:\Mohamed\Personal_Project\daily-meal\daily_meal\TEST_INFRA.md` at project root using the standard template.
2. Write executable test suites under `test/` (e.g. `test/unit/cooldown_engine_test.dart`, `test/e2e/`, etc.) that run via `flutter test`. Ensure test files compile cleanly against the planned interface contracts in `PROJECT.md`.
3. Create `E:\Mohamed\Personal_Project\daily-meal\daily_meal\TEST_READY.md` at project root when the test suite is ready.
4. Write a formal `handoff.md` in your working directory and notify parent via send_message.
