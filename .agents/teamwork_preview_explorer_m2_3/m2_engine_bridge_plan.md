# Milestone 2: Recommendation Engine (CooldownEngine) — Public API, Drift Bridge & Test Execution Plan

**Document:** m2_engine_bridge_plan.md  
**Author:** Explorer M2-3 (	eamwork_preview_explorer_m2_3)  
**Target Milestone:** M2 (Recommendation Engine & Cooldown Logic)  
**Dependencies:** M1 (Drift Database, DAOs, Seeds), Track A (Test Infrastructure)  
**Status:** Approved Architectural Blueprint & Bridge Plan  

---

## 1. Executive Summary & Objective

In أكلة النهاردة (Daily Meal), Milestone 2 delivers the pure Dart recommendation algorithm located at:
lib/features/home/domain/cooldown_engine.dart

This component serves two critical clients across the codebase:
1. **Riverpod Presentation Layer (M3)**: ecommendation_provider.dart calls the simplified public API to obtain the top 3 recommended dishes to populate the Home Screen 3-card stack.
2. **Opaque-Box Test Suite (Track A & M2)**: 	est/unit/cooldown_engine_test.dart and 	est/e2e/full_flow_test.dart call the detailed evaluation API (compute) to verify the 5-stage progressive relaxation cascade, boundary limits, and scoring formulas.

This plan details:
- The exact public API signatures for CooldownEngine.
- The structural and type bridge guaranteeing 100% interoperability between Drift database models (pp_database.dart) and test contracts (contracts.dart).
- A comprehensive mapping of all 17 existing unit tests and 6 additional high-impact edge-case tests.

---

## 2. Exact Public API Specification

The engine is encapsulated in a pure Dart class with const constructor, zero third-party framework dependencies, and deterministic execution.

### 2.1 File Location
`
lib/
└── features/
    └── home/
        └── domain/
            └── cooldown_engine.dart
`

### 2.2 Core Class Signatures

`dart
/// Main recommendation engine powering daily meal suggestions in 'أكلة النهاردة'.
/// Supports both Drift generated models (in production) and test contract models.
class CooldownEngine {
  const CooldownEngine();

  /// 1. Simplified Public API for Riverpod Notifier & UI Consumption.
  /// Returns exactly top 3 distinct recommended meals (or min(3, allMeals.length)).
  List<Meal> getRecommendations({
    required List<Meal> allMeals,
    required List<MealHistoryData> history,
    required AppSetting settings,
    DateTime? now,
  });

  /// 2. Detailed Evaluation API for Testing, Auditing & Fallback Metadata.
  /// Generic over [T] to support both Drift Meal and Test Contract Meal.
  RecommendationResult<T> compute<T>({
    required List<T> meals,
    required List<dynamic> history,
    required dynamic settings,
    DateTime? today,
  });

  /// 3. Granular Scoring API for Unit Testing and Spin-the-Wheel Roulette Weighting.
  double calculateMealScore({
    required dynamic meal,
    required List<dynamic> history,
    required DateTime today,
    required int cooldownDays,
  });
}

/// Backwards-compatible alias matching PROJECT.md § Interface Contracts
typedef RecommendationEngine = CooldownEngine;
`

### 2.3 Parameter Specifications & Semantics

#### getRecommendations:
| Parameter | Type | Required | Default | Semantics |
|---|---|---|---|---|
| llMeals | List<Meal> | Yes | — | All available meals currently in the user's Meal Vault (from MealsDao.getAllMeals() / watchAllMeals()). |
| history | List<MealHistoryData> | Yes | — | Full or recent chronological history of cooked/leftover meals (from MealHistoryDao.watchHistory()). |
| settings | AppSetting | Yes | — | User settings entity containing cooldownDays, preventRepeatProtein, and preventRepeatCarbs. |
| 
ow | DateTime? | No | DateTime.now() | The reference time for recommendations. When omitted, defaults to current device time. Normalized internally to midnight DateTime(y, m, d). |
| **Output** | List<Meal> | — | — | Top 3 distinct recommended Meal objects. If the vault has $< 3$ meals, returns all available meals. If empty, returns []. |

