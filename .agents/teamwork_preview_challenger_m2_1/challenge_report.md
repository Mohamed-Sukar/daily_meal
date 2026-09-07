# Adversarial Challenge Report — Milestone 2 (CooldownEngine)

**Target**: `lib/features/home/domain/cooldown_engine.dart`  
**Challenger**: `teamwork_preview_challenger_m2_1`  
**Timestamp**: 2026-09-07T00:33:30+03:00  
**Overall Risk Assessment**: LOW  
**Verdict**: **APPROVE**

---

## Executive Summary

As the Empirical Adversarial Challenger for Milestone 2, I conducted rigorous stress-testing against `CooldownEngine`. I authored and executed an independent 32-test adversarial suite (`test/unit/cooldown_engine_adversarial_test.dart`), covering:
1. **Midnight & Calendar Boundaries** (23:59 vs 00:01, month-end, leap year transitions, year-end crossovers).
2. **Extreme Cooldown Parameters** (1 day, 60 days, 0 days, negative days, null settings).
3. **Small Vault Resilience** (0, 1, 2 meals) verifying zero crashes and strict avoidance of false degradation.
4. **Cooldown Saturation & Degradation Cascade** (100% cooldown saturation, protein collision, carbs collision, emergency mode).
5. **Diversity & Collision Stress** (monolithic identical vaults, duplicate instances).
6. **Corrupt & Extreme History Data** (null `mealId`, ghost IDs, future timestamps, multiple entries on same day).
7. **Scale & Determinism** (5,000 history entries, 500 repeated trials, Friday booster across weekdays).
8. **Oracle Fidelity & Confounding Variable Isolation** (evaluating test oracle behavior).

**All 32 adversarial test cases passed successfully.** `flutter analyze` reports 0 issues.

---

## Detailed Empirical Challenges & Findings

### Challenge 1: Midnight Boundaries (23:59 vs 00:01)
- **Assumption Challenged**: Sub-hour proximity across midnight (e.g. 2 minutes between 23:59 and 00:01) might be treated as same-day (0 days) due to timestamp subtraction or timezone drift.
- **Attack Scenario**: Cook a meal at 23:59 on Day D; compute recommendations at 00:01 on Day D+1 (2 minutes later).
- **Observed Behavior**: `CooldownEngine` normalizes all timestamps to calendar dates via `DateTime(year, month, day)`. The date difference is computed as `DateTime(2026, 9, 7).difference(DateTime(2026, 9, 6)).inDays == 1`.
- **Result**: Chicken cooked at 23:59 is accurately classified as cooked "yesterday" (within the `<= 1` calendar day window), and is strictly excluded when `preventRepeatProtein` is active. PASS.

### Challenge 2: Small Vaults & False Degradation (0, 1, 2 Meals)
- **Assumption Challenged**: Fixed `targetCount = 3` could cause vaults with 1 or 2 meals to prematurely degrade to Level 5 (bypassing all rules) even when all meals are eligible.
- **Attack Scenario**: Provide a vault of 1 meal or 2 meals with no cooking history.
- **Observed Behavior**: `targetCount` dynamically clamps to `min(3, meals.length)`.
  - For a 1-meal vault, `targetCount == 1`. At Level 0, candidate count is 1 >= 1. The engine returns immediately at **Level 0** with 1 recommendation.
  - For a 2-meal vault, `targetCount == 2`. Candidate count is 2 >= 2. Returns immediately at **Level 0** with 2 recommendations.
  - For a 0-meal vault, returns empty list at **Level 5** with explicit Arabic explanation: `'قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات.'`.
- **Result**: Zero false degradation. Zero index errors. PASS.

### Challenge 3: Extreme & Boundary Cooldown Parameters
- **Assumption Challenged**: Values like 1 day, 60 days, 0 days, or negative integers could trigger divide-by-zero, integer division overflow, or unexpected inclusion/exclusion.
- **Attack Scenarios Tested**:
  - `cooldownDays = 1`: Strictly excludes delta 0 (today) and delta 1 (yesterday). Admits delta 2 (2 days ago).
  - `cooldownDays = 60`: Excludes meals cooked 59 and 60 days ago; admits meal cooked 61 days ago.
  - `cooldownDays = 0`: Excludes meals cooked today (delta 0 <= 0); admits meals cooked yesterday (delta 1 > 0).
  - `cooldownDays = -5`: Arithmetic remains valid; recency score evaluates cleanly without exceptions.
  - `settings = null`: Safely falls back to default 14 days, protein prevention true, carbs prevention true.
