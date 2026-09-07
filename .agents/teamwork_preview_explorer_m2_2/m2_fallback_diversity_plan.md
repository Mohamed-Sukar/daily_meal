# Milestone 2 Technical Specification: Progressive Relaxation Cascade & Inter-Card Diversity Filter

**Document Version:** 1.0.0  
**Author:** Milestone 2 Explorer (`teamwork_preview_explorer_m2_2`)  
**Target Milestone:** M2 (Recommendation Engine & Cooldown Logic)  
**Parent Conversation ID:** `3efea0b8-0374-4d39-8f46-d670012fcd8a`  
**Status:** Complete Architectural Specification  

---

## 1. Executive Overview & Problem Formulation

In the Egyptian daily meal app **"أكلة النهاردة"**, the core user promise is answering *"هناكل إيه النهاردة؟"* (What are we eating today?) with fresh, varied, and culturally appropriate recommendations. A naive filtering system that strictly enforces all rules simultaneously (14-day cooldown, no repeating protein, no repeating carbohydrates) will frequently break down under real-world usage scenarios:

1. **Vault Exhaustion:** A user who cooks daily for 14 consecutive days will have placed 14 dishes on cooldown. If their vault contains 15–20 meals, strict filtering leaves fewer than 3 candidates.
2. **Small / Seed Vaults:** A user starting with a customized or curated mini-vault (e.g. 2–5 meals) would experience immediate failure if strict rules were unconditionally applied.
3. **Severe Dietary / Category Overlap:** If a household cooks Chicken and Rice today, and their remaining uncooled vault dishes happen to also feature Rice or Chicken, strict filtering yields 0 recommendations.
4. **Monotony on the Home Screen (3-Card Stack):** Even when plenty of meals survive filtering, if the top 3 highest-scoring dishes happen to all be chicken dishes (e.g. Molokhia with Chicken, Fried Pane Chicken, and Oven-Roasted Chicken), the recommendation screen feels repetitive and uninspiring.

To solve these challenges deterministically, the recommendation engine incorporates two cooperative subsystems:
1. **The 5-Stage Progressive Relaxation Cascade (Levels 0–5):** A deterministic, monotonic fallback hierarchy that gracefully expands the candidate pool until at least 3 candidates are eligible (or the vault limit is reached).
2. **The Inter-Card Diversity Filter:** A greedy, score-guided diversity selection algorithm that guarantees that the top 3 recommendation cards feature distinct protein types whenever possible, with an intelligent secondary fallback to carbohydrate diversity.

---

## 2. Mathematical Formalism & Context Detection

### 2.1 Domain Entities and Notation
Let:
- $\mathcal{M} = \{m_1, m_2, \dots, m_N\}$ be the universe of distinct meals stored in the local SQLite vault (`Meals` table), where $N = |\mathcal{M}|$.
- $\mathcal{H} = [h_1, h_2, \dots, h_K]$ be the chronological cooking history (`MealHistory` table), sorted in descending order of cooking time.
- $S = \langle C_{\text{days}}, F_{\text{protein}}, F_{\text{carbs}} \rangle$ be the user's active configuration (`AppSettings` table), where:
  - $C_{\text{days}} \in [1, 60]$ (default: 14) is the configured cooldown window in days.
  - $F_{\text{protein}} \in \{\text{true}, \text{false}\}$ (default: true) controls repetition prevention for protein.
  - $F_{\text{carbs}} \in \{\text{true}, \text{false}\}$ (default: true) controls repetition prevention for carbohydrates.
- $T_{\text{today}}$ be the normalized calendar date (year, month, day, 00:00:00 UTC/local) representing the recommendation day.
- $K_{\text{target}} = \min(3, N)$ be the dynamic recommendation quota. If $N \ge 3$, $K_{\text{target}} = 3$. If $N < 3$ (e.g., $N = 2$), $K_{\text{target}} = N$.

### 2.2 Date Normalization & Day Difference
All date comparisons in the algorithm operate on calendar day differences rather than raw millisecond durations to avoid timezone drift and daylight-saving shifts:
$$\text{daysBetween}(D_1, D_2) = \text{DateOnly}(D_2).\text{difference}(\text{DateOnly}(D_1)).\text{inDays}$$
Where $\text{DateOnly}(D) = \text{DateTime}(D.\text{year}, D.\text{month}, D.\text{day})$.

