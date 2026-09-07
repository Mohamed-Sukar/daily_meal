# Handoff Report: Milestone 2 Cooldown Math & Recommendation Engine Plan

**Agent:** `teamwork_preview_explorer_m2_1`  
**Working Directory:** `E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_1`  
**Parent Conversation ID:** `3efea0b8-0374-4d39-8f46-d670012fcd8a`  
**Task:** Mathematical Algorithms, Scoring Formulas, and Eligibility Rules for Cooldown Engine (M2)  
**Primary Deliverable:** `m2_cooldown_math_plan.md`  

---

## 1. Observation

1. **Original User Request & Requirements (`.agents/ORIGINAL_REQUEST.md`)**:
   - Lines 15-16: *"R2. Recommendation Engine & Home Screen: Implement the core UI and logic. The Home screen should display a 3-card stack of meal recommendations. The recommendations must be powered by a Cooldown Algorithm that filters out meals cooked recently (e.g., within 14 days) and prevents back-to-back repeating of protein/carbs. Include a 'Spin the Wheel' roulette feature for random selection..."*
2. **Architecture Blueprint (`.agents/teamwork_preview_explorer_survey_2/architecture_report.md`)**:
   - Lines 300-373: Outlines mathematical formulation $\mathcal{M}$, $\mathcal{H}$, $T_{\text{today}}$, cooldown window $C_{\text{days}} \in [1, 60]$, scoring formula $\text{Score}(m) = S_{\text{recency}} + S_{\text{friday}} + S_{\text{favorite}} + S_{\text{budget}} + Jitter$, inter-card diversity selection for 3 cards, and 5-level degradation cascade.
3. **Existing Test Suite (`test/unit/cooldown_engine_test.dart`)**:
   - Lines 20-47 (Test R2.1): Cooldown window filtering with 14 days default.
   - Lines 49-75 (Test R2.2): Dishes cooked 15 days ago are eligible.
   - Lines 77-111 (Test R2.3): Back-to-back protein repeating prevention when cooked yesterday.
   - Lines 147-180 (Test R2.5): Back-to-back carbs repeating prevention when cooked yesterday.
   - Lines 182-203 (Test R2.6): Friday Special booster prioritizes festive meals on Fridays (`now.weekday == DateTime.friday`).
   - Lines 204-225 (Test R2.7): Friday Special meals score 20 points lower on Monday than Friday (`scoreOnFriday - scoreOnMonday ≈ 20.0`).
   - Lines 226-245 (Test R2.8): Inter-card diversity ensures top 3 cards feature distinct protein types.
   - Lines 246-267 (Test R2.9): Scoring formula rewards untried dishes (+25.0) and favorites (+5.0).
   - Lines 269-526 (Tests T2.1–T2.8): Boundary cases for empty vault, 1-2 meal vaults, all meals on cooldown, single protein/carbs vaults, extreme 1-day cooldown boundary (`T2.6`), intraday multiple logs (`T2.7`), and leftover history status (`T2.8`).
4. **Reference Implementation (`test/support/reference_engine.dart`)**:
   - Lines 28-46: Context detection finds latest history entry where `_daysBetween(entry.cookedDate, normalizedToday) <= 1`.
   - Lines 49-74: 5-level degradation loop testing candidate count $\ge 3$ (or $|\mathcal{M}| < 3$ or level == 5).
   - Lines 93-131: Candidate filtering logic enforcing `deltaDays <= effectiveCooldown` and protein/carbs repetition checks.
   - Lines 149-193: Scoring calculation function (`calculateMealScore`).
   - Lines 195-251: Inter-card diversity selection with protein uniqueness and carbs fallback.
5. **Drift Schemas & Model Alignment (`lib/core/database/`)**:
   - `lib/core/database/tables/meals_table.dart`: `prepTime` integer column, `proteinType` enum (`chicken`, `beef`, `fish`, `legume`, `dairy`, `none`), `carbsType` enum (`rice`, `pasta`, `bread`, `potato`, `grains`, `none`).
   - `lib/core/database/tables/meal_history_table.dart`: `cookedAt` DateTime column, `entryType` enum (`cooked`, `leftover`).
   - `lib/core/database/app_database.dart`: Contains extension getters `MealX.prepTimeMinutes`, `MealHistoryDataX.cookedDate`, and `typedef AppSetting = AppSettingsData`, enabling direct structural parity between Drift entities and engine models.