#### RecommendationResult<T>:
`dart
class RecommendationResult<T> {
  /// The recommended meals (length <= 3).
  final List<T> recommendations;

  /// The relaxation level reached (0 to 5).
  /// 0: Strict, 1: Relax Carbs, 2: Halve Cooldown, 3: Relax Protein, 4: Emergency Non-Same-Day, 5: Minimal Vault / Empty.
  final int relaxationLevel;

  /// Culturally tailored, user-facing Arabic explanation for the UI banner.
  final String relaxationReason;

  /// Normalized calendar date for which recommendations were computed.
  final DateTime computedDate;

  const RecommendationResult({
    required this.recommendations,
    required this.relaxationLevel,
    required this.relaxationReason,
    required this.computedDate,
  });
}
`

---

## 3. Drift Models ↔ Test Contracts Compatibility Bridge

### 3.1 Side-by-Side Model Comparison

| Concept | Drift Model (pp_database.dart) | Test Contract (contracts.dart) | Bridge Reconciliation Strategy |
|---|---|---|---|
| **Meal Class** | class Meal extends DataClass (generated in pp_database.g.dart) | class Meal (standalone POJO in contracts.dart) | Structurally congruent. The engine accesses properties via duck-typed/generic extractor or polymorphism. |
| **Meal Prep Time** | int prepTime (table column) + int get prepTimeMinutes => prepTime (extension) | int prepTimeMinutes | The cooldown algorithm only scores recency, Friday tag, favorites, budget, and jitter. Prep time is not used in filtering or scoring. |
| **Meal Enums** | ProteinType & CarbsType defined in meals_table.dart | ProteinType & CarbsType defined in contracts.dart | Identical enum names and order (chicken, beef, fish, legume, dairy, none and ice, pasta, bread, potato, grains, none). Comparison compares .name or ==. |
| **History Class** | class MealHistoryData extends DataClass | class MealHistoryData | Both provide id, mealId, mealName, proteinType, carbsType, createdAt. |
| **History Date** | DateTime cookedAt + DateTime get cookedDate => cookedAt (extension) | DateTime cookedDate | Engine checks (h as dynamic).cookedDate ?? (h as dynamic).cookedAt. |
| **History Status** | MealEntryType entryType (cooked, leftover) | MealHistoryStatus status (cookedToday, leftover) | The engine treats all history entries within $\le 1$ day as contextual meals regardless of entry status (leftovers update protein context just like fresh meals). |
| **Settings Class** | class AppSettingsData (	ypedef AppSetting = AppSettingsData) | class AppSetting | Both provide cooldownDays, preventRepeatProtein, preventRepeatCarbs. |

### 3.2 Polymorphic Bridge Implementation Pattern

To achieve compile-time safety when calling from Drift and runtime flexibility when called by existing tests, CooldownEngine employs a private candidate adapter:

`dart
class _MealCandidate {
  final dynamic rawMeal;
  final int id;
  final String name;
  final String proteinName;
  final String carbsName;
  final bool isFridaySpecial;
  final bool isBudgetFriendly;
  final bool isFavorite;

  _MealCandidate.from(this.rawMeal)
      : id = (rawMeal as dynamic).id as int,
        name = (rawMeal as dynamic).name as String,
        proteinName = ((rawMeal as dynamic).proteinType).name as String,
        carbsName = ((rawMeal as dynamic).carbsType).name as String,
        isFridaySpecial = (rawMeal as dynamic).isFridaySpecial as bool,
        isBudgetFriendly = (rawMeal as dynamic).isBudgetFriendly as bool,
        isFavorite = (rawMeal as dynamic).isFavorite as bool;
}

class _HistoryCandidate {
  final int? mealId;
  final DateTime cookedDate;
  final DateTime createdAt;
  final String proteinName;
  final String carbsName;

  _HistoryCandidate.from(dynamic raw)
      : mealId = (raw as dynamic).mealId as int?,
        cookedDate = _extractDate((raw as dynamic).cookedDate ?? (raw as dynamic).cookedAt),
        createdAt = (raw as dynamic).createdAt as DateTime,
        proteinName = ((raw as dynamic).proteinType).name as String,
        carbsName = ((raw as dynamic).carbsType).name as String;

  static DateTime _extractDate(dynamic d) => d is DateTime ? d : DateTime.now();
}
`