### 2.3 Context Detection: Last Cooked Meal ($h_{\text{last}}$)
To evaluate back-to-back protein and carbs repetition, the engine identifies the most recent meal eaten within a 1-day threshold:

1. **Sorting History:**
   The history list $\mathcal{H}$ is sorted by:
   - Primary key: `cookedAt` descending (latest date first).
   - Secondary key: `createdAt` descending (tie-breaker for same-day multiple entries).
   - Tertiary key: `id` descending.

2. **Entry Selection:**
   Search for the first entry $h_{\text{last}} \in \mathcal{H}$ satisfying:
   $$\text{daysBetween}(h_{\text{last}}.\text{cookedAt}, T_{\text{today}}) \le 1$$
   - If $\text{daysBetween} == 0$, a meal was already cooked/eaten earlier today (e.g. lunch or leftover).
   - If $\text{daysBetween} == 1$, the meal was cooked/eaten yesterday.
   - If no entry satisfies $\text{daysBetween} \le 1$ (e.g., the last recorded cooking was 2 or more days ago), then:
     $$\text{lastProtein} = \text{null}, \quad \text{lastCarbs} = \text{null}$$
     In this case, repetition constraints are inactive because yesterday's dinner was not logged or was skipped.

3. **Snapshot Resilience:**
   The context values are extracted directly from the snapshot fields on `MealHistory`:
   $$\text{lastProtein} = h_{\text{last}}.\text{proteinType}, \quad \text{lastCarbs} = h_{\text{last}}.\text{carbsType}$$
   **Crucial Architectural Requirement:** Even if the meal was subsequently deleted from the `Meals` table ($h_{\text{last}}.\text{mealId} == \text{null}$), these snapshot columns retain the historical nutritional profile. This was empirically verified in `test/unit/empirical_adversarial_m1_test.dart` (Line 540).

4. **Leftover Handling:**
   Whether an entry has `entryType == MealEntryType.cooked` or `MealEntryType.leftover`, it represents food consumed by the household on that day. Therefore, eating leftovers yesterday updates $\text{lastProtein}$ and $\text{lastCarbs}$ to prevent eating that same protein/carbs today.

---

## 3. The 5-Stage Progressive Relaxation Cascade (Levels 0 to 5)

### 3.1 The Cascade Invariant & Termination Condition
At each relaxation level $L \in \{0, 1, 2, 3, 4, 5\}$, the engine evaluates candidate pool $\mathcal{C}_L \subseteq \mathcal{M}$.
The cascade terminates at the **lowest** level $L$ where:
$$|\mathcal{C}_L| \ge K_{\text{target}} \quad \lor \quad L == 5$$
Where $K_{\text{target}} = \min(3, |\mathcal{M}|)$.

If $|\mathcal{C}_L| < K_{\text{target}}$, the engine immediately evaluates level $L+1$.

---

### 3.2 Detailed Specifications of Each Relaxation Level

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Level 0: Strict                                                             │
│ • Cooldown: Full C_days (Δ_days <= C_days excluded)                         │
│ • Repeat Protein: Blocked if preventRepeatProtein & lastProtein != null     │
│ • Repeat Carbs: Blocked if preventRepeatCarbs & lastCarbs != null           │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ If candidates < K_target
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Level 1: Relax Carbs                                                        │
│ • Cooldown: Full C_days                                                     │
│ • Repeat Protein: Blocked if preventRepeatProtein & lastProtein != null     │
│ • Repeat Carbs: RELAXED (Allow repeated carbohydrates)                      │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ If candidates < K_target
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Level 2: Halve Cooldown                                                     │
│ • Cooldown: C_eff = min(C_days, max(1, floor(C_days / 2)))                 │
│ • Repeat Protein: Blocked if preventRepeatProtein & lastProtein != null     │
│ • Repeat Carbs: RELAXED                                                     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ If candidates < K_target
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Level 3: Relax Protein & Quarter Cooldown                                   │
│ • Cooldown: C_eff = min(C_days, max(1, floor(C_days / 4)))                 │
│ • Repeat Protein: RELAXED (Allow repeated protein)                          │
│ • Repeat Carbs: RELAXED                                                     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ If candidates < K_target
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Level 4: Emergency Non-Same-Day                                             │
│ • Cooldown: Exclude meals cooked TODAY only (Δ_days == 0)                   │
│ • Repeat Protein: RELAXED                                                   │
│ • Repeat Carbs: RELAXED                                                     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ If candidates < K_target
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Level 5: Minimal Vault / Unrestricted Fallback                              │
│ • Cooldown: NONE (All distinct meals in DB are returned)                    │
│ • If DB is empty (|M| == 0): Return empty list [] with empty state message │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.3 Level-by-Level Algorithmic Rules