- **Result**: Completely resilient. PASS.

### Challenge 4: Monolithic Vaults & Exhausted Diversity
- **Assumption Challenged**: When all meals in the vault share identical protein and carbohydrates (e.g. 5 dishes that are all Chicken and Rice), the greedy 3-card diversity selector could loop indefinitely, crash, or fail to produce 3 cards.
- **Attack Scenario**: Vault of 5 distinct meals, all typed as `ProteinType.chicken` and `CarbsType.rice`.
- **Observed Behavior**:
  - Card 1: Selects top scoring candidate.
  - Card 2: Attempts distinct protein (fails) -> falls back to next top scorer (`remaining.removeAt(0)`).
  - Card 3: Attempts distinct protein (fails) -> attempts distinct carbs (fails) -> falls back to next top scorer (`remaining.removeAt(0)`).
  - Result: Returns 3 distinct meals.
- **Result**: Graceful fallback without crashing or duplicates. PASS.

### Challenge 5: Corrupt & Orphaned History Records
- **Assumption Challenged**: When meals are deleted from the Drift database, foreign key constraints set `mealId = null` in `MealHistory`. If the engine dereferences `mealId` unsafely, an exception would crash the Home screen.
- **Attack Scenarios Tested**:
  - History record with `mealId = null`: Engine ignores matching against catalog IDs but retains snapshot `proteinType` and `carbsType` for consecutive repeat prevention.
  - History record with non-existent `mealId = 99999`: Handled cleanly without errors.
  - Future timestamp (delta < 0): Handled cleanly without errors.
- **Result**: Robust crash immunity. PASS.

---

## Critical Forensic Finding: Analysis of Peer Auditor Test Failures

During full test suite execution, 3 test failures were observed in `test/unit/empirical_adversarial_m2_test.dart` (authored by peer agent `teamwork_preview_auditor_m2`):
1. `Exact Cooldown Boundary: deltaDays <= C is excluded, deltaDays == C+1 is eligible`
2. `Calendar Leap Year calculation across Feb 28 -> Mar 1 (Leap 2028)`
3. `Mutating cooldown days from 14 to 30 filters meal cooked 20 days ago`

### Root Cause Analysis: Flawed Test Oracle (Confounding Variable)
- In all 3 tests, the test author asserted that a meal cooked outside the cooldown window (e.g. Meal 1) **must appear in the top-3 recommendation cards** selected from a catalog containing 4 to 20 meals.
- This assumption is mathematically invalid because `CooldownEngine` consists of two distinct stages:
  1. **Candidate Filtering** (`_filterCandidates`): Excludes meals within the cooldown window.
  2. **Scoring and Card Selection** (`_rankAndSelectDiversity`): Ranks all eligible candidates using `calculateMealScore`.
- Under `calculateMealScore`:
  - Never-cooked (untried) meals receive a fixed recency reward of **`+25.0`**.
  - A cooled-down meal receives `min(20.0, (deltaDays - cooldownDays) / 2.0)`. For delta = 15 and cooldown = 14, this score is **`0.5`**.
- Therefore, the 19 untried meals in the catalog legitimately outscore the cooled-down meal by ~20 points and occupy the top 3 cards!
- The meal was **NOT** excluded by the cooldown filter; it simply lost the ranking competition to fresher, untried dishes.

### Empirical Proof of Engine Correctness
In `test/unit/cooldown_engine_adversarial_test.dart` (Group 8):
- When the test vault is isolated to 3 meals, the cooled-down meal **is selected at Level 0** in all 3 boundary scenarios (`8.1`, `8.2`, `8.3`).
- When the meal is within the cooldown window (e.g. 14 days or 20 days under a 30-day cooldown), Level 0 cannot find 3 candidates and correctly triggers cascade degradation.

**Remediation Recommendation**: The peer auditor should update `empirical_adversarial_m2_test.dart` to isolate candidate selection (e.g. pass a 3-meal catalog or assert `result.relaxationLevel == 0`).

---

## Verdict: APPROVE

`CooldownEngine` is thoroughly verified, highly resilient, and adheres strictly to the architectural specifications and boundary conditions.