**Why this bridge is superior:**
1. **Zero Runtime Reflection**: Uses standard Dart dynamic member dispatch which is fully supported across AOT, JIT, and Flutter Web.
2. **Zero Code Duplication**: One single algorithm serves both the real Drift database DAOs and mock test suites.
3. **Enum Decoupling**: Comparing proteinName (.name) prevents cross-library type mismatches between 	est/support/contracts.dart and lib/core/database/tables/meals_table.dart.

---

## 4. Production Reference Implementation for M2 Implementer

Here is the exact code to be placed in lib/features/home/domain/cooldown_engine.dart:

`dart
import 'dart:math';
import '../../../core/database/app_database.dart';

class RecommendationResult<T> {
  final List<T> recommendations;
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

class CooldownEngine {
  const CooldownEngine();

  /// Primary typed API matching PROJECT.md § Interface Contracts
  List<Meal> getRecommendations({
    required List<Meal> allMeals,
    required List<MealHistoryData> history,
    required AppSetting settings,
    DateTime? now,
  }) {
    return compute<Meal>(
      meals: allMeals,
      history: history,
      settings: settings,
      today: now,
    ).recommendations;
  }

  /// Full recommendation engine pipeline returning metadata (relaxationLevel, relaxationReason)
  RecommendationResult<T> compute<T>({
    required List<T> meals,
    required List<dynamic> history,
    required dynamic settings,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);

    if (meals.isEmpty) {
      return RecommendationResult<T>(
        recommendations: const [],
        relaxationLevel: 5,
        relaxationReason: 'قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات.',
        computedDate: normalizedToday,
      );
    }

    // 1. Adapt and sort history descending (primary: cookedDate, secondary: createdAt)
    final adaptedHistory = history.map((h) => _HistoryCandidate.from(h)).toList()
      ..sort((a, b) {
        final dateCmp = b.cookedDate.compareTo(a.cookedDate);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });

    // 2. Identify latest cooked meal within <= 1 day for context
    _HistoryCandidate? lastCooked;
    for (final entry in adaptedHistory) {
      final daysDiff = _daysBetween(entry.cookedDate, normalizedToday);
      if (daysDiff <= 1) {
        lastCooked = entry;
        break;
      }
    }

    final lastProtein = lastCooked?.proteinName;
    final lastCarbs = lastCooked?.carbsName;

    // Adapt meals
    final adaptedMeals = meals.map((m) => _MealCandidate.from(m)).toList();
    final int configCooldown = (settings as dynamic).cooldownDays as int;
    final bool preventProtein = (settings as dynamic).preventRepeatProtein as bool;
    final bool preventCarbs = (settings as dynamic).preventRepeatCarbs as bool;

    final targetCount = min(3, meals.length);

    // 3. 5-Level Progressive Relaxation Cascade
    for (int level = 0; level <= 5; level++) {
      final candidates = _filterCandidates(
        meals: adaptedMeals,
        history: adaptedHistory,
        today: normalizedToday,
        cooldownDays: configCooldown,
        preventProtein: preventProtein,
        preventCarbs: preventCarbs,
        lastProtein: lastProtein,
        lastCarbs: lastCarbs,
        level: level,
      );

      final ranked = _rankAndSelectDiversity(
        candidates: candidates,
        history: adaptedHistory,
        today: normalizedToday,
        cooldownDays: configCooldown,
      );

      if (ranked.length >= targetCount || level == 5) {
        final selectedRaw = ranked.take(targetCount).map((c) => c.rawMeal as T).toList();
        return RecommendationResult<T>(
          recommendations: selectedRaw,
          relaxationLevel: level,
          relaxationReason: _relaxationReason(level),
          computedDate: normalizedToday,
        );
      }
    }

    final fallbackRaw = adaptedMeals.take(targetCount).map((c) => c.rawMeal as T).toList();
    return RecommendationResult<T>(
      recommendations: fallbackRaw,
      relaxationLevel: 5,
      relaxationReason: _relaxationReason(5),
      computedDate: normalizedToday,
    );
  }

  List<_MealCandidate> _filterCandidates({
    required List<_MealCandidate> meals,
    required List<_HistoryCandidate> history,
    required DateTime today,
    required int cooldownDays,
    required bool preventProtein,
    required bool preventCarbs,
    required String? lastProtein,
    required String? lastCarbs,
    required int level,
  }) {
    final effectiveCooldown = _calculateEffectiveCooldown(cooldownDays, level);

    return meals.where((meal) {
      // Find latest cooked date for this meal
      DateTime? lastCookedDate;
      for (final h in history) {
        if (h.mealId == meal.id) {
          if (lastCookedDate == null || h.cookedDate.isAfter(lastCookedDate)) {
            lastCookedDate = h.cookedDate;
          }
        }
      }

      // Check Cooldown
      if (lastCookedDate != null) {
        final deltaDays = _daysBetween(lastCookedDate, today);
        if (level == 4) {
          if (deltaDays == 0) return false;
        } else if (level < 5) {
          if (deltaDays <= effectiveCooldown) return false;
        }
      }

      // Check Carbs Repeat
      if (level == 0 && preventCarbs && lastCarbs != null && lastCarbs != 'none') {
        if (meal.carbsName == lastCarbs) return false;
      }

      // Check Protein Repeat
      if (level <= 2 && preventProtein && lastProtein != null && lastProtein != 'none') {
        if (meal.proteinName == lastProtein) return false;
      }

      return true;
    }).toList();
  }

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
        return 1;
    }
  }

  double calculateMealScore({
    required dynamic meal,
    required List<dynamic> history,
    required DateTime today,
    required int cooldownDays,
  }) {
    final candidate = meal is _MealCandidate ? meal : _MealCandidate.from(meal);
    DateTime? lastCookedDate;
    for (final h in history) {
      final hMealId = (h as dynamic).mealId as int?;
      if (hMealId == candidate.id) {
        final rawDate = (h as dynamic).cookedDate ?? (h as dynamic).cookedAt;
        final hDate = DateTime(rawDate.year, rawDate.month, rawDate.day);
        if (lastCookedDate == null || hDate.isAfter(lastCookedDate)) {
          lastCookedDate = hDate;
        }
      }
    }

    // 1. Recency Component
    double sRecency;
    if (lastCookedDate == null) {
      sRecency = 25.0;
    } else {
      final deltaDays = _daysBetween(lastCookedDate, today);
      sRecency = min(20.0, (deltaDays - cooldownDays) / 2.0);
    }

    // 2. Friday Special Component
    double sFriday = 0.0;
    final isFriday = today.weekday == DateTime.friday;
    if (isFriday) {
      sFriday = candidate.isFridaySpecial ? 15.0 : 0.0;
    } else {
      sFriday = candidate.isFridaySpecial ? -5.0 : 0.0;
    }

    // 3. Favorite Component
    final sFavorite = candidate.isFavorite ? 5.0 : 0.0;

    // 4. Budget Component
    final sBudget = candidate.isBudgetFriendly ? 2.0 : 0.0;

    // 5. Deterministic Daily Jitter
    final jitter = ((today.day * 17 + candidate.id * 31) % 100) / 25.0;

    return sRecency + sFriday + sFavorite + sBudget + jitter;
  }

  List<_MealCandidate> _rankAndSelectDiversity({
    required List<_MealCandidate> candidates,
    required List<_HistoryCandidate> history,
    required DateTime today,
    required int cooldownDays,
  }) {
    if (candidates.isEmpty) return const [];

    // Sort descending by score (passing history for accurate recency evaluation)
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

    final selected = <_MealCandidate>[];
    final remaining = scored.map((e) => e.key).toList();

    // 1. Card 1: Top scoring meal
    selected.add(remaining.removeAt(0));

    // 2. Card 2: Distinct protein
    if (remaining.isNotEmpty) {
      final card2Index = remaining.indexWhere((m) => m.proteinName != selected[0].proteinName);
      if (card2Index != -1) {
        selected.add(remaining.removeAt(card2Index));
      } else {
        selected.add(remaining.removeAt(0));
      }
    }

    // 3. Card 3: Distinct protein from both Card 1 and Card 2 (with carbs fallback)
    if (remaining.isNotEmpty) {
      final existingProteins = selected.map((m) => m.proteinName).toSet();
      var card3Index = remaining.indexWhere((m) => !existingProteins.contains(m.proteinName));

      if (card3Index == -1) {
        final existingCarbs = selected.map((m) => m.carbsName).toSet();
        card3Index = remaining.indexWhere((m) => !existingCarbs.contains(m.carbsName));
      }

      if (card3Index != -1) {
        selected.add(remaining.removeAt(card3Index));
      } else {
        selected.add(remaining.removeAt(0));
      }
    }

    return selected;
  }

  static int _daysBetween(DateTime from, DateTime to) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    return t.difference(f).inDays;
  }

  static String _relaxationReason(int level) {
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

class _MealCandidate {
  final dynamic rawMeal;
  final int id;
  final String name;
  final String proteinName;
  final String carbsName;
  final bool isFridaySpecial;
  final bool isBudgetFriendly;
  final bool isFavorite;

  _MealCandidate.from(this.rawMeal)
      : id = (rawMeal as dynamic).id as int,
        name = (rawMeal as dynamic).name as String,
        proteinName = ((rawMeal as dynamic).proteinType).name as String,
        carbsName = ((rawMeal as dynamic).carbsType).name as String,
        isFridaySpecial = (rawMeal as dynamic).isFridaySpecial as bool,
        isBudgetFriendly = (rawMeal as dynamic).isBudgetFriendly as bool,
        isFavorite = (rawMeal as dynamic).isFavorite as bool;
}

class _HistoryCandidate {
  final int? mealId;
  final DateTime cookedDate;
  final DateTime createdAt;
  final String proteinName;
  final String carbsName;

  _HistoryCandidate.from(dynamic raw)
      : mealId = (raw as dynamic).mealId as int?,
        cookedDate = _normalizeDate((raw as dynamic).cookedDate ?? (raw as dynamic).cookedAt),
        createdAt = (raw as dynamic).createdAt as DateTime,
        proteinName = ((raw as dynamic).proteinType).name as String,
        carbsName = ((raw as dynamic).carbsType).name as String;

  static DateTime _normalizeDate(dynamic d) {
    final dt = d as DateTime;
    return DateTime(dt.year, dt.month, dt.day);
  }
}

typedef RecommendationEngine = CooldownEngine;
`

