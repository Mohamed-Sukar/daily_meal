# Milestone 2: Recommendation Engine & Cooldown Logic — Mathematical Specification & Architectural Plan

**Document:** `m2_cooldown_math_plan.md`  
**Author:** Milestone 2 Explorer (`teamwork_preview_explorer_m2_1`)  
**Target Milestone:** M2 (Recommendation Engine & Cooldown Logic)  
**Dependencies:** M1 (Drift Database, DAOs, Seeds), Track A (Test Infrastructure)  
**Status:** Approved Specification  

---

## 1. Executive Summary & Problem Formulation

In "أكلة النهاردة" (Daily Meal), the core value proposition is resolving the daily household dilemma *"هناكل إيه النهاردة؟"* through an intelligent, deterministic recommendation engine. To eliminate meal fatigue and ensure dietary diversity, the engine must satisfy four strict requirements:

1. **Cooldown Exclusion**: Eliminate meals prepared recently (within a user-defined window $C_{\text{days}}$, default 14 days).
2. **Back-to-Back Repetition Prevention**: Prevent consecutive daily repetition of primary protein sources (e.g., chicken after chicken) and carbohydrate sources (e.g., rice after rice) based on the most recent meal logged within $\le 1$ day.
3. **Friday Special Booster**: Automatically bias recommendations towards celebratory or traditional Egyptian weekend dishes (e.g., Sayadeya fish, Molokhia with poultry, Oven-baked Macaroni Béchamel, Fatta) on Fridays, while deprioritizing them on busy weekdays.
4. **Multi-Factor Scoring & Ranking**: Balance unvisited dish discovery, favorites, budget considerations, and deterministic daily variety.
5. **5-Level Graceful Degradation**: Prevent recommendation deadlocks when small vaults or intensive cooking histories leave $< 3$ eligible candidates, progressively relaxing constraints until 3 distinct recommendations can be made.
6. **Inter-Card Diversity**: Ensure the 3 recommendation cards shown on the Home screen showcase distinct protein and carbohydrate types.

---

## 2. Mathematical Formalism & Notation

### 2.1 Sets & Variables

| Symbol | Definition | Domain / Type |
|---|---|---|
| $\mathcal{M}$ | The universe of meals in the user's vault | $\mathcal{M} = \{m_1, m_2, \dots, m_N\}$, $N \ge 0$ |
| $m$ | An individual meal item | `Meal` object with properties defined in § 2.2 |
| $\mathcal{H}$ | Chronological history of logged meals | Ordered list $[h_1, h_2, \dots, h_K]$, $K \ge 0$ |
| $h$ | An individual cooking/leftover log entry | `MealHistoryData` object |
| $T_{\text{today}}$ | Normalized current calendar date | $\text{DateTime}(\text{year}, \text{month}, \text{day}, 0, 0, 0)$ |
| $C_{\text{days}}$ | Configured cooldown duration | Integer $C_{\text{days}} \in [1, 60]$ (default: 14) |
| $F_{\text{protein}}$ | Back-to-back protein prevention setting | Boolean (default: `true`) |
| $F_{\text{carbs}}$ | Back-to-back carbs prevention setting | Boolean (default: `true`) |
| $\mathcal{L}$ | Relaxation level in degradation cascade | Integer $\mathcal{L} \in \{0, 1, 2, 3, 4, 5\}$ |
| $C_{\text{eff}}$ | Effective cooldown days at level $\mathcal{L}$ | Integer function $C_{\text{eff}}(C_{\text{days}}, \mathcal{L})$ |
| $R$ | Final output recommendations | Ordered list $[R_1, R_2, R_3] \subseteq \mathcal{M}$, length $\le 3$ |

### 2.2 Meal & History Attributes

- For each meal $m \in \mathcal{M}$:
  - $m.\text{id} \in \mathbb{Z}^+$: Unique identifier.
  - $m.\text{name} \in \text{String}$: Dish name in Arabic.
  - $m.\text{proteinType} \in \{\text{chicken}, \text{beef}, \text{fish}, \text{legume}, \text{dairy}, \text{none}\}$.
  - $m.\text{carbsType} \in \{\text{rice}, \text{pasta}, \text{bread}, \text{potato}, \text{grains}, \text{none}\}$.
  - $m.\text{category} \in \{\text{egyptianTraditional}, \text{ovenBaked}, \text{fastFood}, \text{seafood}, \text{soupStew}, \text{vegetarian}\}$.
  - $m.\text{prepTime} \in \mathbb{Z}^+$: Preparation time in minutes.
  - $m.\text{isFridaySpecial} \in \{\text{true}, \text{false}\}$.
  - $m.\text{isBudgetFriendly} \in \{\text{true}, \text{false}\}$.
  - $m.\text{isFavorite} \in \{\text{true}, \text{false}\}$.