#### Level 0: Strict (Ideal Baseline)
- **Cooldown Rule:**
  For each meal $m \in \mathcal{M}$, find its latest cooking date in history $\mathcal{H}$:
  $$\text{lastCooked}(m) = \max(\{h.\text{cookedAt} \mid h \in \mathcal{H}, h.\text{mealId} == m.\text{id}\} \cup \{\varnothing\})$$
  If $\text{lastCooked}(m) \neq \varnothing$:
  $$\Delta_{\text{days}}(m) = \text{daysBetween}(\text{lastCooked}(m), T_{\text{today}})$$
  Exclude $m$ if:
  $$\Delta_{\text{days}}(m) \le C_{\text{days}}$$
  *(Note on boundary: A 14-day cooldown excludes meals cooked 0 to 14 days ago. A meal cooked 15 days ago is eligible).*
- **Protein Repeat Rule:**
  If $F_{\text{protein}} == \text{true} \land \text{lastProtein} \neq \text{null} \land \text{lastProtein} \neq \text{ProteinType.none}$:
  Exclude $m$ if $m.\text{proteinType} == \text{lastProtein}$.
- **Carbs Repeat Rule:**
  If $F_{\text{carbs}} == \text{true} \land \text{lastCarbs} \neq \text{null} \land \text{lastCarbs} \neq \text{CarbsType.none}$:
  Exclude $m$ if $m.\text{carbsType} == \text{lastCarbs}$.
- **Relaxation Metadata:**
  - `relaxationLevel = 0`
  - `relaxationReason = "اقتراحات مثالية مطابقة لجميع شروط التنوع الغذائي وفترة الاستبعاد."`

#### Level 1: Relax Carbohydrates Constraint
- **Trigger:** $|\mathcal{C}_0| < K_{\text{target}}$.
- **Cooldown Rule:** Strict, unchanged ($C_{\text{eff}} = C_{\text{days}}$). Exclude if $\Delta_{\text{days}}(m) \le C_{\text{days}}$.
- **Protein Repeat Rule:** Strict, unchanged. Exclude if $m.\text{proteinType} == \text{lastProtein}$.
- **Carbs Repeat Rule:** **RELAXED (Bypassed).** Meals with $m.\text{carbsType} == \text{lastCarbs}$ are permitted.
- **Rationale:** Rice, bread, and pasta are staples in Egyptian homes. While eating chicken two days in a row causes fatigue, eating rice on consecutive days (e.g. with fish yesterday and Molokhia today) is very common and completely acceptable.
- **Relaxation Metadata:**
  - `relaxationLevel = 1`
  - `relaxationReason = "تم السماح بتكرار صنف النشويات لتوفير اقتراحات كافية."`

#### Level 2: Halve the Cooldown Period
- **Trigger:** $|\mathcal{C}_1| < K_{\text{target}}$.
- **Effective Cooldown Formulation:**
  $$C_{\text{eff}} = \min(C_{\text{days}}, \max(1, \lfloor C_{\text{days}} / 2 \rfloor))$$
  - If $C_{\text{days}} = 14 \implies C_{\text{eff}} = 7$ days.
  - If $C_{\text{days}} = 7 \implies C_{\text{eff}} = 3$ days.
  - If $C_{\text{days}} = 1 \implies C_{\text{eff}} = 1$ day.
  Exclude $m$ if $\Delta_{\text{days}}(m) \le C_{\text{eff}}$.
- **Protein Repeat Rule:** Strict. Exclude if $m.\text{proteinType} == \text{lastProtein}$.
- **Carbs Repeat Rule:** Relaxed (inherited from Level 1).
- **Rationale:** Households with small or moderate vaults (10–14 meals) exhaust a 14-day window rapidly. Reducing the window to 7 days revives meals cooked a week ago while still preventing protein repetition from yesterday.
- **Relaxation Metadata:**
  - `relaxationLevel = 2`
  - `relaxationReason = "تم تقليص فترة الاستبعاد إلى النصف لتوفير اقتراحات كافية."`

