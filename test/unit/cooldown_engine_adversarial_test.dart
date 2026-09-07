// test/unit/cooldown_engine_adversarial_test.dart
// Empirical Adversarial Stress Test Suite for CooldownEngine (Milestone 2)

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/features/home/domain/cooldown_engine.dart';
import '../support/contracts.dart' hide RecommendationResult;
import '../support/seed_catalog.dart';

void main() {
  late CooldownEngine engine;
  late List<Meal> catalog;

  setUp(() {
    engine = const CooldownEngine();
    catalog = List<Meal>.from(initialEgyptianMealsSeed);
  });

  group('Group 1: Midnight & Calendar Boundaries (23:59 vs 00:01)', () {
    test('1.1: Cooked at 23:59 on Day D, evaluated at 00:01 on Day D+1 (exactly 2 mins apart)', () {
      final cookedTime = DateTime(2026, 9, 6, 23, 59);
      final evalTime = DateTime(2026, 9, 7, 0, 1);

      final history = [
        MealHistoryData(
          id: 1,
          mealId: 2, // Chicken
          mealName: 'ملوخية بالفراخ',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: cookedTime,
          status: MealHistoryStatus.cookedToday,
          createdAt: cookedTime,
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true),
        today: evalTime,
      );

      // Even though only 2 minutes passed, calendar days difference is 1 day.
      // Therefore, chicken was eaten "yesterday" (within <= 1 calendar day)
      // and must be blocked by preventRepeatProtein!
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.chicken), isFalse,
          reason: 'Chicken cooked yesterday at 23:59 must be excluded when evaluated today at 00:01');
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(0));
    });

    test('1.2: Cooked at 00:01 on Day D, evaluated at 23:59 on Day D (23h 58m apart, same day)', () {
      final cookedTime = DateTime(2026, 9, 6, 0, 1);
      final evalTime = DateTime(2026, 9, 6, 23, 59);

      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري مصري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: cookedTime,
          status: MealHistoryStatus.cookedToday,
          createdAt: cookedTime,
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: evalTime,
      );

      // Same calendar day: deltaDays is 0. Meal 1 must be excluded by cooldown.
      expect(result.recommendations.any((m) => m.id == 1), isFalse);
    });

    test('1.3: Year-end midnight boundary (Dec 31, 23:59 to Jan 1, 00:01)', () {
      final cookedTime = DateTime(2026, 12, 31, 23, 59);
      final evalTime = DateTime(2027, 1, 1, 0, 1);

      final history = [
        MealHistoryData(
          id: 1,
          mealId: 3, // Beef
          mealName: 'حواوشي بلدي',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.bread,
          cookedDate: cookedTime,
          status: MealHistoryStatus.cookedToday,
          createdAt: cookedTime,
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true),
        today: evalTime,
      );

      // Dec 31 to Jan 1 is 1 calendar day
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.beef), isFalse);
      expect(result.computedDate, equals(DateTime(2027, 1, 1)));
    });

    test('1.4: Leap year transition boundary (Feb 28, 23:59 to Feb 29, 00:01 in leap year 2028)', () {
      final cookedTime = DateTime(2028, 2, 28, 23, 59);
      final evalTime = DateTime(2028, 2, 29, 0, 1);

      final history = [
        MealHistoryData(
          id: 1,
          mealId: 4, // Fish
          mealName: 'سمك بلطي مقلي',
          proteinType: ProteinType.fish,
          carbsType: CarbsType.rice,
          cookedDate: cookedTime,
          status: MealHistoryStatus.cookedToday,
          createdAt: cookedTime,
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true),
        today: evalTime,
      );

      expect(result.recommendations.any((m) => m.proteinType == ProteinType.fish), isFalse);
      expect(result.computedDate, equals(DateTime(2028, 2, 29)));
    });

    test('1.5: Cooked at 23:59 on Day D, evaluated at 00:01 on Day D+2 (2 calendar days, 24h 02m apart)', () {
      // 2 calendar days apart -> outside the <= 1 calendar day window for lastCooked repeat protein
      final cookedTime = DateTime(2026, 9, 6, 23, 59);
      final evalTime = DateTime(2026, 9, 8, 0, 1);

      final history = [
        MealHistoryData(
          id: 1,
          mealId: 2, // Chicken
          mealName: 'ملوخية بالفراخ',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          cookedDate: cookedTime,
          status: MealHistoryStatus.cookedToday,
          createdAt: cookedTime,
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true),
        today: evalTime,
      );

      // Meal 2 itself is still in 14-day cooldown (delta = 2 days <= 14)
      expect(result.recommendations.any((m) => m.id == 2), isFalse);
      // But other chicken meals (e.g. Shish Tawook or Shawarma) are NOT blocked by yesterday repeat
      // because chicken was eaten 2 days ago, not yesterday!
      final chickenRecs = result.recommendations.where((m) => m.proteinType == ProteinType.chicken).toList();
      expect(chickenRecs.isNotEmpty, isTrue,
          reason: 'Other chicken dishes should be allowed because chicken was 2 days ago, not yesterday');
    });
  });

  group('Group 2: Extreme Cooldown Parameters (1 day, 60 days, 0 days, negative days, null)', () {
    test('2.1: Cooldown = 1 day (strict 1-day exclusion: excludes today and yesterday, allows 2 days ago)', () {
      final baseDate = DateTime(2026, 9, 10);
      final mealCookedToday = catalog[0];
      final mealCookedYesterday = catalog[1];
      final mealCooked2DaysAgo = catalog[2];
      final mealCooked3DaysAgo = catalog[3];
      final mealCooked4DaysAgo = catalog[4];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: mealCookedToday.id,
          mealName: mealCookedToday.name,
          proteinType: mealCookedToday.proteinType,
          carbsType: mealCookedToday.carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 2,
          mealId: mealCookedYesterday.id,
          mealName: mealCookedYesterday.name,
          proteinType: mealCookedYesterday.proteinType,
          carbsType: mealCookedYesterday.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1)),
        ),
        MealHistoryData(
          id: 3,
          mealId: mealCooked2DaysAgo.id,
          mealName: mealCooked2DaysAgo.name,
          proteinType: mealCooked2DaysAgo.proteinType,
          carbsType: mealCooked2DaysAgo.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 2)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 2)),
        ),
      ];

      final result = engine.compute(
        meals: [mealCookedToday, mealCookedYesterday, mealCooked2DaysAgo, mealCooked3DaysAgo, mealCooked4DaysAgo],
        history: history,
        settings: const AppSetting(cooldownDays: 1, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );

      // Today (delta=0) and Yesterday (delta=1) are <= cooldownDays (1) -> excluded!
      expect(result.recommendations.any((m) => m.id == mealCookedToday.id), isFalse);
      expect(result.recommendations.any((m) => m.id == mealCookedYesterday.id), isFalse);
      // 2 days ago (delta=2 > 1) -> eligible!
      expect(result.recommendations.any((m) => m.id == mealCooked2DaysAgo.id), isTrue);
      expect(result.relaxationLevel, equals(0));
    });

    test('2.2: Cooldown = 60 days (extreme long window)', () {
      final baseDate = DateTime(2026, 9, 10);
      final mealCooked59Days = catalog[0];
      final mealCooked60Days = catalog[1];
      final mealCooked61Days = catalog[2];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: mealCooked59Days.id,
          mealName: mealCooked59Days.name,
          proteinType: mealCooked59Days.proteinType,
          carbsType: mealCooked59Days.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 59)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 59)),
        ),
        MealHistoryData(
          id: 2,
          mealId: mealCooked60Days.id,
          mealName: mealCooked60Days.name,
          proteinType: mealCooked60Days.proteinType,
          carbsType: mealCooked60Days.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 60)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 60)),
        ),
        MealHistoryData(
          id: 3,
          mealId: mealCooked61Days.id,
          mealName: mealCooked61Days.name,
          proteinType: mealCooked61Days.proteinType,
          carbsType: mealCooked61Days.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 61)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 61)),
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 60, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );

      // 59 and 60 days are <= 60 -> excluded
      expect(result.recommendations.any((m) => m.id == mealCooked59Days.id), isFalse);
      expect(result.recommendations.any((m) => m.id == mealCooked60Days.id), isFalse);
      // 61 days > 60 -> eligible
      expect(result.relaxationLevel, equals(0));
    });

    test('2.3: Cooldown = 0 days (excludes only today at Level 0, allows yesterday)', () {
      final baseDate = DateTime(2026, 9, 10);
      final mealToday = catalog[0];
      final mealYesterday = catalog[1];
      final mealOther = catalog[2];
      final mealOther2 = catalog[3];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: mealToday.id,
          mealName: mealToday.name,
          proteinType: mealToday.proteinType,
          carbsType: mealToday.carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
        MealHistoryData(
          id: 2,
          mealId: mealYesterday.id,
          mealName: mealYesterday.name,
          proteinType: mealYesterday.proteinType,
          carbsType: mealYesterday.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1)),
        ),
      ];

      final result = engine.compute(
        meals: [mealToday, mealYesterday, mealOther, mealOther2],
        history: history,
        settings: const AppSetting(cooldownDays: 0, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );

      // At cooldownDays = 0, deltaDays <= 0 excludes today (delta=0), but allows yesterday (delta=1 > 0)
      expect(result.recommendations.any((m) => m.id == mealToday.id), isFalse);
      expect(result.recommendations.any((m) => m.id == mealYesterday.id), isTrue);
      expect(result.relaxationLevel, equals(0));
    });

    test('2.4: Negative cooldownDays (e.g. -5) does not crash or throw exceptions', () {
      final baseDate = DateTime(2026, 9, 10);
      final result = engine.compute(
        meals: catalog,
        history: const [],
        settings: const AppSetting(cooldownDays: -5),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(0));
    });

    test('2.5: Null settings parameter gracefully falls back to default 14-day config without crashing', () {
      final baseDate = DateTime(2026, 9, 10);
      final mealCooked5Days = catalog[0];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: mealCooked5Days.id,
          mealName: mealCooked5Days.name,
          proteinType: mealCooked5Days.proteinType,
          carbsType: mealCooked5Days.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 5)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 5)),
        ),
      ];

      // Passing null for settings
      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: null,
        today: baseDate,
      );

      // Default 14-day cooldown should apply, excluding mealCooked5Days
      expect(result.recommendations.any((m) => m.id == mealCooked5Days.id), isFalse);
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(0));
    });
  });

  group('Group 3: Small Vaults (0, 1, 2 meals) & No False Degradation', () {
    test('3.1: Vault with 0 meals returns empty recommendations at Level 5 with empty reason', () {
      final baseDate = DateTime(2026, 9, 10);
      final result = engine.compute(
        meals: const <Meal>[],
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations, isEmpty);
      expect(result.relaxationLevel, equals(5));
      expect(result.relaxationReason, equals('قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات.'));
    });

    test('3.2: Vault with exactly 1 meal (no history) returns 1 meal at Level 0 without false degradation', () {
      final baseDate = DateTime(2026, 9, 10);
      final singleMeal = catalog[0];

      final result = engine.compute(
        meals: [singleMeal],
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(1));
      expect(result.recommendations.first.id, equals(singleMeal.id));
      expect(result.relaxationLevel, equals(0),
          reason: 'A vault with 1 eligible meal must terminate at Level 0, NOT falsely degrade to Level 5!');
    });

    test('3.3: Vault with exactly 2 meals (no history) returns 2 meals at Level 0 without false degradation', () {
      final baseDate = DateTime(2026, 9, 10);
      final twoMeals = [catalog[0], catalog[1]];

      final result = engine.compute(
        meals: twoMeals,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(2));
      expect(result.recommendations.map((m) => m.id), containsAll([catalog[0].id, catalog[1].id]));
      expect(result.relaxationLevel, equals(0),
          reason: 'A vault with 2 eligible meals must terminate at Level 0, NOT falsely degrade to Level 5!');
    });

    test('3.4: Vault with 1 meal cooked 2 days ago gracefully degrades through cascade', () {
      final baseDate = DateTime(2026, 9, 10);
      final singleMeal = catalog[0];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: singleMeal.id,
          mealName: singleMeal.name,
          proteinType: singleMeal.proteinType,
          carbsType: singleMeal.carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 2)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 2)),
        ),
      ];

      // Cooldown is 14 days. Delta is 2 days.
      // Level 0: 14 days -> excluded
      // Level 1: 14 days -> excluded
      // Level 2: 7 days -> excluded
      // Level 3: 3 days (14~/4) -> excluded (2 <= 3)
      // Level 4: emergency mode (only excludes delta=0) -> 2 != 0 -> ELIGIBLE!
      final result = engine.compute(
        meals: [singleMeal],
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(1));
      expect(result.recommendations.first.id, equals(singleMeal.id));
      expect(result.relaxationLevel, equals(4),
          reason: 'Meal cooked 2 days ago should be recovered at Level 4 (exclude today only)');
    });

    test('3.5: Vault with 1 meal cooked today is recovered only at Level 5', () {
      final baseDate = DateTime(2026, 9, 10);
      final singleMeal = catalog[0];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: singleMeal.id,
          mealName: singleMeal.name,
          proteinType: singleMeal.proteinType,
          carbsType: singleMeal.carbsType,
          cookedDate: baseDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final result = engine.compute(
        meals: [singleMeal],
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      // Cooked today: Level 4 still excludes today (delta=0).
      // Level 5 completely bypasses cooldown.
      expect(result.recommendations.length, equals(1));
      expect(result.recommendations.first.id, equals(singleMeal.id));
      expect(result.relaxationLevel, equals(5));
    });
  });

  group('Group 4: Cooldown Saturation & Degradation Cascade Triggers', () {
    test('4.1: All meals sharing same protein as yesterday triggers Level 3 relaxation', () {
      final baseDate = DateTime(2026, 9, 10);
      // History: yesterday ate Chicken
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 999,
          mealName: 'شاورما فراخ سابقة',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.bread,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1)),
        ),
      ];

      // Vault contains ONLY chicken meals
      final chickenVault = catalog.where((m) => m.proteinType == ProteinType.chicken).toList();
      expect(chickenVault.length, greaterThanOrEqualTo(3));

      final result = engine.compute(
        meals: chickenVault,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true, preventRepeatCarbs: false),
        today: baseDate,
      );

      // Levels 0, 1, 2 all exclude chicken because of lastProtein repeat prevention.
      // Level 3 relaxes protein repeat rule -> chicken meals become eligible!
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(3));
      expect(result.recommendations.every((m) => m.proteinType == ProteinType.chicken), isTrue);
    });

    test('4.2: All meals sharing same carbs as yesterday triggers Level 1 relaxation', () {
      final baseDate = DateTime(2026, 9, 10);
      // History: yesterday ate Rice with Beef
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 999,
          mealName: 'فتة باللحمة',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1)),
        ),
      ];

      // Vault contains ONLY rice meals, but with multiple protein types (chicken, fish, legume)
      final riceVault = catalog.where((m) => m.carbsType == CarbsType.rice && m.proteinType != ProteinType.beef).toList();
      expect(riceVault.length, greaterThanOrEqualTo(3));

      final result = engine.compute(
        meals: riceVault,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true, preventRepeatCarbs: true),
        today: baseDate,
      );

      // Level 0 blocks repeated carbs (rice).
      // Level 1 relaxes carbs repeat rule -> rice meals become eligible!
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(1));
    });

    test('4.3: All meals on cooldown: 4 meals cooked 3, 5, 8, 10 days ago', () {
      final baseDate = DateTime(2026, 9, 10);
      final fourMeals = catalog.take(4).toList();

      final history = [
        MealHistoryData(
          id: 1,
          mealId: fourMeals[0].id,
          mealName: fourMeals[0].name,
          proteinType: fourMeals[0].proteinType,
          carbsType: fourMeals[0].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 3)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 3)),
        ),
        MealHistoryData(
          id: 2,
          mealId: fourMeals[1].id,
          mealName: fourMeals[1].name,
          proteinType: fourMeals[1].proteinType,
          carbsType: fourMeals[1].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 5)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 5)),
        ),
        MealHistoryData(
          id: 3,
          mealId: fourMeals[2].id,
          mealName: fourMeals[2].name,
          proteinType: fourMeals[2].proteinType,
          carbsType: fourMeals[2].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 8)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 8)),
        ),
        MealHistoryData(
          id: 4,
          mealId: fourMeals[3].id,
          mealName: fourMeals[3].name,
          proteinType: fourMeals[3].proteinType,
          carbsType: fourMeals[3].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 10)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 10)),
        ),
      ];

      // Cooldown = 14 days
      // Level 0: 14 days -> all excluded (0 candidates)
      // Level 1: 14 days -> all excluded (0 candidates)
      // Level 2: 7 days -> 8 and 10 days ago are > 7, so 2 candidates! But targetCount is 3, so 2 < 3 -> proceeds!
      // Level 3: 3 days (14~/4) -> 5, 8, 10 days ago are > 3, so 3 candidates! -> Level 3 succeeds!
      final result = engine.compute(
        meals: fourMeals,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(3),
          reason: 'Level 3 quarter cooldown (3 days) enables 3 meals cooked 5, 8, 10 days ago');
    });

    test('4.4: All meals cooked today triggers Level 5 emergency bypass', () {
      final baseDate = DateTime(2026, 9, 10);
      final fiveMeals = catalog.take(5).toList();

      final history = fiveMeals.map((m) => MealHistoryData(
        id: m.id,
        mealId: m.id,
        mealName: m.name,
        proteinType: m.proteinType,
        carbsType: m.carbsType,
        cookedDate: baseDate,
        status: MealHistoryStatus.cookedToday,
        createdAt: baseDate,
      )).toList();

      final result = engine.compute(
        meals: fiveMeals,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      // Since all meals were cooked today, Level 4 excludes all of them (delta == 0).
      // Level 5 completely bypasses cooldown, guaranteeing 3 recommendations.
      expect(result.recommendations.length, equals(3));
      expect(result.relaxationLevel, equals(5));
    });
  });

  group('Group 5: Diversity & Edge Structural Constraints', () {
    test('5.1: Monolithic vault (all meals have identical protein and identical carbs) does not crash or infinite loop', () {
      final baseDate = DateTime(2026, 9, 10);
      // Create 5 meals all with Chicken and Rice
      final monoVault = List.generate(5, (i) => Meal(
        id: 100 + i,
        name: 'طبق فراخ بالأرز $i',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.rice,
        category: MealCategory.ovenBaked,
        prepTimeMinutes: 30,
        createdAt: baseDate,
      ));

      final result = engine.compute(
        meals: monoVault,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      // All 3 will have chicken and rice because there are no alternatives
      expect(result.recommendations.every((m) => m.proteinType == ProteinType.chicken), isTrue);
      expect(result.recommendations.every((m) => m.carbsType == CarbsType.rice), isTrue);
      // All 3 must be distinct meals
      final ids = result.recommendations.map((m) => m.id).toSet();
      expect(ids.length, equals(3));
    });

    test('5.2: Inter-card protein diversity strictly prioritizes distinct proteins when available', () {
      final baseDate = DateTime(2026, 9, 10);
      final result = engine.compute(
        meals: catalog,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
      final distinctProteins = result.recommendations.map((m) => m.proteinType).toSet();
      expect(distinctProteins.length, equals(3),
          reason: 'Full catalog has beef, chicken, fish, legume - all 3 cards must have distinct proteins');
    });

    test('5.3: Duplicate meal instances in meals list handled gracefully', () {
      final baseDate = DateTime(2026, 9, 10);
      // Passing duplicates of meal 1
      final mealsWithDupes = [catalog[0], catalog[0], catalog[1], catalog[2]];

      final result = engine.compute(
        meals: mealsWithDupes,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
    });
  });

  group('Group 6: Corrupt, Missing & Extreme History Data', () {
    test('6.1: History entry with null mealId (deleted meal) does not crash and preserves context', () {
      final baseDate = DateTime(2026, 9, 10);
      final history = [
        MealHistoryData(
          id: 1,
          mealId: null, // Foreign key set to null on meal deletion
          mealName: 'وجبة محذوفة كباب حلة',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1)),
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true),
        today: baseDate,
      );

      // Context of beef is preserved from deleted meal -> beef is excluded
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.beef), isFalse);
      expect(result.recommendations.length, equals(3));
    });

    test('6.2: History entry with ghost mealId not in meals list does not crash', () {
      final baseDate = DateTime(2026, 9, 10);
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 99999, // Unknown ID
          mealName: 'أكلة فضائية',
          proteinType: ProteinType.fish,
          carbsType: CarbsType.bread,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1)),
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true),
        today: baseDate,
      );

      expect(result.recommendations.any((m) => m.proteinType == ProteinType.fish), isFalse);
      expect(result.recommendations.length, equals(3));
    });

    test('6.3: History with future cooked date (clock desynchronization) does not crash', () {
      final baseDate = DateTime(2026, 9, 10);
      final futureDate = DateTime(2026, 9, 20); // 10 days in future

      final history = [
        MealHistoryData(
          id: 1,
          mealId: 1,
          mealName: 'كشري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          cookedDate: futureDate,
          status: MealHistoryStatus.cookedToday,
          createdAt: futureDate,
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );

      expect(result.recommendations.length, equals(3));
    });

    test('6.4: Multiple history entries on the same day correctly picks the most recent entry', () {
      final baseDate = DateTime(2026, 9, 10);
      // Yesterday lunch: Beef. Yesterday dinner: Fish.
      final history = [
        MealHistoryData(
          id: 1,
          mealId: 3,
          mealName: 'حواوشي',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.bread,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1, hours: 5)),
        ),
        MealHistoryData(
          id: 2,
          mealId: 4,
          mealName: 'سمك مشوي',
          proteinType: ProteinType.fish,
          carbsType: CarbsType.rice,
          cookedDate: baseDate.subtract(const Duration(days: 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(const Duration(days: 1, hours: 1)), // More recent!
        ),
      ];

      final result = engine.compute(
        meals: catalog,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: true),
        today: baseDate,
      );

      // The latest eaten protein is fish (from dinner createdAt)
      expect(result.recommendations.any((m) => m.proteinType == ProteinType.fish), isFalse);
    });
  });

  group('Group 7: Stress Harness, Scale & Determinism', () {
    test('7.1: Large history volume (5,000 entries) executes within acceptable duration (< 200ms)', () {
      final baseDate = DateTime(2026, 9, 10);
      final massiveHistory = List.generate(5000, (i) {
        final meal = catalog[i % catalog.length];
        return MealHistoryData(
          id: i,
          mealId: meal.id,
          mealName: meal.name,
          proteinType: meal.proteinType,
          carbsType: meal.carbsType,
          cookedDate: baseDate.subtract(Duration(days: (i ~/ 3) + 1)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate.subtract(Duration(days: (i ~/ 3) + 1)),
        );
      });

      final stopwatch = Stopwatch()..start();
      final result = engine.compute(
        meals: catalog,
        history: massiveHistory,
        settings: const AppSetting(cooldownDays: 14),
        today: baseDate,
      );
      stopwatch.stop();

      expect(result.recommendations.length, equals(3));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'Engine must process 5,000 history entries efficiently without quadratic slowdown');
    });

    test('7.2: Deterministic recommendation output over 500 consecutive executions', () {
      final baseDate = DateTime(2026, 9, 10);
      final reference = engine.compute(
        meals: catalog,
        history: const [],
        settings: const AppSetting(),
        today: baseDate,
      );

      final referenceIds = reference.recommendations.map((m) => m.id).toList();

      for (int i = 0; i < 500; i++) {
        final trial = engine.compute(
          meals: catalog,
          history: const [],
          settings: const AppSetting(),
          today: baseDate,
        );
        expect(trial.recommendations.map((m) => m.id).toList(), equals(referenceIds));
      }
    });

    test('7.3: Day transition alters jitter and ranking appropriately', () {
      final day1 = DateTime(2026, 9, 10);
      final day2 = DateTime(2026, 9, 11); // Different day (and Friday!)

      final res1 = engine.compute(
        meals: catalog,
        history: const [],
        settings: const AppSetting(),
        today: day1,
      );
      final res2 = engine.compute(
        meals: catalog,
        history: const [],
        settings: const AppSetting(),
        today: day2,
      );

      // On Friday (day 2), the top recommendation must be Friday Special
      expect(res2.recommendations.first.isFridaySpecial, isTrue);
      // Scores and rankings differ across days
      expect(res1.recommendations.map((m) => m.id).toList(), isNot(equals(res2.recommendations.map((m) => m.id).toList())));
    });
  });

  group('Group 8: Oracle Fidelity & Confounding Variable Isolation', () {
    test('8.1: Exact cooldown boundary isolation: 14 vs 15 days in isolated 3-meal vault', () {
      final baseDate = DateTime(2026, 9, 6);
      final vault = [catalog[0], catalog[1], catalog[2]]; // Exactly 3 meals

      final history14 = [
        MealHistoryData(
          id: 1,
          mealId: vault[0].id,
          mealName: vault[0].name,
          proteinType: vault[0].proteinType,
          carbsType: vault[0].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 14)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final res14 = engine.compute(
        meals: vault,
        history: history14,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );

      // Meal 0 is in 14-day cooldown -> excluded at Level 0!
      // Vault has only 2 other meals, so candidate count is 2 < 3.
      // Must degrade to recover 3 meals!
      expect(res14.relaxationLevel, greaterThan(0),
          reason: 'When meal 0 is on cooldown, vault of 3 cannot satisfy targetCount 3 at Level 0');

      final history15 = [
        MealHistoryData(
          id: 1,
          mealId: vault[0].id,
          mealName: vault[0].name,
          proteinType: vault[0].proteinType,
          carbsType: vault[0].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 15)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      final res15 = engine.compute(
        meals: vault,
        history: history15,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );

      // Meal 0 cooked 15 days ago is ELIGIBLE!
      // All 3 meals are eligible at Level 0!
      expect(res15.relaxationLevel, equals(0));
      expect(res15.recommendations.any((m) => m.id == vault[0].id), isTrue,
          reason: 'In isolated 3-meal vault, eligible meal 0 MUST be selected at Level 0');
    });

    test('8.2: Leap year 2028 Feb 28 -> Mar 1 boundary in isolated 3-meal vault', () {
      final leapFeb28 = DateTime(2028, 2, 28);
      final leapMar1 = DateTime(2028, 3, 1);
      final vault = [catalog[0], catalog[1], catalog[2]];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: vault[0].id,
          mealName: vault[0].name,
          proteinType: vault[0].proteinType,
          carbsType: vault[0].carbsType,
          cookedDate: leapFeb28,
          status: MealHistoryStatus.cookedToday,
          createdAt: leapFeb28,
        ),
      ];

      // Cooldown = 1 day. Feb 28 to Mar 1 in leap year 2028 is 2 days!
      // Delta (2 days) > cooldown (1 day) -> eligible at Level 0!
      final result = engine.compute(
        meals: vault,
        history: history,
        settings: const AppSetting(cooldownDays: 1, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: leapMar1,
      );

      expect(result.relaxationLevel, equals(0));
      expect(result.recommendations.any((m) => m.id == vault[0].id), isTrue);
    });

    test('8.3: Cooldown mutation (14 to 30 days) in isolated 3-meal vault', () {
      final baseDate = DateTime(2026, 9, 6);
      final vault = [catalog[0], catalog[1], catalog[2]];

      final history = [
        MealHistoryData(
          id: 1,
          mealId: vault[0].id,
          mealName: vault[0].name,
          proteinType: vault[0].proteinType,
          carbsType: vault[0].carbsType,
          cookedDate: baseDate.subtract(const Duration(days: 20)),
          status: MealHistoryStatus.cookedToday,
          createdAt: baseDate,
        ),
      ];

      // At 14 days cooldown: cooked 20 days ago -> eligible! Level 0!
      final res14 = engine.compute(
        meals: vault,
        history: history,
        settings: const AppSetting(cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );
      expect(res14.relaxationLevel, equals(0));
      expect(res14.recommendations.any((m) => m.id == vault[0].id), isTrue);

      // At 30 days cooldown: cooked 20 days ago (20 <= 30) -> ON COOLDOWN!
      // Only 2 meals available at Level 0 -> must degrade!
      final res30 = engine.compute(
        meals: vault,
        history: history,
        settings: const AppSetting(cooldownDays: 30, preventRepeatProtein: false, preventRepeatCarbs: false),
        today: baseDate,
      );
      expect(res30.relaxationLevel, greaterThan(0));
    });
  });
}