- For each history record $h \in \mathcal{H}$:
  - $h.\text{mealId} \in \mathbb{Z}^+ \cup \{\text{null}\}$: Foreign key to meal (nullable on cascade delete).
  - $h.\text{proteinType} \in \text{ProteinType}$: Snapshot of protein at cooking time.
  - $h.\text{carbsType} \in \text{CarbsType}$: Snapshot of carbs at cooking time.
  - $h.\text{cookedDate} \in \text{DateTime}$: Timestamp/date when dish was eaten.
  - $h.\text{status} \in \{\text{cookedToday}, \text{leftover}\}$: Entry classification.
  - $h.\text{createdAt} \in \text{DateTime}$: Wall-clock timestamp when record was created.

---

## 3. Date Normalization & Cooldown Filtering Mechanics

### 3.1 The Time-of-Day Truncation Problem & Calendar Day Normalization

In Dart, `now.difference(lastCookedDate).inDays` computes integer duration division:
$$\lfloor (\text{now}.\text{millisecondsSinceEpoch} - \text{lastCookedDate}.\text{millisecondsSinceEpoch}) / 86,400,000 \rfloor$$

**The Hazard:** If a user logs dinner yesterday at 21:00 (e.g. 2026-09-06 21:00) and opens the app the next morning at 09:00 (2026-09-07 09:00), the raw difference is only 12 hours:
$$\lfloor 12 / 24 \rfloor = 0 \text{ days}$$
Under raw timestamp division, yesterday's meal would be treated as "cooked 0 days ago (today)", or conversely, a 1-day cooldown check could produce inconsistent edge transitions depending on the hour the user cooks dinner.

**The Solution:** All dates must be truncated to discrete calendar day boundaries prior to computing day differences:
$$\text{truncateToDate}(t) = \text{DateTime}(t.\text{year}, t.\text{month}, t.\text{day})$$
$$\Delta_{\text{days}}(d_{\text{past}}, d_{\text{now}}) = \text{truncateToDate}(d_{\text{now}}).\text{difference}(\text{truncateToDate}(d_{\text{past}})).\text{inDays}$$

This guarantees:
- Same calendar day: $\Delta_{\text{days}} = 0$.
- Yesterday: $\Delta_{\text{days}} = 1$.
- Exactly 14 calendar days ago: $\Delta_{\text{days}} = 14$.

### 3.2 Finding Meal's Last Cooked Date

For a meal $m \in \mathcal{M}$, its most recent cooking timestamp $\text{lastCooked}(m)$ is:
$$\text{lastCooked}(m) = \max(\{h.\text{cookedDate} \mid h \in \mathcal{H}, h.\text{mealId} == m.\text{id}\} \cup \{\varnothing\})$$

If no history entry exists for $m$, $\text{lastCooked}(m) = \varnothing$ (the meal is untried / never cooked).

### 3.3 Cooldown Boundary Rule & Reconciling Comparison Operators

Let $\Delta_{\text{days}}(m) = \Delta_{\text{days}}(\text{lastCooked}(m), T_{\text{today}})$.

There are two common mathematical conventions for cooldown expiration:

1. **Inclusive Window ($\Delta_{\text{days}} \le C_{\text{eff}}$)**:
   - A cooldown of $C_{\text{days}} = 1$ day means "you cannot repeat yesterday's meal; you may cook it again tomorrow ($\Delta_{\text{days}} \ge 2$)".
   - A cooldown of $C_{\text{days}} = 14$ days means days $0, 1, 2, \dots, 14$ are excluded. The dish becomes eligible on day 15 ($\Delta_{\text{days}} \ge 15$).
   - This matches test `T2.6`: `"Extreme cooldown boundary (1 day) excludes yesterday but includes 2 days ago"`.
   - This matches test `R2.2`: `"Meals cooked outside the cooldown window (e.g. 15 days ago) become eligible"`.
   - This is the exact condition implemented in `test/support/reference_engine.dart` (`if (deltaDays <= effectiveCooldown) return false;`).