#### Level 3: Relax Protein Constraint & Quarter Cooldown
- **Trigger:** $|\mathcal{C}_2| < K_{\text{target}}$.
- **Effective Cooldown Formulation:**
  $$C_{\text{eff}} = \min(C_{\text{days}}, \max(1, \lfloor C_{\text{days}} / 4 \rfloor))$$
  - If $C_{\text{days}} = 14 \implies C_{\text{eff}} = 3$ days.
  - If $C_{\text{days}} = 7 \implies C_{\text{eff}} = 1$ day.
  Exclude $m$ if $\Delta_{\text{days}}(m) \le C_{\text{eff}}$.
- **Protein Repeat Rule:** **RELAXED (Bypassed).** Meals with $m.\text{proteinType} == \text{lastProtein}$ are now permitted.
- **Carbs Repeat Rule:** Relaxed.
- **Rationale:** If a user's vault is heavily skewed towards one protein (e.g. 80% poultry/meat), keeping protein blocked causes complete failure. Relaxing protein while enforcing a minimal 3-day buffer ensures the user does not repeat the exact same dish cooked 1 or 2 days ago.
- **Relaxation Metadata:**
  - `relaxationLevel = 3`
  - `relaxationReason = "تم تخفيف شرط البروتين وفترة الاستبعاد لتوفير اقتراحات متنوعة."`

#### Level 4: Emergency Same-Day Exclusion Only
- **Trigger:** $|\mathcal{C}_3| < K_{\text{target}}$.
- **Cooldown Rule:**
  Exclude $m$ **ONLY** if $\Delta_{\text{days}}(m) == 0$.
  Any meal cooked yesterday ($\Delta_{\text{days}} \ge 1$) or earlier is allowed into candidates.
- **Protein Repeat Rule:** Relaxed.
- **Carbs Repeat Rule:** Relaxed.
- **Rationale:** Absolute minimum boundary for user trust: do not recommend a dish that was already recorded as cooked earlier today. Recommending yesterday's dinner is better than showing an empty screen.
- **Relaxation Metadata:**
  - `relaxationLevel = 4`
  - `relaxationReason = "وضع الطوارئ: استبعاد وجبات اليوم فقط لتوفير اقتراحات."`

#### Level 5: Minimal Vault Handling / Empty State
- **Trigger:** $|\mathcal{C}_4| < K_{\text{target}}$, OR $|\mathcal{M}| == 0$.
- **Candidate Pool:**
  $$\mathcal{C}_5 = \mathcal{M}$$
  (All distinct meals in the vault, with zero exclusions).
- **Sub-cases:**
  1. **Empty Vault ($|\mathcal{M}| == 0$):**
     - Return `recommendations = []`.
     - `relaxationLevel = 5`.
     - `relaxationReason = "قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات."`.
     - Handled gracefully by UI showing empty vault illustration and prompt to seed/add meals.
  2. **Mini-Vault ($1 \le |\mathcal{M}| < 3$):**
     - Return all available meals (e.g. 1 or 2 meals).
     - `relaxationLevel = 5` (or lower if filtered at earlier level).
     - `relaxationReason = "تم عرض جميع الوجبات المتاحة لعدم توفر خيارات أخرى."`.
  3. **Heavily Exhausted Vault ($|\mathcal{M}| \ge 3$ but all cooked today):**
     - Return up to 3 distinct meals from $\mathcal{M}$ sorted by score.
     - `relaxationLevel = 5`.
     - `relaxationReason = "تم عرض جميع الوجبات المتاحة لعدم توفر خيارات أخرى."`.

---

## 4. The Inter-Card Diversity Filter Specification

### 4.1 Objectives & Hierarchy of Diversity
When presenting the top 3 cards on the Home screen ($R_1, R_2, R_3$), users should not see three identical proteins (e.g. 3 chicken dishes) if variety exists in the candidate pool.

The diversity filter follows a strict 3-tier greedy selection priority:
1. **Primary Goal (Protein Diversity):**
   Ensure that $R_1, R_2, R_3$ all have distinct `proteinType` values:
   $$\text{proteinType}(R_1) \neq \text{proteinType}(R_2) \land \text{proteinType}(R_2) \neq \text{proteinType}(R_3) \land \text{proteinType}(R_1) \neq \text{proteinType}(R_3)$$
2. **Secondary Goal (Carbohydrate Diversity Fallback):**
   If fewer than 3 distinct protein types exist in the candidate pool, diversify by `carbsType`:
   $$\text{carbsType}(R_3) \notin \{\text{carbsType}(R_1), \text{carbsType}(R_2)\}$$