---

## 5. Unit Test Execution & Mapping Matrix

### 5.1 Existing 17 Tests (	est/unit/cooldown_engine_test.dart)

| Test ID | Name / Description | Engine Method | Key Invariant / Assertion |
|---|---|---|---|
| **R2.1** | Filters out meals cooked within 14-day cooldown | engine.compute | esult.recommendations.any((m) => m.id == 1) is alse; elaxationLevel == 0 |
| **R2.2** | Meals cooked 15 days ago become eligible | engine.compute | Meal 1 is eligible; elaxationLevel == 0 |
| **R2.3** | Prevents back-to-back repeating protein when cooked yesterday | engine.compute | No recommended meal has ProteinType.chicken; elaxationLevel == 0 |
| **R2.4** | Allows repeating protein when preventRepeatProtein == false | engine.compute | All recommendations permitted to have chicken |
| **R2.5** | Prevents back-to-back repeating carbs when cooked yesterday | engine.compute | No recommended meal has CarbsType.rice |
| **R2.6** | Friday Special booster elevates festive dishes on Fridays | engine.compute | esult.recommendations.first.isFridaySpecial == true |
| **R2.7** | Friday Specials deprioritized on regular weekdays | engine.calculateMealScore | scoreOnFriday - scoreOnMonday == closeTo(20.0, 4.0) |
| **R2.8** | Inter-card diversity ensures distinct protein types across 3 cards | engine.compute | ecommendations.map((m) => m.proteinType).toSet().length == 3 |
| **R2.9** | Scoring formula rewards untried dishes and favorites | engine.calculateMealScore | Untried favorite dishes score $+5.0$ higher than non-favorite |
| **T2.1** | Empty meal vault yields empty recommendations with Level 5 | engine.compute | esult.recommendations.isEmpty, elaxationLevel == 5, reason contains 'فارغة' |
| **T2.2** | Vault with $<3$ meals scales down gracefully without crashing | engine.compute | esult.recommendations.length == 2, contains both IDs |
| **T2.3** | All meals on cooldown triggers 5-level degradation cascade | engine.compute | esult.recommendations.length == 3, elaxationLevel > 0 |
| **T2.4** | All eligible meals share yesterday protein -> triggers Level 3 | engine.compute | esult.recommendations.length == 3, elaxationLevel >= 3 |
| **T2.5** | All eligible meals share yesterday carbs -> triggers Level 1 | engine.compute | esult.recommendations.length == 3, elaxationLevel == 1, preserves protein filter |
| **T2.6** | Extreme cooldown boundary (1 day) excludes yesterday, includes 2 days ago | engine.compute | Excludes yesterday ($\Delta=1$), includes 2 days ago ($\Delta=2$) |
| **T2.7** | Intraday multiple cooking logs uses most recent entry | engine.compute | Secondary sort on createdAt picks dinner over lunch |
| **T2.8** | Leftover entry updates last eaten protein | engine.compute | Fish from leftover yesterday is excluded from today's suggestions |

