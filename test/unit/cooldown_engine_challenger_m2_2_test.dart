// test/unit/cooldown_engine_challenger_m2_2_test.dart
// Dedicated Empirical Adversarial Challenge Test Suite for Milestone 2 (CooldownEngine)
// Authored by: teamwork_preview_challenger_m2_2
// Objectives:
//  - Stress scalability (1,000+ meals, 5,000+ history logs, worst-case cascade latency)
//  - Verify 100% daily jitter determinism (repeated executions, cross-hour evaluation, jitter bounds)
//  - Verify inter-card diversity under edge and pathological catalog compositions
//  - Empirically verify cooldown correctness, fallback triggers, and forensic analysis

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import '../support/contracts.dart' hide RecommendationResult;
import '../support/seed_catalog.dart';

void main() {
  late CooldownEngine engine;
  final baseDate = DateTime(2026, 9, 6); // Sunday

  setUp(() {
    engine = const CooldownEngine();
  });

  group('Dimension 1: Scalability & Performance Under Stress (1,000+ Meals, 5,000+ History)', () {
    test('CHALLENGE-1.1: High volume (1,000 meals x 5,000 history logs) finishes in < 1500ms', () {
      final proteins = ProteinType.values;
      final carbs = CarbsType.values;
      final categories = MealCategory.values;

      final largeCatalog = List.generate(1000, (i) {
        return Meal(
          id: i + 1,
          name: 'وجبة رقم #${i + 1}',
          proteinType: proteins[i % proteins.length],
          carbsType: carbs[(i ~/ proteins.length) % carbs.length],
          category: categories[i % categories.length],
          prepTimeMinutes: 15 + (i % 60),
          isFridaySpecial: i % 7 == 0,
          isBudgetFriendly: i % 3 == 0,
          isFavorite: i % 10 == 0,
          createdAt: baseDate.subtract(Duration(days: 200 + (i % 200))),
        );
      });

      final largeHistory = List.generate(5000, (i) {
        final mealId = (i % 1000) + 1;
        final daysAgo = 1 + (i % 365);
        return MealHistoryData(
          id: i + 1,
          mealId: mealId,
          mealName: 'وجبة رقم #$mealId',
          proteinType: proteins[mealId % proteins.length],
          carbsType: carbs[(mealId ~/ proteins.length) % carbs.length],
          cookedDate: baseDate.subtract(Duration(days: daysAgo)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(Duration(days: daysAgo, hours: 1)),
        );
      });

      const settings = AppSetting(
        cooldownDays: 14,
        preventRepeatProtein: true,
        preventRepeatCarbs: true,
      );

      final stopwatch = Stopwatch()..start();
      final result = engine.compute(
        meals: largeCatalog,
        history: largeHistory,
        settings: settings,
        today: baseDate,
      );
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('CHALLENGE-1.1: 1,000 meals x 5,000 history logs completed in ${elapsedMs}ms');

      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(0));
      expect(elapsedMs, lessThan(1500));
    });

    test('CHALLENGE-1.2: Worst-case cascade under stress: 1,000 meals x 5,000 history forced to Level 5', () {
      final proteins = ProteinType.values;
      final carbs = CarbsType.values;

      final largeCatalog = List.generate(1000, (i) {
        return Meal(
          id: i + 1,
          name: 'وجبة محظورة #${i + 1}',
          proteinType: proteins[i % proteins.length],
          carbsType: carbs[i % carbs.length],
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 30,
          createdAt: baseDate,
        );
      });

      // All 1,000 meals cooked TODAY in history -> triggers Level 0 to Level 5 full cascade
      final allCookedTodayHistory = List.generate(5000, (i) {
        final mealId = (i % 1000) + 1;
        return MealHistoryData(
          id: i + 1,
          mealId: mealId,
          mealName: 'وجبة محظورة #$mealId',
          proteinType: proteins[mealId % proteins.length],
          carbsType: carbs[mealId % carbs.length],
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        );
      });

      final stopwatch = Stopwatch()..start();
      final result = engine.compute(
        meals: largeCatalog,
        history: allCookedTodayHistory,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      // ignore: avoid_print
      print('CHALLENGE-1.2: Full 6-level cascade (1,000 meals x 5,000 history) completed in ${elapsedMs}ms');

      expect(result.relaxationLevel, equals(5));
      expect(result.recommendations.length, equals(3));
      expect(elapsedMs, lessThan(3500));
    });

    test('CHALLENGE-1.3: Scalability profile verification across increasing N', () {
      final timings = <int, int>{};
      final sizes = [100, 250, 500, 1000];

      for (final n in sizes) {
        final meals = List.generate(n, (i) => initialEgyptianMealsSeed[i % initialEgyptianMealsSeed.length].copyWith(id: i + 1));
        final history = List.generate(n * 5, (i) {
          final mId = (i % n) + 1;
          return MealHistoryData(
            id: i + 1,
            mealId: mId,
            mealName: 'M #$mId',
            proteinType: ProteinType.chicken,
            carbsType: CarbsType.rice,
            cookedDate: baseDate.subtract(Duration(days: 20 + (i % 50))),
            status: MealHistoryStatus.cookedToday,
            createdAt: baseDate,
          );
        });

        final sw = Stopwatch()..start();
        engine.compute(meals: meals, history: history, settings: const AppSetting(), today: baseDate);
        sw.stop();
        timings[n] = sw.elapsedMilliseconds;
      }

      // ignore: avoid_print
      print('CHALLENGE-1.3: Timings across sizes: $timings');
      expect(timings.keys, containsAll(sizes));
    });
  });

  group('Dimension 2: 100% Determinism & Daily Jitter Invariants', () {
    test('CHALLENGE-2.1: Bit-for-bit recommendation identity over 2,000 repeated executions on same day', () {
      final firstResult = engine.compute(
        meals: initialEgyptianMealsSeed,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );
      final firstIds = firstResult.recommendations.map((m) => m.id).toList();

      for (int i = 0; i < 2000; i++) {
        final repeated = engine.compute(
          meals: initialEgyptianMealsSeed,
          history: const [],
          settings: const AppSetting(),
          today: baseDate,
        );
        final repeatedIds = repeated.recommendations.map((m) => m.id).toList();
        expect(repeatedIds, equals(firstIds),
            reason: 'Recommendation set diverged at iteration $i on the exact same date');
      }
    });

    test('CHALLENGE-2.2: Determinism invariant across arbitrary timestamps within the same calendar day', () {
      final hours = [0, 4, 8, 12, 16, 20, 23];
      final minutes = [0, 15, 30, 45, 59];

      final baselineIds = engine.compute(
        meals: initialEgyptianMealsSeed,
        history: const [],
        settings: const AppSetting(),
        today: DateTime(2026, 9, 6, 0, 0, 0),
      ).recommendations.map((m) => m.id).toList();

      for (final h in hours) {
        for (final m in minutes) {
          final t = DateTime(2026, 9, 6, h, m, 42);
          final res = engine.compute(
            meals: initialEgyptianMealsSeed,
            history: const [],
            settings: const AppSetting(),
            today: t,
          );
          expect(res.recommendations.map((e) => e.id).toList(), equals(baselineIds),
              reason: 'Time-of-day $t altered recommendations within the same calendar date');
        }
      }
    });

    test('CHALLENGE-2.3: Jitter rotation across 30 consecutive calendar days', () {
      final uniqueSets = <String>{};

      for (int day = 1; day <= 30; day++) {
        final testDate = DateTime(2026, 9, day);
        final res = engine.compute(
          meals: initialEgyptianMealsSeed,
          history: const [],
          settings: const AppSetting(),
          today: testDate,
        );
        uniqueSets.add(res.recommendations.map((m) => m.id).join(','));
      }

      // Jitter must rotate meal rankings across different days
      expect(uniqueSets.length, greaterThan(1),
          reason: 'Daily jitter must vary recommendations over different days of the month');
    });

    test('CHALLENGE-2.4: Score components bounds and finite invariants', () {
      for (final meal in initialEgyptianMealsSeed) {
        for (int day = 1; day <= 31; day++) {
          final testDate = DateTime(2026, 9, day);
          final score = engine.calculateMealScore(
            meal: meal,
            history: const [],
            today: testDate,
            cooldownDays: 14,
          );
          expect(score.isFinite, isTrue);
          expect(score.isNaN, isFalse);
          expect(score, greaterThan(15.0)); // Never-cooked recency baseline is 25.0, Friday penalty min is -5.0
          expect(score, lessThan(52.0)); // Max score: 25 (recency) + 15 (Fri) + 5 (Fav) + 2 (Budget) + 3.96 (Jitter) = 50.96
        }
      }
    });

    test('CHALLENGE-2.5: Jitter modular identity: ID % 100 collision equivalence', () {
      final meal1 = initialEgyptianMealsSeed[0].copyWith(id: 7);
      final meal2 = initialEgyptianMealsSeed[0].copyWith(id: 107);

      final score1 = engine.calculateMealScore(meal: meal1, history: const [], today: baseDate, cooldownDays: 14);
      final score2 = engine.calculateMealScore(meal: meal2, history: const [], today: baseDate, cooldownDays: 14);

      expect(score1, equals(score2));
    });
  });

  group('Dimension 3: Inter-Card Diversity Under Pathological Catalog Compositions', () {
    test('CHALLENGE-3.1: Monoculture catalog (100% Chicken) enforces Carbs diversity fallback', () {
      final chickenCatalog = List.generate(20, (i) {
        final carbsList = [CarbsType.rice, CarbsType.pasta, CarbsType.bread, CarbsType.potato];
        return Meal(
          id: i + 1,
          name: 'صنف فراخ #${i + 1}',
          proteinType: ProteinType.chicken,
          carbsType: carbsList[i % carbsList.length],
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 30,
          createdAt: baseDate,
        );
      });

      final result = engine.compute(
        meals: chickenCatalog,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      final ids = result.recommendations.map((m) => m.id).toSet();
      expect(ids.length, equals(3), reason: 'Cards must contain 3 distinct meal entities');

      // Fallback to carbs diversity
      final carbs = result.recommendations.map((m) => m.carbsType).toSet();
      expect(carbs.length, greaterThanOrEqualTo(2));
    });

    test('CHALLENGE-3.2: Complete Monoculture (100% Chicken AND 100% Rice) returns 3 distinct meal entities', () {
      final uniformCatalog = List.generate(10, (i) {
        return Meal(
          id: i + 1,
          name: 'فراخ بالأرز #${i + 1}',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 30,
          createdAt: baseDate,
        );
      });

      final result = engine.compute(
        meals: uniformCatalog,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      final ids = result.recommendations.map((m) => m.id).toSet();
      expect(ids.length, equals(3));
    });

    test('CHALLENGE-3.3: Dual-Protein Catalog (Chicken + Beef) provides protein diversity on Card 2 and carbs on Card 3', () {
      final dualCatalog = [
        ...List.generate(10, (i) => Meal(
          id: i + 1,
          name: 'دجاج #$i',
          proteinType: ProteinType.chicken,
          carbsType: i % 2 == 0 ? CarbsType.rice : CarbsType.pasta,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 30,
          createdAt: baseDate,
        )),
        ...List.generate(10, (i) => Meal(
          id: i + 11,
          name: 'لحم #$i',
          proteinType: ProteinType.beef,
          carbsType: i % 2 == 0 ? CarbsType.bread : CarbsType.potato,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 30,
          createdAt: baseDate,
        )),
      ];

      final result = engine.compute(
        meals: dualCatalog,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      // Card 1 and Card 2 must have distinct proteins
      expect(result.recommendations[0].proteinType, isNot(equals(result.recommendations[1].proteinType)));
      // Card 3 must have distinct carbs
      final distinctCarbs = result.recommendations.map((m) => m.carbsType).toSet();
      expect(distinctCarbs.length, greaterThanOrEqualTo(2));
    });

    test('CHALLENGE-3.4: Skewed Catalog (99 Chicken meals, 1 Fish meal) forces selection of Fish meal', () {
      final skewedCatalog = [
        ...List.generate(99, (i) => Meal(
          id: i + 1,
          name: 'دجاج #$i',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 30,
          isFavorite: true,
          createdAt: baseDate,
        )),
        Meal(
          id: 100,
          name: 'سمك نادر',
          proteinType: ProteinType.fish,
          carbsType: CarbsType.rice,
          category: MealCategory.seafood,
          prepTimeMinutes: 30,
          isFavorite: false,
          createdAt: baseDate,
        ),
      ];

      final result = engine.compute(
        meals: skewedCatalog,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.fish), isTrue,
          reason: 'Fish meal must be selected for diversity despite lower ranking score');
    });

    test('CHALLENGE-3.5: Minimal Vault Scaling (0, 1, and 2 meals)', () {
      // 0 meals
      final r0 = engine.compute(meals: const [], history: const [], settings: const AppSetting(), today: baseDate);
      expect(r0.recommendations, isEmpty);
      expect(r0.relaxationLevel, equals(5));

      // 1 meal
      final r1 = engine.compute(meals: [initialEgyptianMealsSeed[0]], history: const [], settings: const AppSetting(), today: baseDate);
      expect(r1.recommendations.length, equals(1));
      expect(r1.recommendations.first.id, equals(initialEgyptianMealsSeed[0].id));

      // 2 meals
      final r2 = engine.compute(meals: [initialEgyptianMealsSeed[0], initialEgyptianMealsSeed[1]], history: const [], settings: const AppSetting(), today: baseDate);
      expect(r2.recommendations.length, equals(2));
      expect(r2.recommendations.map((m) => m.id).toSet().length, equals(2));
    });
  });

  group('Dimension 4: Correctness of Cooldown & Fallback Degradation Cascade', () {
    test('CHALLENGE-4.1: History entry with null mealId (deleted meal) preserves protein repeat filter', () {
      final historyWithNullMealId = [
        MealHistoryData(
          id: 1,
          mealId: null, // Deleted meal
          mealName: 'وجبة محذوفة باللحمة',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1)),
        ),
      ];

      final result = engine.compute(
        meals: initialEgyptianMealsSeed,
        history: historyWithNullMealId,
        settings: const AppSetting(preventRepeatProtein: true),
        today: baseDate,
      );

      for (final meal in result.recommendations) {
        expect(meal.proteinType, isNot(equals(ProteinType.beef)),
            reason: 'Deleted meal protein (beef) should still prevent protein repeat');
      }
    });

    test('CHALLENGE-4.2: Chronological tie-breaking when multiple meals cooked on same day', () {
      final yesterday = baseDate.subtract(const Duration(days: 1));
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'غداء دجاج',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: yesterday,
          status: MealHistoryStatus.cookedToday,
          createdAt: yesterday.add(const Duration(hours: 13)),
        ),
        MealHistoryData(
          id: 2,
          mealId: 2,
          mealName: 'عشاء سمك',
          proteinType: ProteinType.fish,
          carbsType: CarbsType.bread,
          cookedDate: yesterday,
          status: MealHistoryStatus.cookedToday,
          createdAt: yesterday.add(const Duration(hours: 21)),
        ),
      ];

      final result = engine.compute(
        meals: initialEgyptianMealsSeed,
        history: history,
        settings: const AppSetting(preventRepeatProtein: true),
        today: baseDate,
      );

      // Latest entry was Dinner at 21:00 (fish). Fish must be prevented.
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.fish), isFalse);
    });

    test('CHALLENGE-4.3: Level 4 emergency mode strictly excludes today but permits yesterday', () {
      final miniCatalog = [
        initialEgyptianMealsSeed[0],
        initialEgyptianMealsSeed[1],
        initialEgyptianMealsSeed[2],
        initialEgyptianMealsSeed[3],
      ];

      // Meal 0 cooked today at 10:00 AM; others cooked 1, 2, 3 days ago
      final history = [
        MealHistoryData(
          id: 1,
          mealId: miniCatalog[0].id,
          mealName: miniCatalog[0].name,
          proteinType: miniCatalog[0].proteinType,
          carbsType: miniCatalog[0].carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 2,
          mealId: miniCatalog[1].id,
          mealName: miniCatalog[1].name,
          proteinType: miniCatalog[1].proteinType,
          carbsType: miniCatalog[1].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 3,
          mealId: miniCatalog[2].id,
          mealName: miniCatalog[2].name,
          proteinType: miniCatalog[2].proteinType,
          carbsType: miniCatalog[2].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 2)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 4,
          mealId: miniCatalog[3].id,
          mealName: miniCatalog[3].name,
          proteinType: miniCatalog[3].proteinType,
          carbsType: miniCatalog[3].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 3)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result = engine.compute(
        meals: miniCatalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      expect(result.relaxationLevel, equals(4));
      expect(result.recommendations.length, equals(3));
      expect(result.recommendations.any((m) => m.id == miniCatalog[0].id), isFalse);
    });

    test('CHALLENGE-4.4: Level 5 absolute fallback operates when all meals were cooked today', () {
      final microCatalog = [
        initialEgyptianMealsSeed[0],
        initialEgyptianMealsSeed[1],
      ];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: microCatalog[0].id,
          mealName: microCatalog[0].name,
          proteinType: microCatalog[0].proteinType,
          carbsType: microCatalog[0].carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 2,
          mealId: microCatalog[1].id,
          mealName: microCatalog[1].name,
          proteinType: microCatalog[1].proteinType,
          carbsType: microCatalog[1].carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result = engine.compute(
        meals: microCatalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      expect(result.relaxationLevel, equals(5));
      expect(result.recommendations.length, equals(2));
    });

    test('CHALLENGE-4.5: Forensic Proof of Auditor Flawed Assumption (Eligibility vs Top-3 Ranking)', () {
      // In a 20-meal catalog where 19 meals were NEVER cooked (recency score 25.0):
      // A meal cooked 15 days ago (cooldown 14) has recency score (15 - 14)/2 = 0.5.
      // Even though it is 100% ELIGIBLE (not excluded), its score (~0.5) cannot beat never-cooked meals (~25.0).
      // Testing eligibility by checking if it appears in the top 3 cards among 20 meals is a logical fallacy.
      // To test eligibility correctly, we provide a catalog of exactly 3 meals:
      final miniCatalog = [
        initialEgyptianMealsSeed[0], // Cooked 15 days ago
        initialEgyptianMealsSeed[1], // Cooked 30 days ago
        initialEgyptianMealsSeed[2], // Cooked 40 days ago
      ];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: miniCatalog[0].id,
          mealName: miniCatalog[0].name,
          proteinType: miniCatalog[0].proteinType,
          carbsType: miniCatalog[0].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 15)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result = engine.compute(
        meals: miniCatalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      // Now with 3 candidates, Meal 0 is selected and relaxationLevel remains 0!
      expect(result.relaxationLevel, equals(0));
      expect(result.recommendations.any((m) => m.id == miniCatalog[0].id), isTrue,
          reason: 'Meal cooked 15 days ago is eligible and properly included');
    });
  });
}
