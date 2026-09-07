# Project Plan: أكلة النهاردة (Daily Meal) Flutter MVP

## Objective
Build a complete, verified MVP for "أكلة النهاردة" Flutter (Android) application with Drift SQLite, Recommendation Engine with Cooldown Algorithm, Spin the Wheel, History, Settings, Notifications, Riverpod state management, GoRouter, Material 3, and Arabic RTL.

## Milestones and Phases
- [ ] Phase 0: Survey & Specification Mining (Parallel Explorers & Spec Miner)
- [ ] Dual-Track Setup:
  - Track A: E2E Testing Track (Test infrastructure, Tier 1-4 tests, TEST_READY.md)
  - Track B: Implementation Track (Milestones M1 to M4)
- [ ] Milestone 1: Drift Database Layer & Data Models (CRUD, meal_history, app_settings, build_runner code generation)
- [ ] Milestone 2: Recommendation Engine & Cooldown Algorithm (Cooldown filtering, protein/carbs repeat prevention, unit tests)
- [ ] Milestone 3: Presentation Layer & State Management (Riverpod providers, GoRouter, Home Screen 3-card stack, Spin the wheel roulette, Quick actions, Add/Edit Meal with immediate UI reflection)
- [ ] Milestone 4: History, Settings & Daily Notification (Past meals log, cooldown configuration, theme mode, flutter_local_notifications setup, Arabic RTL localization)
- [ ] Milestone 5: E2E Integration & Verification
  - Phase 1: 100% E2E test suite pass (Tiers 1-4)
  - Phase 2: Adversarial coverage hardening (Tier 5 challenger loop)
  - Verification: flutter analyze (0 issues), flutter build apk (success)

## Gate Criteria
- Strict verification per iteration: Worker build/tests pass, Reviewers APPROVE, Challengers confirm correctness, Auditor reports CLEAN.
