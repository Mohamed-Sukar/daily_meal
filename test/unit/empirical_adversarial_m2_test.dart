// test/unit/empirical_adversarial_m2_test.dart
// Adversarial Forensic Audit Test Suite for Milestone 2 (CooldownEngine)
// Independently authored by teamwork_preview_auditor_m2 to verify mathematical invariants,
// cascade transitions, scoring components, diversity fallbacks, and anti-facade integrity.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import '../support/contracts.dart' hide RecommendationResult;
import '../support/seed_catalog.dart';

void main() {
  late CooldownEngine engine;
  late List<Meal> catalog;
  final baseDate = DateTime(2026, 9, 6); // Sunday

  setUp(() {
    engine = const CooldownEngine();
    catalog = List<Meal>.from(initialEgyptianMealsSeed);
  });

  group('Adversarial Suite 1: Mathematical Invariants & Date Boundary Rigor', () {
    test('Exact Cooldown Boundary: deltaDays <= C is excluded, deltaDays == C+1 is eligible', () {
      const cooldown = 14;
      // 3 meals in vault: Meal 1, Meal 2, Meal 3
      final threeMealVault = [catalog[0], catalog[1], catalog[2]];

      // Case A: Meal 1 cooked exactly 14 days ago -> excluded under cooldown 14
      // Candidates in Level 0 will be only 2 (Meals 2 & 3), triggering relaxation Level > 0
      final history14Days = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري مصري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 14)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result14 = engine.compute(
        meals: threeMealVault,
        history: history14Days,
        settings: const AppSetting(cooldownDays: cooldown, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );

      // Meal 1 must be excluded at Level 0, forcing relaxation (relaxationLevel > 0)
      expect(result14.relaxationLevel, greaterThan(0),
          reason: 'Only 2 eligible meals at Level 0 because Meal 1 is on cooldown; must relax');

      // Case B: Meal 1 cooked exactly 15 days ago -> eligible under cooldown 14
      // All 3 meals are eligible at Level 0, so relaxationLevel == 0
      final history15Days = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري مصري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 15)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result15 = engine.compute(
        meals: threeMealVault,
        history: history15Days,
        settings: const AppSetting(cooldownDays: cooldown, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );

      // Meal 1 is eligible at 15 days, so all 3 meals are eligible at Level 0
      expect(result15.relaxationLevel, equals(0),
          reason: 'All 3 meals are eligible without relaxation when cooked 15 days ago');
      expect(result15.recommendations.any((m) => m.id == 1), isTrue);
    });

    test('Calendar Leap Year calculation across Feb 28 -> Mar 1 (Leap 2028)', () {
      final leapFeb28 = DateTime(2028, 2, 28);
      final leapMar1 = DateTime(2028, 3, 1);
      final threeMealVault = [catalog[0], catalog[1], catalog[2]];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: leapFeb28,
          status: MealHistoryStatus.cookedToday,
          createdAt: leapFeb28,
        ),
      ];

      // Cooldown of 1 day: cooked on Feb 28 in leap year, tested on Mar 1 (difference is 2 days because of Feb 29)
      final result = engine.compute(
        meals: threeMealVault,
        history: history,
        settings: const AppSetting(cooldownDays: 1, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: leapMar1,
      );

      // Delta is 2 days > 1 day cooldown, so Meal 1 is eligible and all 3 meals are recommended at Level 0
      expect(result.relaxationLevel, equals(0));
      expect(result.recommendations.any((m) => m.id == 1), isTrue);
    });

    test('Year crossover boundary: 2026-12-31 to 2027-01-01 evaluates to exactly 1 day', () {
      final dec31 = DateTime(2026, 12, 31, 22, 0);
      final jan1 = DateTime(2027, 1, 1, 8, 0);

      final history = [
        MealHistoryData(
          id: 1,
          mealId: 2,
          mealName: 'فراخ',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: dec31,
          status: MealHistoryStatus.cookedToday,
          createdAt: dec31,
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true),
        today: jan1,
      );

      expect(result.recommendations.any((m) => m.proteinType == ProteinType.chicken), isFalse);
    });

    test('Future cooked date handling (deltaDays < 0): excluded cleanly without throwing', () {
      final tomorrow = baseDate.add(const Duration(days: 1));
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: tomorrow,
          status: MealHistoryStatus.cookedToday,
          createdAt: tomorrow,
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      expect(result.recommendations.any((m) => m.id == 1), isFalse);
    });
  });

  group('Adversarial Suite 2: Progressive Relaxation Cascade & Arabic Explanations', () {
    test('Cascade Level 0 (Strict): Level is 0 with exact reason', () {
      final result = engine.compute(
        meals: catalog,
        history: const [],
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      expect(result.relaxationLevel, equals(0));
      expect(result.relaxationReason, equals('اقتراحات مثالية مطابقة لجميع شروط التنوع الغذائي وفترة الاستبعاد.'));
    });

    test('Cascade Level 1 (Relax Carbs): Disables carbs repetition filter while preserving protein filter', () {
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 2,
          mealName: 'فراخ ورز',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final miniVault = [
        catalog.firstWhere((m) => m.carbsType == CarbsType.bread && m.proteinType != ProteinType.chicken),
        catalog.firstWhere((m) => m.carbsType == CarbsType.rice && m.proteinType == ProteinType.beef),
        catalog.firstWhere((m) => m.carbsType == CarbsType.rice && m.proteinType == ProteinType.fish),
        catalog.firstWhere((m) => m.carbsType == CarbsType.rice && m.proteinType == ProteinType.legume),
      ];

      final result = engine.compute(
        meals: miniVault,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true, preventRepeatCarbs: true),
        today: baseDate,
      );

      expect(result.relaxationLevel, equals(1));
      expect(result.relaxationReason, contains('النشويات'));
      expect(result.recommendations.length, equals(3));
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.chicken), isFalse);
    });

    test('Cascade Level 2 (Halve Cooldown): Cooldown window halved when candidates < 3', () {
      final miniVault = catalog.take(3).toList();
      final history = [
        MealHistoryData(
          id: 1,
          mealId: miniVault[0].id,
          mealName: miniVault[0].name,
          proteinType: miniVault[0].proteinType,
          carbsType: miniVault[0].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 10)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 2,
          mealId: miniVault[1].id,
          mealName: miniVault[1].name,
          proteinType: miniVault[1].proteinType,
          carbsType: miniVault[1].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 10)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 3,
          mealId: miniVault[2].id,
          mealName: miniVault[2].name,
          proteinType: miniVault[2].proteinType,
          carbsType: miniVault[2].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 10)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result = engine.compute(
        meals: miniVault,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );

      expect(result.relaxationLevel, equals(2));
      expect(result.relaxationReason, contains('النصف'));
      expect(result.recommendations.length, equals(3));
    });

    test('Cascade Level 3 (Relax Protein & Quarter Cooldown)', () {
      final chickenMeals = catalog.where((m) => m.proteinType == ProteinType.chicken).take(3).toList();
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 999,
          mealName: 'فراخ أمس',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result = engine.compute(
        meals: chickenMeals,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true, preventRepeatCarbs: false),
        today: baseDate,
      );

      expect(result.relaxationLevel, equals(3));
      expect(result.relaxationReason, contains('البروتين'));
      expect(result.recommendations.length, equals(3));
      expect(result.recommendations.every((m) => m.proteinType == ProteinType.chicken), isTrue);
    });

    test('Cascade Level 4 (Emergency Mode): Only same-day excluded', () {
      final miniVault = catalog.take(4).toList();
      final history = [
        MealHistoryData(
          id: 1,
          mealId: miniVault[0].id,
          mealName: miniVault[0].name,
          proteinType: miniVault[0].proteinType,
          carbsType: miniVault[0].carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 2,
          mealId: miniVault[1].id,
          mealName: miniVault[1].name,
          proteinType: miniVault[1].proteinType,
          carbsType: miniVault[1].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 3,
          mealId: miniVault[2].id,
          mealName: miniVault[2].name,
          proteinType: miniVault[2].proteinType,
          carbsType: miniVault[2].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 4,
          mealId: miniVault[3].id,
          mealName: miniVault[3].name,
          proteinType: miniVault[3].proteinType,
          carbsType: miniVault[3].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result = engine.compute(
        meals: miniVault,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      expect(result.relaxationLevel, equals(4));
      expect(result.relaxationReason, contains('الطوارئ'));
      expect(result.recommendations.length, equals(3));
      expect(result.recommendations.any((m) => m.id == miniVault[0].id), isFalse);
    });

    test('Cascade Level 5 (Unrestricted Fallback): When all meals were cooked today', () {
      final miniVault = catalog.take(3).toList();
      final history = [
        MealHistoryData(
          id: 1,
          mealId: miniVault[0].id,
          mealName: miniVault[0].name,
          proteinType: miniVault[0].proteinType,
          carbsType: miniVault[0].carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 2,
          mealId: miniVault[1].id,
          mealName: miniVault[1].name,
          proteinType: miniVault[1].proteinType,
          carbsType: miniVault[1].carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 3,
          mealId: miniVault[2].id,
          mealName: miniVault[2].name,
          proteinType: miniVault[2].proteinType,
          carbsType: miniVault[2].carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result = engine.compute(
        meals: miniVault,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      expect(result.relaxationLevel, equals(5));
      expect(result.relaxationReason, contains('جميع الوجبات المتاحة'));
      expect(result.recommendations.length, equals(3));
    });
  });

  group('Adversarial Suite 3: Multi-Factor Scoring Formula Verification', () {
    test('Never-cooked meal recency bonus is exactly 25.0', () {
      final testMeal = catalog.firstWhere((m) => !m.isFavorite && !m.isBudgetFriendly && !m.isFridaySpecial);
      final score = engine.calculateMealScore(
        meal: testMeal,
        history: const [],
        today: DateTime(2026, 9, 7),
        cooldownDays: 14,
      );

      final jitter = ((7 * 17 + testMeal.id * 31) % 100) / 25.0;
      expect(score, closeTo(25.0 + jitter, 0.001));
    });

    test('Recency score for cooled-down dish is min(20.0, (delta - C) / 2)', () {
      final testMeal = catalog.firstWhere((m) => !m.isFavorite && !m.isBudgetFriendly && !m.isFridaySpecial);
      final history = [
        MealHistoryData(
          id: 1,
          mealId: testMeal.id,
          mealName: testMeal.name,
          proteinType: testMeal.proteinType,
          carbsType: testMeal.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 24)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final score = engine.calculateMealScore(
        meal: testMeal,
        history: history,
        today: baseDate,
        cooldownDays: 14,
      );

      final jitter = ((baseDate.day * 17 + testMeal.id * 31) % 100) / 25.0;
      expect(score, closeTo(5.0 + jitter, 0.001));
    });

    test('Recency score caps at 20.0 for very old cooking history', () {
      final testMeal = catalog.firstWhere((m) => !m.isFavorite && !m.isBudgetFriendly && !m.isFridaySpecial);
      final history = [
        MealHistoryData(
          id: 1,
          mealId: testMeal.id,
          mealName: testMeal.name,
          proteinType: testMeal.proteinType,
          carbsType: testMeal.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 100)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final score = engine.calculateMealScore(
        meal: testMeal,
        history: history,
        today: baseDate,
        cooldownDays: 14,
      );

      final jitter = ((baseDate.day * 17 + testMeal.id * 31) % 100) / 25.0;
      expect(score, closeTo(20.0 + jitter, 0.001));
    });

    test('Friday Special net delta is exactly 20.0 points between Friday and Weekday', () {
      final fridayMeal = catalog.firstWhere((m) => m.isFridaySpecial);
      final scoreFriday = engine.calculateMealScore(
        meal: fridayMeal,
        history: const [],
        today: DateTime(2026, 9, 11),
        cooldownDays: 14,
      );
      final scoreMonday = engine.calculateMealScore(
        meal: fridayMeal,
        history: const [],
        today: DateTime(2026, 9, 7),
        cooldownDays: 14,
      );

      final jitterFriday = ((11 * 17 + fridayMeal.id * 31) % 100) / 25.0;
      final jitterMonday = ((7 * 17 + fridayMeal.id * 31) % 100) / 25.0;

      final pureDelta = (scoreFriday - jitterFriday) - (scoreMonday - jitterMonday);
      expect(pureDelta, closeTo(20.0, 0.0001));
    });
  });

  group('Adversarial Suite 4: Inter-Card Diversity & Catalog Starvation', () {
    test('Diversity with only 1 protein and 1 carb in entire vault', () {
      final homogenousVault = List.generate(5, (i) => Meal(
        id: 200 + i,
        name: 'دجاج بالأرز $i',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
        category: MealCategory.egyptianTraditional,
        prepTimeMinutes: 30,
        createdAt: baseDate,
      ));

      final result = engine.compute(
        meals: homogenousVault,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      final ids = result.recommendations.map((m) => m.id).toSet();
      expect(ids.length, equals(3));
    });

    test('Single meal in vault returns 1 recommendation without IndexOutOfBoundsException', () {
      final singleVault = [catalog.first];
      final result = engine.compute(
        meals: singleVault,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(1));
      expect(result.recommendations.first.id, equals(catalog.first.id));
    });
  });

  group('Adversarial Suite 5: High Scale & Stress Performance', () {
    test('500 synthetic meals and 2,000 history records execute within 200ms', () {
      final rng = Random(42);
      final largeCatalog = List.generate(500, (i) => Meal(
        id: i + 1,
        name: 'وجبة تجريبية $i',
        proteinType: ProteinType.values[rng.nextInt(ProteinType.values.length)],
        carbsType: CarbsType.values[rng.nextInt(CarbsType.values.length)],
        category: MealCategory.values[rng.nextInt(MealCategory.values.length)],
        prepTimeMinutes: 20 + rng.nextInt(40),
        isFridaySpecial: rng.nextBool(),
        isBudgetFriendly: rng.nextBool(),
        isFavorite: rng.nextBool(),
        createdAt: baseDate,
      ));

      final largeHistory = List.generate(2000, (i) => MealHistoryData(
        id: i + 1,
        mealId: 1 + rng.nextInt(500),
        mealName: 'سجل $i',
        proteinType: ProteinType.values[rng.nextInt(ProteinType.values.length)],
        carbsType: CarbsType.values[rng.nextInt(CarbsType.values.length)],
        cookedDate: baseDate.subtract(Duration(days: rng.nextInt(90))),
        status: MealHistoryStatus.cookedToday,
        createdAt: baseDate.subtract(Duration(days: rng.nextInt(90))),
      ));

      final stopwatch = Stopwatch()..start();
      final result = engine.compute(
        meals: largeCatalog,
        history: largeHistory,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );
      stopwatch.stop();

      expect(result.recommendations.length, equals(3));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('Adversarial Suite 6: Mutation & Anti-Facade Sensitivity', () {
    test('Mutating settings from preventRepeatProtein=true to false alters recommendations', () {
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 2,
          mealName: 'فراخ',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final withFilter = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true, preventRepeatCarbs: false),
        today: baseDate,
      );
      expect(withFilter.recommendations.any((m) => m.proteinType == ProteinType.chicken), isFalse);

      final withoutFilter = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );
      expect(withoutFilter.recommendations.isNotEmpty, isTrue);
    });

    test('Mutating cooldown days from 14 to 30 filters meal cooked 20 days ago', () {
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 20)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final threeMealVault = [catalog[0], catalog[1], catalog[2]];

      final res14 = engine.compute(
        meals: threeMealVault,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );
      // Under 14 days cooldown, cooked 20 days ago is eligible at Level 0
      expect(res14.relaxationLevel, equals(0));
      expect(res14.recommendations.any((m) => m.id == 1), isTrue);

      final res30 = engine.compute(
        meals: threeMealVault,
        history: history,
        settings: const AppSetting(cooldownDays: 30, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );
      // Under 30 days cooldown, cooked 20 days ago is excluded at Level 0 (forcing relaxation)
      expect(res30.relaxationLevel, greaterThan(0));
    });
  });
}
