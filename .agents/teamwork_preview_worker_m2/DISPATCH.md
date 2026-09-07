## 2026-09-06T21:24:34Z

You are the Implementation Worker for Milestone 2: Recommendation Engine & Cooldown Logic (identity: teamwork_preview_worker_m2).
Working directory: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_worker_m2
Parent conversation ID: 3efea0b8-0374-4d39-8f46-d670012fcd8a

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY: Read the full, verbatim user request at:
E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md

Read the Explorer Implementation Blueprints:
- Math & Scoring Blueprint: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_1\m2_cooldown_math_plan.md
- Fallback Cascade & Diversity Blueprint: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_2\m2_fallback_diversity_plan.md
- API Bridge & Test Blueprint: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_3\m2_engine_bridge_plan.md
- Project Scope: E:\Mohamed\Personal_Project\daily-meal\daily_meal\PROJECT.md

File Ownership Boundaries:
You EXCLUSIVELY own:
- lib/features/home/domain/cooldown_engine.dart
- 	est/unit/cooldown_engine_test.dart (if any adjustments needed)

Objective:
Implement Milestone 2 production domain logic in lib/features/home/domain/cooldown_engine.dart:
1. Full Cooldown & Recommendation Algorithm:
   - Normalize calendar dates (DateTime(y, m, d)) to prevent intraday elapsed time errors.
   - Strict Cooldown Invariant: lastCookedDate != null && now.difference(lastCookedDate).inDays <= cooldownDays.
   - Context evaluation: find latest cooked meal in history (within <= 1 calendar day, sorting by cookedAt desc, createdAt desc, handling leftovers).
   - Back-to-back repetition filtering for protein (if preventRepeatProtein) and carbs (if preventRepeatCarbs).
   - Scoring formula: untried dishes (+25.0), Friday special (+15.0 on Friday, -5.0 on weekdays), favorite (+5.0), budget friendly (+2.0), daily deterministic jitter ([0.0, 3.96]).
   - 5-Stage progressive relaxation cascade (Level 0 Strict -> Level 1 Relax Carbs -> Level 2 Halve Cooldown -> Level 3 Relax Protein -> Level 4 Emergency Same-Day Exclusion -> Level 5 Minimal/Empty State) targeting {\text{target}} = \min(3, |\mathcal{M}|)$.
   - Inter-card protein diversity selection ensuring distinct proteins across top 3 cards when possible (passing sortedHistory into the scoring function).
   - Compatibility: Support Drift database entities (Meal, MealHistoryData, AppSetting) and generic/contract models.
2. Verification:
   - Run lutter test test/unit/cooldown_engine_test.dart and verify all 17 tests pass.
   - Run lutter test across all suites (all 108 tests must pass).
   - Run lutter analyze and ensure 0 issues.
3. Write changes.md and a formal handoff.md in your working directory (E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_worker_m2).
4. Notify parent via send_message when done.