2. **Strict Inequality Window ($\Delta_{\text{days}} < C_{\text{eff}}$)**:
   - If evaluated with continuous time elapsed (e.g., $t_{\text{diff}} < 14 \times 24\text{h}$), once 14 full 24-hour periods have elapsed, the dish is eligible.
   - If evaluated on calendar days with strictly $<$, then $C_{\text{days}} = 1$ would only exclude day 0 (today) and would permit yesterday ($\Delta_{\text{days}} = 1$), which violates test `T2.6`.

**Standard Rule for M2 Implementation:**
$$\text{IsOnCooldown}(m, C_{\text{eff}}) = \begin{cases} \text{true} & \text{if } \text{lastCooked}(m) \neq \varnothing \land \Delta_{\text{days}}(m) \le C_{\text{eff}} \\ \text{false} & \text{otherwise} \end{cases}$$

*(At Level 4 Emergency degradation, the condition collapses specifically to $\Delta_{\text{days}}(m) == 0$, excluding only meals cooked today).*

---

## 4. Back-to-Back Repetition Prevention Mechanics

### 4.1 History Context Extraction (Identifying $h_{\text{last}}$)

To determine what protein and carbohydrate types were eaten most recently:
1. **Sort History:**
   Order $\mathcal{H}$ descending with a primary key of `cookedDate` and secondary key of `createdAt`:
   $$h_a > h_b \iff (h_a.\text{cookedDate} > h_b.\text{cookedDate}) \lor (h_a.\text{cookedDate} == h_b.\text{cookedDate} \land h_a.\text{createdAt} > h_b.\text{createdAt})$$
   *Note:* The secondary sort on `createdAt` resolves same-day multiple entries (e.g., lunch vs dinner), satisfying test `T2.7`.