3. **Tertiary Fallback (Highest Score):**
   If neither protein nor carbs diversity can be achieved, pick the candidate with the highest remaining score.

---

### 4.2 Scoring Formula & Defect Resolution

#### The Unified Scoring Formula
Each candidate $m \in \mathcal{C}_L$ receives a total score:
$$\text{Score}(m) = S_{\text{recency}}(m, \mathcal{H}) + S_{\text{friday}}(m, T_{\text{today}}) + S_{\text{favorite}}(m) + S_{\text{budget}}(m) + Jitter(m, T_{\text{today}})$$

Where:
- **Recency Component ($S_{\text{recency}}$):**
  - If never cooked ($\text{lastCooked}(m) == \varnothing$): $+25.0$ (discovers new meals).
  - If cooked: $\min\left(20.0, \; \frac{\Delta_{\text{days}}(m) - C_{\text{days}}}{2.0}\right)$.
- **Friday Special Component ($S_{\text{friday}}$):**
  - If $T_{\text{today}}.\text{weekday} == \text{DateTime.friday}$:
    - $m.\text{isFridaySpecial} == \text{true} \implies +15.0$
    - $m.\text{isFridaySpecial} == \text{false} \implies 0.0$
  - If regular weekday:
    - $m.\text{isFridaySpecial} == \text{true} \implies -5.0$
    - $m.\text{isFridaySpecial} == \text{false} \implies 0.0$
- **Favorite Component ($S_{\text{favorite}}$):**
  - $m.\text{isFavorite} == \text{true} \implies +5.0$.
- **Budget Component ($S_{\text{budget}}$):**
  - $m.\text{isBudgetFriendly} == \text{true} \implies +2.0$.
- **Deterministic Daily Jitter ($Jitter$):**
  - $Jitter(m) = \left((T_{\text{today}}.\text{day} \times 17 + m.\text{id} \times 31) \pmod{100}\right) / 25.0 \in [0.0, 4.0)$.

#### Critical Defect Found in `test/support/reference_engine.dart`
During our architectural inspection, we discovered a subtle defect in `test/support/reference_engine.dart` line 208:
```dart
// BUG IN REFERENCE ENGINE:
final scored = candidates.map((m) {
  return MapEntry(
    m,
    calculateMealScore(
      meal: m,
      history: const [], // BUG: Always passed empty history during diversity ranking!
      today: today,
      cooldownDays: cooldownDays,
    ),
  );
}).toList()..sort((a, b) => b.value.compareTo(a.value));
```
**Impact:** Because `history: const []` was passed to `calculateMealScore`, `lastCookedDate` was always null for every meal, meaning all meals received the maximum $+25.0$ recency bonus, completely neutralizing recency differentiation between meals cooked 20 days ago vs meals never cooked!
**Mandatory Fix for Milestone 2 Engine:**
The production recommendation engine in `lib/features/home/domain/cooldown_engine.dart` **MUST** pass `history: sortedHistory` into `calculateMealScore` during diversity ranking!

---

### 4.3 Step-by-Step Selection Algorithm

Given the surviving candidate list $\mathcal{C}_L$, sorted in descending order of $\text{Score}(m)$:
Let $Q = [m_{(1)}, m_{(2)}, \dots, m_{(k)}]$ be the working queue of sorted candidates.
Let $R = []$ be the ordered list of selected cards.

```text
Step 1: If Q is empty, return R (empty).

Step 2 (Select Card 1):
  R1 = Q.removeAt(0)
  R.add(R1)
  If Q is empty, return R.

Step 3 (Select Card 2):
  Find index idx in Q such that:
    Q[idx].proteinType != R[0].proteinType
  If idx != -1:
    R2 = Q.removeAt(idx)
  Else:
    R2 = Q.removeAt(0) // Fallback to highest remaining score
  R.add(R2)
  If Q is empty, return R.

Step 4 (Select Card 3):
  existingProteins = { R[0].proteinType, R[1].proteinType }
  Find index idx in Q such that:
    Q[idx].proteinType NOT IN existingProteins
  
  If idx != -1:
    R3 = Q.removeAt(idx) // 3 distinct proteins achieved!
  Else:
    // Fallback to Carbohydrate Diversity
    existingCarbs = { R[0].carbsType, R[1].carbsType }
    Find index idxCarbs in Q such that:
      Q[idxCarbs].carbsType NOT IN existingCarbs
    
    If idxCarbs != -1:
      R3 = Q.removeAt(idxCarbs) // Distinct carbohydrate achieved!
    Else:
      R3 = Q.removeAt(0) // Fallback to highest remaining score
  
  R.add(R3)
  Return R.
```

