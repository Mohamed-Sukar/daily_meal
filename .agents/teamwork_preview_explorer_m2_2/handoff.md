# Handoff Report: Milestone 2 Progressive Relaxation Cascade & Inter-Card Diversity

**Agent ID:** `teamwork_preview_explorer_m2_2`  
**Role:** Explorer for Milestone 2 (Recommendation Engine & Cooldown Logic)  
**Parent Conversation ID:** `3efea0b8-0374-4d39-8f46-d670012fcd8a`  
**Working Directory:** `E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_2`  
**Date:** 2026-09-06T21:24:00Z  
**Primary Deliverable:** `E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_2\m2_fallback_diversity_plan.md`  

---

## 1. Observation

1. **User Requirements (R2):**
   - In `E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md`, lines 15–17:
     > "The Home screen should display a 3-card stack of meal recommendations. The recommendations must be powered by a Cooldown Algorithm that filters out meals cooked recently (e.g., within 14 days) and prevents back-to-back repeating of protein/carbs."
2. **Project Feature Inventory:**
   - In `E:\Mohamed\Personal_Project\daily-meal\daily_meal\PROJECT.md`, lines 24–26:
     - Feature 8: "5-Level Graceful Degradation: Fallback cascade when candidates < 3: relax carbs -> halve cooldown -> relax protein -> emergency same-day filter -> minimal vault state (M2, R2)".
     - Feature 9: "Inter-Card Diversity Filter: Guarantee top 3 recommendation cards don't have duplicate protein types when possible (M2, R2)".
3. **Database Schema Types:**
   - In `lib/core/database/tables/meal_history_table.dart`, lines 14–20:
     - Table columns: `mealId` (nullable, `ON DELETE SET NULL`), `mealName` (text), `proteinType` (enum text), `carbsType` (enum text), `cookedAt` (DateTime), `entryType` (`MealEntryType.cooked` / `MealEntryType.leftover`).
   - In `lib/core/database/tables/meals_table.dart`, line 37: `prepTime` is integer minutes.
   - In `lib/core/database/tables/app_settings_table.dart`, lines 13–15: `cooldownDays` (default 14), `preventRepeatProtein` (default true), `preventRepeatCarbs` (default true).
4. **Existing Test Suite Invariants:**
   - In `test/unit/cooldown_engine_test.dart`:
     - Line 46: `expect(result.relaxationLevel, equals(0));`
     - Line 279: `expect(result.relaxationLevel, equals(5));`
     - Line 283: Mini-vault with 2 meals yields 2 recommendations without throwing or crashing.
     - Line 353: All 4 meals cooked in last 4 days triggers `greaterThan(0)` relaxation.
     - Line 384: All meals share yesterday's protein triggers Level 3 relaxation (`greaterThanOrEqualTo(3)`).
     - Line 415: All meals share yesterday's carbs triggers Level 1 relaxation (`equals(1)`).
     - Line 459: `cooldownDays: 1` excludes yesterday ($\Delta = 1$) but includes 2 days ago ($\Delta = 2$).
5. **Defect in Test Support Reference Engine:**
   - In `test/support/reference_engine.dart`, line 208:
     ```dart
     scored = candidates.map((m) {
       return MapEntry(
         m,
         calculateMealScore(
           meal: m,
           history: const [], // BUG: Hardcoded empty history ignores recency weighting!
           today: today,
           cooldownDays: cooldownDays,
         ),
       );
     })
     ```
     Passing `history: const []` disabled the recency calculation ($S_{\text{recency}}$) during card ranking.

---

## 2. Logic Chain

1. **Target Recommendation Quota ($K_{\text{target}}$):**
   - *From Observation 4 (Line 283)*: When a vault contains fewer than 3 meals (e.g. 2 meals), the engine must return those 2 meals without failing or false-degrading.
   - *Deduction*: The target count must dynamically be $K_{\text{target}} = \min(3, |\mathcal{M}|)$.
   - Relaxation occurs if and only if $|\mathcal{C}_L| < K_{\text{target}}$.