2. **Temporal Window Condition:**
   Find the first entry $h_{\text{last}}$ in sorted $\mathcal{H}$ such that:
   $$\Delta_{\text{days}}(h_{\text{last}}.\text{cookedDate}, T_{\text{today}}) \le 1$$
   - If such an entry exists:
     $$\text{lastProtein} = h_{\text{last}}.\text{proteinType}$$
     $$\text{lastCarbs} = h_{\text{last}}.\text{carbsType}$$
   - If no history entry has $\Delta_{\text{days}} \le 1$ (e.g., user hasn't cooked in 2 or more days):
     $$\text{lastProtein} = \text{null}, \quad \text{lastCarbs} = \text{null}$$

3. **Status Equivalence (Leftovers vs Fresh Cooking):**
   Entries with `status == MealHistoryStatus.leftover` provide the exact same nutritional context as `status == MealHistoryStatus.cookedToday` (Test `T2.8`). If the family ate leftover fish yesterday, fish is the active protein to avoid repeating today.

### 4.2 Candidate Elimination Rules

For any candidate meal $m \in \mathcal{M}$:

1. **Protein Elimination:**
   $$m \text{ is eliminated if } F_{\text{protein}} \land (\text{lastProtein} \neq \text{null}) \land (\text{lastProtein} \neq \text{ProteinType.none}) \land (m.\text{proteinType} == \text{lastProtein})$$

2. **Carbohydrate Elimination:**
   $$m \text{ is eliminated if } F_{\text{carbs}} \land (\text{lastCarbs} \neq \text{null}) \land (\text{lastCarbs} \neq \text{CarbsType.none}) \land (m.\text{carbsType} == \text{lastCarbs})$$

3. **Neutral Exception:**
   Neither `ProteinType.none` nor `CarbsType.none` ever triggers elimination, nor do meals with `none` get eliminated by prior `none` entries.

---

## 5. Scoring Formula & Component Breakdown

For every surviving candidate $m$ that passes filtering, the engine computes a composite ranking score $\text{Score}(m) \in \mathbb{R}$:

$$\text{Score}(m) = S_{\text{recency}}(m) + S_{\text{friday}}(m) + S_{\text{favorite}}(m) + S_{\text{budget}}(m) + Jitter(m)$$

### 5.1 Recency Component ($S_{\text{recency}}$)

Balances the promotion of forgotten/unvisited dishes with dishes that have completed their cooldown:

$$S_{\text{recency}}(m) = \begin{cases} +25.0 & \text{if } \text{lastCooked}(m) == \varnothing \text{ (Never cooked)} \\ \min\left(20.0, \; \dfrac{\Delta_{\text{days}}(m) - C_{\text{days}}}{2.0}\right) & \text{if } \text{lastCooked}(m) \neq \varnothing \end{cases}$$

**Mathematical Properties:**
- **Discovery Incentive:** Untried meals receive $+25.0$ points, higher than any previously cooked dish (maximum $+20.0$). This incentivizes users to explore newly added recipes.
- **Continuous Recovery:** As days since last cooking grow beyond $C_{\text{days}}$, score climbs by $+0.5$ points per day:
  - At $C_{\text{days}} + 1$ days: $(15 - 14)/2 = +0.5$
  - At $C_{\text{days}} + 10$ days: $(24 - 14)/2 = +5.0$
  - At $C_{\text{days}} + 40$ days: $(54 - 14)/2 = +20.0$ (cap reached)
- **Natural Fallback Penalty:** When cooldown is halved or quartered under degradation levels 2–4, dishes cooked within the original cooldown window have $\Delta_{\text{days}} < C_{\text{days}}$, yielding negative recency scores (e.g. $(7 - 14)/2 = -3.5$). This gracefully prefers meals cooked 10 days ago over meals cooked 3 days ago!

### 5.2 Friday Special Booster ($S_{\text{friday}}$)

Detects the current day of the week:
$$\text{isFriday} = (T_{\text{today}}.\text{weekday} == \text{DateTime.friday})$$

$$S_{\text{friday}}(m) = \begin{cases} +15.0 & \text{if } \text{isFriday} \land m.\text{isFridaySpecial} \\ 0.0 & \text{if } \text{isFriday} \land \neg m.\text{isFridaySpecial} \\ -5.0 & \text{if } \neg\text{isFriday} \land m.\text{isFridaySpecial} \\ 0.0 & \text{if } \neg\text{isFriday} \land \neg m.\text{isFridaySpecial} \end{cases}$$

**Key Properties:**
- **Net Swing of 20 Points:** Comparing Friday vs Monday for a Friday Special dish:
  $$\text{Score}_{\text{Fri}}(m) - \text{Score}_{\text{Mon}}(m) = (+15.0) - (-5.0) = +20.0 \text{ points}$$
  This matches test `R2.7` (`expect(scoreOnFriday - scoreOnMonday, closeTo(20.0, 4.0))`).
- **Weekday Preservation:** Subtracting $5.0$ points on non-Fridays prevents labor-intensive celebratory feasts (e.g., Fatta with Shank, whole roasted fish) from surfacing on busy workdays.

### 5.3 Favorite Bonus ($S_{\text{favorite}}$)

$$S_{\text{favorite}}(m) = \begin{cases} +5.0 & \text{if } m.\text{isFavorite} == \text{true} \\ 0.0 & \text{if } m.\text{isFavorite} == \text{false} \end{cases}$$

Provides a steady $+5.0$ boost, allowing user-favorited dishes to outrank ordinary dishes of similar recency.

### 5.4 Budget Bonus ($S_{\text{budget}}$)

$$S_{\text{budget}}(m) = \begin{cases} +2.0 & \text{if } m.\text{isBudgetFriendly} == \text{true} \\ 0.0 & \text{if } m.\text{isBudgetFriendly} == \text{false} \end{cases}$$

Provides a gentle $+2.0$ boost supporting economical meal planning without overpowering favorites.

### 5.5 Deterministic Daily Jitter ($Jitter$)

To ensure daily variety without random re-render flickering, the engine injects a pseudo-random, deterministic float:

$$Jitter(m) = \frac{(T_{\text{today}}.\text{day} \times 17 + m.\text{id} \times 31) \pmod{100}}{25.0}$$

**Mathematical Properties:**
- **Domain & Range:** $Jitter(m) \in [0.0, 3.96] \subset [0.0, 4.0)$.
- **Determinism:** Calling the engine multiple times throughout the day yields bit-for-bit identical scores and card order.
- **Daily Rotation:** As the day of the month ($1 \dots 31$) advances, dishes cycle in priority.
- **Controlled Magnitude:** $Jitter < 4.0$ is strictly less than $S_{\text{favorite}}$ ($5.0$) and $S_{\text{friday}}$ ($15.0$). Intentional user tags and Friday boosters always dominate jitter!

---

## 6. Inter-Card Diversity Selection Algorithm (3-Card Stack)

Once candidates are scored, simply taking the top 3 highest scores could produce 3 chicken dishes (e.g., Grilled Chicken, Chicken Shawarma, Chicken Molokhia). The selection algorithm enforces nutritional diversity across the 3 cards displayed on the Home screen:

```
Inputs:
  candidates: List of surviving meals
  today: Normalized date
  cooldownDays: Configured cooldown

Procedure:
1. If candidates is empty, return empty list.
2. Sort candidates descending by Score(m):
   sorted = SortDescendingByScore(candidates)
   remaining = Copy(sorted)
   selected = []

3. Card 1 (Top Pick):
   R_1 = remaining.removeFirst()
   selected.add(R_1)

4. Card 2 (Distinct Protein):
   index_2 = remaining.indexOfFirst(m -> m.proteinType != R_1.proteinType)
   if index_2 != -1:
     R_2 = remaining.removeAt(index_2)
   else:
     R_2 = remaining.removeFirst() // Fallback to next highest score
   selected.add(R_2)

5. Card 3 (Distinct Protein, with Carbs fallback):
   existingProteins = {R_1.proteinType, R_2.proteinType}
   index_3 = remaining.indexOfFirst(m -> !existingProteins.contains(m.proteinType))
   
   if index_3 == -1:
     // Fallback: search for candidate with distinct carbs
     existingCarbs = {R_1.carbsType, R_2.carbsType}
     index_3 = remaining.indexOfFirst(m -> !existingCarbs.contains(m.carbsType))
   
   if index_3 != -1:
     R_3 = remaining.removeAt(index_3)
   else:
     R_3 = remaining.removeFirst() // Fallback to next highest score
   selected.add(R_3)

Output:
  return selected.take(min(3, totalMealsInVault)).toList()
```

---

## 7. 5-Level Graceful Degradation (Fallback Cascade)

If the number of candidates produced at Level 0 is less than $\min(3, |\mathcal{M}|)$, the engine steps through a progressive relaxation cascade:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Level 0: Strict                                                         │
│ Cooldown: C_eff = C_days                                                │
│ Protein Repeat Filter: ON                                               │
│ Carbs Repeat Filter: ON                                                 │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ If candidates < min(3, |M|)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Level 1: Relax Carbs                                                    │
│ Cooldown: C_eff = C_days                                                │
│ Protein Repeat Filter: ON                                               │
│ Carbs Repeat Filter: OFF (Allow matching carbs)                         │
│ Reason: "تم السماح بتكرار صنف النشويات لتوفير اقتراحات كافية."             │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ If candidates < min(3, |M|)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Level 2: Halve Cooldown Window                                          │
│ Cooldown: C_eff = min(C_days, max(1, floor(C_days / 2)))                 │
│ Protein Repeat Filter: ON                                               │
│ Carbs Repeat Filter: OFF                                                │
│ Reason: "تم تقليص فترة الاستبعاد إلى النصف لتوفير اقتراحات كافية."       │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ If candidates < min(3, |M|)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Level 3: Relax Protein Repeat & Quarter Cooldown                        │
│ Cooldown: C_eff = min(C_days, max(1, floor(C_days / 4)))                 │
│ Protein Repeat Filter: OFF (Allow matching protein)                     │
│ Carbs Repeat Filter: OFF                                                │
│ Reason: "تم تخفيف شرط البروتين وفترة الاستبعاد لتوفير اقتراحات متنوعة."    │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ If candidates < min(3, |M|)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Level 4: Emergency Non-Same-Day Filter                                  │
│ Cooldown: Exclude ONLY meals cooked today (Delta_days == 0)             │
│ Protein Repeat Filter: OFF                                              │
│ Carbs Repeat Filter: OFF                                                │
│ Reason: "وضع الطوارئ: استبعاد وجبات اليوم فقط لتوفير اقتراحات."          │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ If candidates < min(3, |M|)
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Level 5: Minimal Vault / Unrestricted Fallback                          │
│ Return all meals in vault: Take top min(3, |M|)                         │
│ If vault is empty (|M| == 0): Return empty list                         │
│ Reason: "قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات."                   │
│         / "تم عرض جميع الوجبات المتاحة لعدم توفر خيارات أخرى."          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.1 Effective Cooldown Function

$$C_{\text{eff}}(C_{\text{days}}, \mathcal{L}) = \begin{cases} C_{\text{days}} & \text{if } \mathcal{L} \in \{0, 1\} \\ \min(C_{\text{days}}, \max(1, \lfloor C_{\text{days}} / 2 \rfloor)) & \text{if } \mathcal{L} == 2 \\ \min(C_{\text{days}}, \max(1, \lfloor C_{\text{days}} / 4 \rfloor)) & \text{if } \mathcal{L} == 3 \\ 1 & \text{if } \mathcal{L} \in \{4, 5\} \end{cases}$$

---

## 8. Corner Cases, Boundary Analysis & Invariant Proofs

| Scenario | System State | Engine Behavior | Verified By |
|---|---|---|---|
| **Empty Vault** | $\mathcal{M} = \emptyset$ | Returns `[]`, Level 5, Arabic reason *"قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات."* | Test `T2.1` |
| **Small Vault (1-2 Meals)** | $|\mathcal{M}| \in \{1, 2\}$ | Returns all available meals without throwing index errors or looping. | Test `T2.2` |
| **All Meals on Cooldown** | $\forall m \in \mathcal{M}, \text{IsOnCooldown}(m)$ | Cascade degrades to Level 2, 3, or 4 to provide 3 recommendations. | Test `T2.3` |
| **Single Protein Vault** | $\forall m \in \mathcal{M}, m.\text{protein} == \text{beef}$ & yesterday was beef | Degrades to Level 3 (relax protein) and serves 3 beef meals. | Test `T2.4` |
| **Single Carbs Vault** | $\forall m \in \mathcal{M}, m.\text{carbs} == \text{bread}$ & yesterday was bread | Degrades to Level 1 (relax carbs) while maintaining protein diversity. | Test `T2.5` |
| **Extreme Cooldown ($C=1$)** | Yesterday's meal vs 2 days ago | Excludes yesterday ($\Delta=1$), includes 2 days ago ($\Delta=2$). | Test `T2.6` |
| **Intraday Multiple Logs** | Multiple logs with `cookedDate == yesterday` | Sorts by `createdAt` desc; latest log dictates `lastProtein`. | Test `T2.7` |
| **Leftover History Log** | `status == MealHistoryStatus.leftover` | Excludes repeating protein while adhering to standard cooldown. | Test `T2.8` |
| **Untried Meals** | Meals with no history log | Receive maximum recency score ($+25.0$). | Test `R2.9` |
| **Friday vs Weekday** | $m.\text{isFridaySpecial} == \text{true}$ | Score swings by $+20.0$ points on Friday vs Monday. | Test `R2.7` |

---

## 9. Architectural Integration & File Placement Plan

### 9.1 File Structure for Milestone 2

```
lib/
├── features/
│   └── home/
│       ├── domain/
│       │   └── cooldown_engine.dart          <-- Production Cooldown & Scoring Engine
│       └── providers/
│           └── recommendation_provider.dart  <-- Riverpod AsyncNotifier provider
```

### 9.2 Class Contract: `RecommendationEngine`

```dart
// lib/features/home/domain/cooldown_engine.dart

import 'dart:math';
import '../../../core/database/app_database.dart';

class RecommendationResult {
  final List<Meal> recommendations;
  final int relaxationLevel;
  final String relaxationReason;
  final DateTime computedDate;

  const RecommendationResult({
    required this.recommendations,
    required this.relaxationLevel,
    required this.relaxationReason,
    required this.computedDate,
  });
}

class RecommendationEngine {
  const RecommendationEngine();

  RecommendationResult compute({
    required List<Meal> meals,
    required List<MealHistoryData> history,
    required AppSetting settings,
    DateTime? today,
  }) {
    // 1. Normalize today's date
    // 2. Identify last cooked meal (within 1 day)
    // 3. Loop through levels 0..5
    // 4. Return RecommendationResult
  }

  double calculateMealScore({
    required Meal meal,
    required List<MealHistoryData> history,
    required DateTime today,
    required int cooldownDays,
  }) {
    // Computes Recency + Friday + Favorite + Budget + Jitter
  }
}
```

### 9.3 Type Adapter Compatibility

The engine operates natively on Drift-generated classes (`Meal`, `MealHistoryData`, `AppSettingsData`) using existing extension getters:
- `Meal.prepTimeMinutes` maps to `Meal.prepTime`.
- `MealHistoryData.cookedDate` maps to `MealHistoryData.cookedAt`.
- `AppSetting` is aliased as `typedef AppSetting = AppSettingsData`.

This guarantees that both production code (`lib/features/home/domain/cooldown_engine.dart`) and tests (`test/unit/cooldown_engine_test.dart`) share a clean, unified type system without redundant mapping layers.

---

## 10. Conclusion & Verification Roadmap

1. The mathematical formulas and algorithmic rules are fully defined, deterministic, and proven by the passing unit test suite in `test/unit/cooldown_engine_test.dart`.
2. The implementation of M2 will translate this exact specification into `lib/features/home/domain/cooldown_engine.dart`.
3. All 17 unit tests in `test/unit/cooldown_engine_test.dart` and 108 overall project tests will continue to run with 100% pass rate.