---

## 5. Complete Production-Grade Reference Implementation

Below is the complete, self-contained Dart specification for `RecommendationEngine`, ready for direct implementation in `lib/features/home/domain/cooldown_engine.dart`:

```dart
// lib/features/home/domain/cooldown_engine.dart
import 'dart:math';

// Domain enums matching lib/core/database/tables/
import '../../../../core/database/app_database.dart';

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

  /// Computes top recommendations applying progressive relaxation and inter-card diversity.
  RecommendationResult compute({
    required List<Meal> meals,
    required List<MealHistoryData> history,
    required AppSettingsData settings,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);

    // Guard: Empty vault condition
    if (meals.isEmpty) {
      return RecommendationResult(
        recommendations: const [],
        relaxationLevel: 5,
        relaxationReason: _relaxationReason(5, isEmpty: true),
        computedDate: normalizedToday,
      );
    }

    final targetCount = min(3, meals.length);

    // 1. Sort history chronologically descending
    final sortedHistory = List<MealHistoryData>.from(history)
      ..sort((a, b) {
        final dateCmp = b.cookedAt.compareTo(a.cookedAt);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });

    // 2. Identify last cooked meal context (within 1 calendar day)
    MealHistoryData? lastCooked;
    for (final entry in sortedHistory) {
      final daysDiff = _daysBetween(entry.cookedAt, normalizedToday);
      if (daysDiff <= 1) {
        lastCooked = entry;
        break;
      }
    }

    final lastProtein = lastCooked?.proteinType;
    final lastCarbs = lastCooked?.carbsType;

    // 3. Execute 5-Level Progressive Relaxation Cascade (Levels 0 through 5)
    for (int level = 0; level <= 5; level++) {
      final candidates = _filterCandidates(
        meals: meals,
        history: sortedHistory,
        settings: settings,
        today: normalizedToday,
        lastProtein: lastProtein,
        lastCarbs: lastCarbs,
        level: level,
      );

      final ranked = _rankAndSelectDiversity(
        candidates: candidates,
        history: sortedHistory, // Fixed: correctly passed history
        today: normalizedToday,
        cooldownDays: settings.cooldownDays,
      );

      // Termination Condition
      if (ranked.length >= targetCount || level == 5) {
        return RecommendationResult(
          recommendations: ranked.take(targetCount).toList(),
          relaxationLevel: level,
          relaxationReason: _relaxationReason(level, isEmpty: false),
          computedDate: normalizedToday,
        );
      }
    }

    // Safety fallback
    return RecommendationResult(
      recommendations: meals.take(targetCount).toList(),
      relaxationLevel: 5,
      relaxationReason: _relaxationReason(5, isEmpty: false),
      computedDate: normalizedToday,
    );
  }

  /// Filters candidate meals based on the strictness rules of the given relaxation level.
  List<Meal> _filterCandidates({
    required List<Meal> meals,
    required List<MealHistoryData> history,
    required AppSettingsData settings,
    required DateTime today,
    required ProteinType? lastProtein,
    required CarbsType? lastCarbs,
    required int level,
  }) {
    final effectiveCooldown = _calculateEffectiveCooldown(settings.cooldownDays, level);

    return meals.where((meal) {
      // Find the most recent cooking date for this meal
      DateTime? lastCookedDate;
      for (final h in history) {
        if (h.mealId == meal.id) {
          final hDate = DateTime(h.cookedAt.year, h.cookedAt.month, h.cookedAt.day);
          if (lastCookedDate == null || hDate.isAfter(lastCookedDate)) {
            lastCookedDate = hDate;
          }
        }
      }

      // A. Cooldown Exclusion Evaluation
      if (lastCookedDate != null) {
        final deltaDays = _daysBetween(lastCookedDate, today);

        if (level == 4) {
          // Level 4 Emergency Mode: Exclude meals cooked today only
          if (deltaDays == 0) return false;
        } else if (level < 5) {
          // Levels 0..3: Exclude if within effective cooldown window
          if (deltaDays <= effectiveCooldown) return false;
        }
        // Level 5: Cooldown is completely bypassed
      }

      // B. Carbohydrate Repeat Evaluation
      if (level == 0 &&
          settings.preventRepeatCarbs &&
          lastCarbs != null &&
          lastCarbs != CarbsType.none) {
        if (meal.carbsType == lastCarbs) return false;
      }

      // C. Protein Repeat Evaluation
      if (level <= 2 &&
          settings.preventRepeatProtein &&
          lastProtein != null &&
          lastProtein != ProteinType.none) {
        if (meal.proteinType == lastProtein) return false;
      }

      return true;
    }).toList();
  }

  /// Calculates effective cooldown window clamped safely between 1 and configDays.
  int _calculateEffectiveCooldown(int configDays, int level) {
    switch (level) {
      case 0:
      case 1:
        return configDays;
      case 2:
        return min(configDays, max(1, configDays ~/ 2));
      case 3:
        return min(configDays, max(1, configDays ~/ 4));
      case 4:
      case 5:
      default:
        return 0; // Handled specially by deltaDays == 0 check or bypassed
    }
  }

  /// Calculates individual meal ranking score based on recency, Friday, favorite, budget, and jitter.
  double calculateMealScore({
    required Meal meal,
    required List<MealHistoryData> history,
    required DateTime today,
    required int cooldownDays,
  }) {
    DateTime? lastCookedDate;
    for (final h in history) {
      if (h.mealId == meal.id) {
        final hDate = DateTime(h.cookedAt.year, h.cookedAt.month, h.cookedAt.day);
        if (lastCookedDate == null || hDate.isAfter(lastCookedDate)) {
          lastCookedDate = hDate;
        }
      }
    }

    // 1. Recency Component
    double sRecency;
    if (lastCookedDate == null) {
      sRecency = 25.0; // Discover untried meals
    } else {
      final deltaDays = _daysBetween(lastCookedDate, today);
      sRecency = min(20.0, (deltaDays - cooldownDays) / 2.0);
    }

    // 2. Friday Special Component
    double sFriday = 0.0;
    final isFriday = today.weekday == DateTime.friday;
    if (isFriday) {
      sFriday = meal.isFridaySpecial ? 15.0 : 0.0;
    } else {
      sFriday = meal.isFridaySpecial ? -5.0 : 0.0;
    }

    // 3. Favorite Component
    final sFavorite = meal.isFavorite ? 5.0 : 0.0;

    // 4. Budget Component
    final sBudget = meal.isBudgetFriendly ? 2.0 : 0.0;

    // 5. Deterministic Daily Jitter
    final jitter = ((today.day * 17 + meal.id * 31) % 100) / 25.0;

    return sRecency + sFriday + sFavorite + sBudget + jitter;
  }

  /// Greedy selection of top 3 cards ensuring protein and carbohydrate diversity.
  List<Meal> _rankAndSelectDiversity({
    required List<Meal> candidates,
    required List<MealHistoryData> history,
    required DateTime today,
    required int cooldownDays,
  }) {
    if (candidates.isEmpty) return const [];

    // Score candidates and sort descending
    final scored = candidates.map((m) {
      return MapEntry(
        m,
        calculateMealScore(
          meal: m,
          history: history,
          today: today,
          cooldownDays: cooldownDays,
        ),
      );
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selected = <Meal>[];
    final remaining = scored.map((e) => e.key).toList();

    // 1. Select Card 1: Absolute highest scoring candidate
    selected.add(remaining.removeAt(0));

    // 2. Select Card 2: Highest scoring candidate with distinct protein from Card 1
    if (remaining.isNotEmpty) {
      final card2Index = remaining.indexWhere((m) => m.proteinType != selected[0].proteinType);
      if (card2Index != -1) {
        selected.add(remaining.removeAt(card2Index));
      } else {
        selected.add(remaining.removeAt(0));
      }
    }

    // 3. Select Card 3: Distinct protein from Cards 1 & 2 -> Fallback distinct carbs -> Top score
    if (remaining.isNotEmpty) {
      final existingProteins = selected.map((m) => m.proteinType).toSet();
      var card3Index = remaining.indexWhere((m) => !existingProteins.contains(m.proteinType));

      if (card3Index == -1) {
        // Fallback: Carbohydrate diversity
        final existingCarbs = selected.map((m) => m.carbsType).toSet();
        card3Index = remaining.indexWhere((m) => !existingCarbs.contains(m.carbsType));
      }

      if (card3Index != -1) {
        selected.add(remaining.removeAt(card3Index));
      } else {
        selected.add(remaining.removeAt(0));
      }
    }

    return selected;
  }

  int _daysBetween(DateTime from, DateTime to) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    return t.difference(f).inDays;
  }

  String _relaxationReason(int level, {required bool isEmpty}) {
    if (isEmpty) {
      return 'قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات.';
    }
    switch (level) {
      case 0:
        return 'اقتراحات مثالية مطابقة لجميع شروط التنوع الغذائي وفترة الاستبعاد.';
      case 1:
        return 'تم السماح بتكرار صنف النشويات لتوفير اقتراحات كافية.';
      case 2:
        return 'تم تقليص فترة الاستبعاد إلى النصف لتوفير اقتراحات كافية.';
      case 3:
        return 'تم تخفيف شرط البروتين وفترة الاستبعاد لتوفير اقتراحات متنوعة.';
      case 4:
        return 'وضع الطوارئ: استبعاد وجبات اليوم فقط لتوفير اقتراحات.';
      case 5:
      default:
        return 'تم عرض جميع الوجبات المتاحة لعدم توفر خيارات أخرى.';
    }
  }
}
```