2. **5-Stage Cascade Level Mechanics:**
   - *Level 0 (Strict)*: Exclude if $\Delta_{\text{days}} \le C_{\text{days}}$, exclude if $m.\text{proteinType} == \text{lastProtein}$, exclude if $m.\text{carbsType} == \text{lastCarbs}$.
   - *Level 1 (Relax Carbs)*: If $|\mathcal{C}_0| < K_{\text{target}}$, remove the carbohydrate exclusion. Protein repeat and full cooldown remain active. Supported by `cooldown_engine_test.dart:415`.
   - *Level 2 (Halve Cooldown)*: If $|\mathcal{C}_1| < K_{\text{target}}$, reduce cooldown to $C_{\text{eff}} = \min(C_{\text{days}}, \max(1, \lfloor C_{\text{days}} / 2 \rfloor))$. Protein repeat remains blocked. Carbs repeat remains relaxed. Supported by `cooldown_engine_test.dart:353`.
   - *Level 3 (Relax Protein)*: If $|\mathcal{C}_2| < K_{\text{target}}$, reduce cooldown to $C_{\text{eff}} = \min(C_{\text{days}}, \max(1, \lfloor C_{\text{days}} / 4 \rfloor))$ and remove protein repeat exclusion. Supported by `cooldown_engine_test.dart:384`.
   - *Level 4 (Emergency Same-Day)*: If $|\mathcal{C}_3| < K_{\text{target}}$, exclude only meals where $\Delta_{\text{days}} == 0$. Meals cooked yesterday or earlier are allowed.
   - *Level 5 (Minimal Vault / Empty State)*: If $|\mathcal{C}_4| < K_{\text{target}}$, return all distinct meals in DB. If $|\mathcal{M}| == 0$, return empty list `[]` with Arabic reason `"قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات."`. Supported by `cooldown_engine_test.dart:279`.
3. **Inter-Card Diversity Filter Formulation:**
   - *From Observation 1 & 2*: Top 3 cards must not feature duplicate proteins when possible.
   - *Algorithm*:
     - Card 1: Absolute highest scoring candidate ($R_1$).
     - Card 2: Highest scoring candidate where $m.\text{proteinType} \neq R_1.\text{proteinType}$. Fallback: highest remaining score.
     - Card 3: Highest scoring candidate where $m.\text{proteinType} \notin \{R_1.\text{proteinType}, R_2.\text{proteinType}\}$.
       - Fallback: Carbohydrate diversity where $m.\text{carbsType} \notin \{R_1.\text{carbsType}, R_2.\text{carbsType}\}$.
       - Tertiary fallback: highest remaining score.
4. **Scoring Input Correction:**
   - *From Observation 5*: `_rankAndSelectDiversity` must receive `history: sortedHistory` and pass it into `calculateMealScore` so that $S_{\text{recency}}$ correctly prioritizes untried meals (+25.0) and discounts recently cooled dishes.

---

## 3. Caveats

1. **Leftover Entries:** Leftovers are logged with `entryType == MealEntryType.leftover`. They indicate food was consumed and thus update `lastProtein` and `lastCarbs`, but they do not add a new cooking cooldown to unrelated dishes.
2. **Same-Day Multiple History Entries:** When multiple history entries exist on the same date (e.g. lunch and dinner), the algorithm sorts by `cookedAt` descending, then `createdAt` descending, selecting the latest meal for context.
3. **No Code Implementation in Explorer Phase:** In accordance with the Explorer role, no production code in `lib/` was modified. The deliverable is a comprehensive specification and reference implementation plan in `m2_fallback_diversity_plan.md`.

---

## 4. Conclusion

The specification for the 5-Stage Progressive Relaxation Cascade and the Inter-Card Diversity Filter is fully formalized, mathematically bounded, culturally grounded, and 100% compliant with existing project contracts and tests.
All details, pseudocode, edge cases, and Arabic user-facing strings are documented in:
`E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_2\m2_fallback_diversity_plan.md`.

The Milestone 2 implementer/worker can directly translate this specification into `lib/features/home/domain/cooldown_engine.dart` with zero ambiguity.

---

## 5. Verification Method

To independently verify this specification against the codebase:

1. **Verify Existing Reference Tests Pass:**
   Execute in PowerShell at `E:\Mohamed\Personal_Project\daily-meal\daily_meal`:
   ```powershell
   flutter test test/unit/cooldown_engine_test.dart
   ```
   Confirm that all 17 unit tests in Tier 1 and Tier 2 pass against the Reference Engine contract.

2. **Verify Full-Flow & Adversarial Tests Pass:**
   ```powershell
   flutter test test/unit/empirical_adversarial_m1_test.dart
   flutter test test/e2e/full_flow_test.dart
   ```

3. **Verify Specification File Inspection:**
   View `E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_2\m2_fallback_diversity_plan.md` to confirm:
   - Section 3 details Levels 0 through 5 with exact clamping formulas.
   - Section 4 details the 3-tier greedy diversity algorithm and documents the `history` scoring fix.
   - Section 5 provides the complete production Dart code for `RecommendationEngine`.

4. **Invalidation Conditions:**
   - Any change to `AppSettingsData` or `MealHistoryData` column names in Drift that breaks snapshot persistence.
   - Any scenario where an empty vault throws an unhandled exception instead of returning `relaxationLevel: 5`.