6. **Test Execution Status**:
   - `flutter test test/unit/cooldown_engine_test.dart` executed: 17/17 passed (0 failures).
   - `flutter test` across entire project executed: 108/108 passed (0 failures).

---

## 2. Logic Chain

1. **Date Boundary Normalization**:
   - Raw `DateTime.difference().inDays` performs integer division on elapsed milliseconds. If a meal was cooked at 20:00 yesterday and checked at 08:00 today, the raw duration is 12 hours ($0$ days).
   - Truncating timestamps to `DateTime(year, month, day)` before calculating difference ensures calendar day accuracy where yesterday evaluates strictly to $\Delta_{\text{days}} = 1$.
2. **Cooldown Boundary Invariant ($\Delta_{\text{days}} \le C_{\text{eff}}$)**:
   - For $C_{\text{days}} = 1$ (Test T2.6), a 1-day cooldown must exclude yesterday ($\Delta_{\text{days}} = 1$) while allowing dishes cooked 2 days ago ($\Delta_{\text{days}} = 2$).
   - For $C_{\text{days}} = 14$ (Test R2.1 & R2.2), meals cooked 1..14 days ago are excluded, and meals cooked 15 days ago are eligible.
   - The condition $\Delta_{\text{days}} \le C_{\text{eff}}$ strictly satisfies both boundaries.
3. **Recent Meal Context & Tie-Breaking**:
   - To prevent back-to-back repetitions, the context meal must have been cooked within $\le 1$ calendar day.
   - Multiple logs on the same day (Test T2.7) are resolved by sorting descending on `createdAt` so that dinner takes precedence over lunch.
   - Leftovers (Test T2.8) carry the same nutritional protein/carbs context as freshly cooked meals.
4. **Scoring Formula Balance**:
   - Untried meals receive $+25.0$, higher than the $+20.0$ max cap on previously cooked dishes, incentivizing culinary exploration.
   - Friday special delivers $+15.0$ on Friday and $-5.0$ on weekdays, producing the required $+20.0$ point swing (Test R2.7).
   - Favorites provide $+5.0$, Budget friendly $+2.0$, and daily deterministic jitter provides $[0.0, 3.96]$, guaranteeing stable, non-flickering UI on re-renders while introducing daily variety.
5. **Fallback Degradation Invariants**:
   - If available candidates $< \min(3, |\mathcal{M}|)$, the cascade progressively: (1) relaxes carbs, (2) halves cooldown, (3) relaxes protein, (4) allows emergency non-same-day meals, and (5) surfaces all available inventory with localized Arabic explanation.

---

## 3. Caveats

- **No Code Modification in `lib/`**: In accordance with the Explorer archetype's read-only mandate, no source files in `lib/` were created or modified during this investigation. All findings and algorithms have been formalized in `m2_cooldown_math_plan.md` for the implementer agent.
- **Clock Drift Assumption**: The mathematical engine assumes standard device local time. Normalizing timestamps to `DateTime(y, m, d)` protects against daylight savings and standard time transitions within typical daily offsets.

---

## 4. Conclusion

The mathematical formulas, date normalization logic, back-to-back repetition rules, scoring weights, inter-card diversity selection, and 5-level degradation cascade are completely defined, cross-referenced with existing tests, and documented in:
`E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_1\m2_cooldown_math_plan.md`

The implementer agent for Milestone 2 can implement `lib/features/home/domain/cooldown_engine.dart` directly following this specification without algorithmic ambiguity.

---

## 5. Verification Method

To independently verify the mathematical consistency and test compliance:
1. **Run Cooldown Engine Unit Tests**:
   ```bash
   flutter test test/unit/cooldown_engine_test.dart
   ```
   *Expected result: 17 passed tests verifying R2.1–R2.9 and T2.1–T2.8.*
2. **Run Full Project Test Suite**:
   ```bash
   flutter test
   ```
   *Expected result: 108 passed tests across unit, widget, and e2e tiers.*
3. **Inspect the Specification Document**:
   Examine `m2_cooldown_math_plan.md` in this directory to confirm all mathematical equations, pseudocode, and edge-case guarantees.