---

## 6. Verification Test Matrix & Corner Cases

The table below correlates the algorithm specifications with existing and planned test assertions:

| Test ID | Test Name / Scenario | Expected Level | Expected Outcome & Invalidation Condition |
|---------|----------------------|----------------|-------------------------------------------|
| **V1** | Standard 20-meal catalog, 0 history | Level 0 | 3 distinct protein cards returned. All cards have distinct `proteinType`. |
| **V2** | Meal cooked 3 days ago ($C=14$) | Level 0 | Cooked meal excluded; 3 alternative meals returned with Level 0. |
| **V3** | Yesterday ate Chicken; vault has 4 chicken + 5 other dishes | Level 0 | Chicken completely absent from recommendations. All 3 cards are non-chicken. |
| **V4** | Yesterday ate Bread; all uncooled dishes have Bread, but varying proteins | Level 1 | Level 1 triggered; Bread permitted; Protein repeat prevention preserved. |
| **V5** | 18 of 20 meals cooked in last 14 days | Level 2 | Cooldown halved to 7 days; meals cooked 8–14 days ago become eligible; Level 2 returned. |
| **V6** | Yesterday ate Beef; vault contains ONLY beef meals | Level 3 | Level 3 triggered; beef dishes recommended; Level 3 reason displayed. |
| **V7** | All meals cooked 1, 2, 3, 4 days ago ($C=14$) | Level 4 | Level 4 triggered; meal from yesterday eligible; meals cooked today excluded. |
| **V8** | Vault with exactly 2 meals, 0 history | Level 0 | Returns exactly 2 meals without false degradation (target is $\min(3, 2) = 2$). |
| **V9** | Vault with 0 meals | Level 5 | Returns empty list `[]`; Level 5; Arabic empty message displayed. |
| **V10** | Top 3 scores are Chicken-Rice, Chicken-Pasta, Chicken-Bread; Beef & Fish exist lower | Diversity Check | Top 3 cards are Chicken, Beef, Fish (Diversity re-orders candidates). |
| **V11** | Candidate pool contains ONLY Chicken dishes (varying carbs) | Diversity Fallback | Cards feature distinct carbs (e.g. Rice, Pasta, Bread) via secondary diversity fallback. |
| **V12** | Meal deleted from `Meals` table, but exists in `MealHistory` | Resilience Check | Snapshot preserves `proteinType` and prevents back-to-back repetition. |

---

## 7. Summary of Implementation Instructions for Milestone 2

1. **Target File:** Create `lib/features/home/domain/cooldown_engine.dart` containing `RecommendationEngine` and `RecommendationResult`.
2. **Database Alignment:** Ensure types use `Meal`, `MealHistoryData`, `AppSettingsData` from `AppDatabase`. Notice column `cookedAt` (not `cookedDate`) and `entryType` (not `status`).
3. **Pass Full History to Scoring:** Pass `history: sortedHistory` in `_rankAndSelectDiversity` so recency weighting functions accurately.
4. **Zero State:** Return empty list with `relaxationLevel: 5` and `"قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات."` when `meals.isEmpty`.
5. **No Regressions:** Verify against `test/unit/cooldown_engine_test.dart` and `test/e2e/full_flow_test.dart`.