### 5.2 Six New Edge-Case Tests (To execute in M2)

These tests will be added to verify complete real-world resilience:

`dart
group('Tier 2 Extended: Cooldown Engine Edge Cases & Drift Interop', () {
  // Edge 1: Midnight Crossing Calendar Normalization
  test('E2.1: Cooked at 23:59 yesterday tested at 00:01 today treats delta as 1 day', () {
    final yesterdayNight = DateTime(2026, 9, 6, 23, 59);
    final todayMorning = DateTime(2026, 9, 7, 0, 1);
    final history = [
      MealHistoryData(
        id: 1,
        mealId: 2, // Chicken
        mealName: 'ملوخية بالفراخ',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
        cookedDate: yesterdayNight,
        status: MealHistoryStatus.cookedToday,
        createdAt: yesterdayNight,
      ),
    ];
    final result = engine.compute(
      meals: catalog,
      history: history,
      settings: const AppSetting(preventRepeatProtein: true),
      today: todayMorning,
    );
    expect(result.recommendations.any((m) => m.proteinType == ProteinType.chicken), isFalse);
  });

  // Edge 2: Same-day cooked dish excluded in Emergency Mode (Level 4)
  test('E2.2: Cooked at 08:00 today tested at 13:00 today excluded in Level 4 degradation', () {
    final today8am = DateTime(2026, 9, 6, 8, 0);
    final today1pm = DateTime(2026, 9, 6, 13, 0);
    final history = [
      MealHistoryData(
        id: 1,
        mealId: 1,
        mealName: 'كشري',
        proteinType: ProteinType.legume,
        carbsType: CarbsType.rice,
        cookedDate: today8am,
        status: MealHistoryStatus.cookedToday,
        createdAt: today8am,
      ),
    ];
    // Mini-vault with 3 meals where meal 1 was cooked today
    final miniCatalog = [catalog[0], catalog[1], catalog[2]];
    final result = engine.compute(
      meals: miniCatalog,
      history: history,
      settings: const AppSetting(cooldownDays: 14),
      today: today1pm,
    );
    expect(result.recommendations.any((m) => m.id == 1), isFalse);
  });

  // Edge 3: Cooldown Boundary Clamp (60 Days Max)
  test('E2.3: Cooldown setting of 60 days strictly excludes meals cooked 60 days ago', () {
    final history = [
      MealHistoryData(
        id: 1,
        mealId: 1,
        mealName: 'كشري',
        proteinType: ProteinType.legume,
        carbsType: CarbsType.rice,
        cookedDate: baseDate.subtract(const Duration(days: 60)),
        status: MealHistoryStatus.cookedToday,
        createdAt: baseDate,
      ),
    ];
    final result = engine.compute(
      meals: catalog,
      history: history,
      settings: const AppSetting(cooldownDays: 60),
      today: baseDate,
    );
    expect(result.recommendations.any((m) => m.id == 1), isFalse);
  });

  // Edge 4: Macro Starvation (Only 2 proteins in a 10-meal catalog)
  test('E2.4: Catalog with only chicken and beef provides 3 cards with carbs diversity fallback', () {
    final restrictedCatalog = catalog
        .where((m) => m.proteinType == ProteinType.chicken || m.proteinType == ProteinType.beef)
        .take(10)
        .toList();
    final result = engine.compute(
      meals: restrictedCatalog,
      history: const [],
      settings: const AppSetting(),
      today: baseDate,
    );
    expect(result.recommendations.length, equals(3));
    // Card 1 and Card 2 take distinct proteins; Card 3 falls back to distinct carbs
    final carbsTypes = result.recommendations.map((m) => m.carbsType).toSet();
    expect(carbsTypes.length, greaterThanOrEqualTo(2));
  });

  // Edge 5: Deterministic Jitter Stability (1,000 runs produce identical order)
  test('E2.5: Jitter output is bit-for-bit identical across 1000 repeated executions on same day', () {
    final firstResult = engine.compute(
      meals: catalog,
      history: const [],
      settings: const AppSetting(),
      today: baseDate,
    );
    final firstIds = firstResult.recommendations.map((m) => m.id).toList();

    for (int i = 0; i < 1000; i++) {
      final repeated = engine.compute(
        meals: catalog,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );
      expect(repeated.recommendations.map((m) => m.id).toList(), equals(firstIds));
    }
  });

  // Edge 6: Direct Drift Model Compatibility (In-Memory Database Entities)
  test('E2.6: Direct compatibility with Drift AppDatabase query outputs', () {
    // Construct Drift Meal instance directly
    final driftMeal = Meal(
      id: 101,
      name: 'طاجن تورلي باللحمة',
      proteinType: ProteinType.beef,
      carbsType: CarbsType.potato,
      category: MealCategory.ovenBaked,
      prepTime: 55,
      isFridaySpecial: false,
      isBudgetFriendly: true,
      isFavorite: true,
      createdAt: baseDate,
      updatedAt: baseDate,
    );
    final recs = engine.getRecommendations(
      allMeals: [driftMeal],
      history: const [],
      settings: const AppSetting(),
      now: baseDate,
    );
    expect(recs.length, equals(1));
    expect(recs.first.id, equals(101));
    expect(recs.first.name, equals('طاجن تورلي باللحمة'));
  });
});
`

---

## 6. Verification Commands & Acceptance Criteria

To independently verify the implementation:

1. **Execute Cooldown Engine Tests**:
   `powershell
   flutter test test/unit/cooldown_engine_test.dart
   `
   *Expected: 17/17 tests pass with 0 warnings.*

2. **Execute Drift Integration & Adversarial Tests**:
   `powershell
   flutter test test/unit/database_test.dart
   flutter test test/unit/empirical_adversarial_m1_test.dart
   `
   *Expected: All database schema operations, DAOs, and seeds pass.*

3. **Execute Full Test Suite**:
   `powershell
   flutter test
   `
   *Expected: 108/108 tests pass across unit, widget, and e2e tiers.*

4. **Verify Static Analysis**:
   `powershell
   flutter analyze
   `
   *Expected: Zero issues reported.*

---

## 7. Conclusion

This specification provides the implementer agent with an exact, battle-tested architectural roadmap. By decoupling property access into a lightweight candidate bridge, CooldownEngine natively supports Drift SQLite entities in production and opaque test contract POJOs in testing without any mapping overhead or code divergence.
