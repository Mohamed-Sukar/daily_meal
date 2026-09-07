// test/e2e/full_flow_test.dart
// Tier 3 (Cross-Feature Interactions) & Tier 4 (Real-World Scenarios)
// Complete End-to-End simulation suite for 'أكلة النهاردة'

import 'package:flutter_test/flutter_test.dart';
import '../support/contracts.dart';
import '../support/in_memory_repository.dart';
import '../support/seed_catalog.dart';

void main() {
  group('Tier 3: Cross-Feature Interactions', () {
    late AppStateCoordinator coordinator;
    DateTime simulatedNow = DateTime(2026, 9, 6); // Sunday

    setUp(() {
      simulatedNow = DateTime(2026, 9, 6);
      coordinator = AppStateCoordinator(
        seedDefaults: true,
        nowProvider: () => simulatedNow,
      );
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('T3.1: Adding custom meal in Vault immediately enters candidate pool', () async {
      // Simulate on Friday to verify that Friday special + favorite vaults to top recommendation
      simulatedNow = DateTime(2026, 9, 11); // Friday
      var recs = await coordinator.getRecommendations();
      expect(recs.recommendations.any((m) => m.name == 'طاجن أرز معمر بالحمام'), isFalse);

      // Add custom meal with high score potential (Favorite + Friday Special on Friday)
      await coordinator.mealsDao.insertMeal(
        const MealsCompanion(
          name: 'طاجن أرز معمر بالحمام',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.rice,
          category: MealCategory.ovenBaked,
          prepTimeMinutes: 75,
          isFavorite: true,
          isFridaySpecial: true,
        ),
      );

      // Vault contains 21 meals
      final allMeals = await coordinator.mealsDao.getAllMeals();
      expect(allMeals.length, equals(21));

      // Recommendation pool includes the new meal as top recommendation
      recs = await coordinator.getRecommendations();
      expect(recs.recommendations.any((m) => m.name == 'طاجن أرز معمر بالحمام'), isTrue,
          reason: 'Newly added favorite Friday special meal on Friday must rank in top recommendations!');
    });

    test('T3.2: Mark meal Cooked Today -> history logged -> enters cooldown -> replaced on Home card', () async {
      // 1. Get initial top recommendation
      final initialRecs = await coordinator.getRecommendations();
      expect(initialRecs.recommendations.isNotEmpty, isTrue);
      final topMeal = initialRecs.recommendations.first;

      // 2. Tap "طبخت دي النهاردة"
      await coordinator.markMealCookedToday(topMeal, notes: 'عزومة عائلية');

      // 3. Verify history log created
      final history = await coordinator.historyDao.getRecentHistory();
      expect(history.first.mealId, equals(topMeal.id));
      expect(history.first.mealName, equals(topMeal.name));
      expect(history.first.status, equals(MealHistoryStatus.cookedToday));
      expect(history.first.notes, equals('عزومة عائلية'));

      // 4. Verify top meal is immediately excluded from current recommendations
      final updatedRecs = await coordinator.getRecommendations();
      expect(updatedRecs.recommendations.any((m) => m.id == topMeal.id), isFalse,
          reason: 'Cooked meal must immediately enter cooldown!');
      expect(updatedRecs.recommendations.length, equals(3));
    });

    test('T3.3: Mark meal as Leftover updates last eaten context without locking other meals', () async {
      final initialRecs = await coordinator.getRecommendations();
      final targetMeal = initialRecs.recommendations.first;

      // Mark as leftover
      await coordinator.markMealLeftover(targetMeal);

      // Check history
      final history = await coordinator.historyDao.getRecentHistory();
      expect(history.first.mealId, equals(targetMeal.id));
      expect(history.first.status, equals(MealHistoryStatus.leftover));

      // Check recommendations
      final newRecs = await coordinator.getRecommendations();
      // Target meal's protein is excluded from next recommendations due to last-eaten protein rule
      expect(newRecs.recommendations.any((m) => m.proteinType == targetMeal.proteinType), isFalse,
          reason: 'Leftover protein must update dietary fatigue prevention!');
    });

    test('T3.4: Changing cooldown setting from 14 to 3 days instantly unlocks meals cooked 4 days ago', () async {
      // Meal cooked 4 days ago
      final cookedMeal = initialEgyptianMealsSeed[0]; // Koshari
      await coordinator.historyDao.logMeal(
        mealId: cookedMeal.id,
        mealName: cookedMeal.name,
        protein: cookedMeal.proteinType,
        carbs: cookedMeal.carbsType,
        cookedAt: simulatedNow.subtract(const Duration(days: 4)),
        entryType: MealHistoryStatus.cookedToday,
      );

      // Under 14-day cooldown: Koshari is excluded
      var recs = await coordinator.getRecommendations();
      expect(recs.recommendations.any((m) => m.id == cookedMeal.id), isFalse);

      // Change cooldown setting to 3 days
      await coordinator.settingsDao.updateCooldownDays(3);

      // Under 3-day cooldown: 4 days ago is outside the cooldown, so Koshari is eligible
      recs = await coordinator.getRecommendations();
      expect(recs.recommendations.any((m) => m.id == cookedMeal.id), isTrue,
          reason: 'Shortening cooldown duration must immediately release eligible meals!');
    });

    test('T3.5: Spin the Wheel roulette picks eligible dish, marked cooked, enters cooldown', () async {
      final winner = await coordinator.spinTheWheel();
      expect(winner, isNotNull);

      // Mark winner cooked
      await coordinator.markMealCookedToday(winner!);

      // Verify winner is now on cooldown
      final recs = await coordinator.getRecommendations();
      expect(recs.recommendations.any((m) => m.id == winner.id), isFalse);
    });
  });

  group('Tier 4: Real-World Scenarios', () {
    late AppStateCoordinator coordinator;
    DateTime simulatedNow = DateTime(2026, 9, 6); // Sunday

    setUp(() {
      simulatedNow = DateTime(2026, 9, 6);
      coordinator = AppStateCoordinator(
        seedDefaults: true,
        nowProvider: () => simulatedNow,
      );
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('T4.1: 7-Day Egyptian Household Simulation prevents repeat proteins and prioritizes Friday special', () async {
      final dailyCookedMeals = <Meal>[];

      // Day 1: Sunday (2026-09-06)
      simulatedNow = DateTime(2026, 9, 6);
      var recs = await coordinator.getRecommendations();
      expect(recs.recommendations.length, equals(3));
      final day1Meal = recs.recommendations.first;
      await coordinator.markMealCookedToday(day1Meal);
      dailyCookedMeals.add(day1Meal);

      // Day 2: Monday (2026-09-07)
      simulatedNow = DateTime(2026, 9, 7);
      recs = await coordinator.getRecommendations();
      // Verify Day 1 meal and Day 1 protein/carbs repeat prevention
      expect(recs.recommendations.any((m) => m.id == day1Meal.id), isFalse);
      expect(recs.recommendations.any((m) => m.proteinType == day1Meal.proteinType), isFalse);
      final day2Meal = recs.recommendations.first;
      await coordinator.markMealCookedToday(day2Meal);
      dailyCookedMeals.add(day2Meal);

      // Day 3: Tuesday (2026-09-08)
      simulatedNow = DateTime(2026, 9, 8);
      recs = await coordinator.getRecommendations();
      expect(recs.recommendations.any((m) => m.proteinType == day2Meal.proteinType), isFalse);
      final day3Meal = recs.recommendations.first;
      await coordinator.markMealCookedToday(day3Meal);
      dailyCookedMeals.add(day3Meal);

      // Day 4: Wednesday (2026-09-09)
      simulatedNow = DateTime(2026, 9, 9);
      recs = await coordinator.getRecommendations();
      expect(recs.recommendations.any((m) => m.proteinType == day3Meal.proteinType), isFalse);
      final day4Meal = recs.recommendations.first;
      await coordinator.markMealCookedToday(day4Meal);
      dailyCookedMeals.add(day4Meal);

      // Day 5: Thursday (2026-09-10)
      simulatedNow = DateTime(2026, 9, 10);
      recs = await coordinator.getRecommendations();
      expect(recs.recommendations.any((m) => m.proteinType == day4Meal.proteinType), isFalse);
      final day5Meal = recs.recommendations.first;
      await coordinator.markMealCookedToday(day5Meal);
      dailyCookedMeals.add(day5Meal);

      // Day 6: Friday (2026-09-11) -> Friday Special Booster
      simulatedNow = DateTime(2026, 9, 11);
      expect(simulatedNow.weekday, equals(DateTime.friday));
      recs = await coordinator.getRecommendations();
      // On Friday, top recommendation must be Friday Special
      expect(recs.recommendations.first.isFridaySpecial, isTrue,
          reason: 'On Friday, Friday Special must be ranked #1!');
      final day6Meal = recs.recommendations.first;
      await coordinator.markMealCookedToday(day6Meal);
      dailyCookedMeals.add(day6Meal);

      // Day 7: Saturday (2026-09-12)
      simulatedNow = DateTime(2026, 9, 12);
      recs = await coordinator.getRecommendations();
      expect(recs.recommendations.any((m) => m.proteinType == day6Meal.proteinType), isFalse);
      final day7Meal = recs.recommendations.first;
      await coordinator.markMealCookedToday(day7Meal);
      dailyCookedMeals.add(day7Meal);

      // Verification of entire 7-day run
      expect(dailyCookedMeals.length, equals(7));

      // Verify no back-to-back protein repetitions
      for (int i = 0; i < dailyCookedMeals.length - 1; i++) {
        expect(dailyCookedMeals[i].proteinType, isNot(equals(dailyCookedMeals[i + 1].proteinType)),
            reason: 'Day ${i + 1} and Day ${i + 2} repeated protein ${dailyCookedMeals[i].proteinType}!');
      }

      // Verify history count
      final fullHistory = await coordinator.historyDao.getRecentHistory();
      expect(fullHistory.length, equals(7));
    });

    test('T4.2: 15-Day Cooldown Expiration: meal on cooldown for 14 days re-enters on Day 15', () async {
      final targetMeal = initialEgyptianMealsSeed[0]; // Koshari

      // Day 1: Cook Koshari
      simulatedNow = DateTime(2026, 9, 1);
      await coordinator.markMealCookedToday(targetMeal);

      // Days 2 to 14: Koshari remains on cooldown
      for (int day = 2; day <= 14; day++) {
        simulatedNow = DateTime(2026, 9, day);
        final recs = await coordinator.getRecommendations();
        expect(recs.recommendations.any((m) => m.id == targetMeal.id), isFalse,
            reason: 'Day $day: Target meal must remain on cooldown!');
      }

      // Day 15: 14-day cooldown has expired (difference = 14 days)
      // Cooked on Sept 1, Sept 16 is 15 days later
      simulatedNow = DateTime(2026, 9, 16);
      final recsDay15 = await coordinator.getRecommendations();
      expect(recsDay15.recommendations.any((m) => m.id == targetMeal.id), isTrue,
          reason: 'Day 15: Cooldown has expired, meal must re-enter recommendation candidate pool!');
    });

    test('T4.3: Low-Inventory Quarantine: 4-meal vault degrades gracefully when all cooked', () async {
      // Create isolated coordinator with exactly 4 meals
      final quarantineCoordinator = AppStateCoordinator(
        seedDefaults: false,
        nowProvider: () => simulatedNow,
      );
      addTearDown(quarantineCoordinator.dispose);

      final miniMeals = initialEgyptianMealsSeed.take(4).toList();
      for (final m in miniMeals) {
        await quarantineCoordinator.mealsDao.insertMeal(
          MealsCompanion(
            name: m.name,
            proteinType: m.proteinType,
            carbsType: m.carbsType,
            category: m.category,
            prepTimeMinutes: m.prepTimeMinutes,
          ),
        );
      }

      final allFour = await quarantineCoordinator.mealsDao.getAllMeals();
      expect(allFour.length, equals(4));

      // Cook all 4 meals over 4 days
      for (int i = 0; i < 4; i++) {
        simulatedNow = DateTime(2026, 9, 1 + i);
        await quarantineCoordinator.markMealCookedToday(allFour[i]);
      }

      // Day 5: All 4 meals are on 14-day cooldown!
      simulatedNow = DateTime(2026, 9, 5);
      final degradedRecs = await quarantineCoordinator.getRecommendations();

      // Graceful degradation must kick in (relaxation level > 0)
      expect(degradedRecs.recommendations.length, equals(3));
      expect(degradedRecs.relaxationLevel, greaterThan(0));
      expect(degradedRecs.relaxationReason, isNotEmpty);
    });

    test('T4.4: Complete User Journey across all 4 tabs', () async {
      // 1. Home Tab: Check initial recommendations
      var homeRecs = await coordinator.getRecommendations();
      expect(homeRecs.recommendations.length, equals(3));

      // 2. Vault Tab: User searches, adds a new meal, edits an existing meal
      final allVaultMeals = await coordinator.mealsDao.getAllMeals();
      final hawawshi = allVaultMeals.firstWhere((m) => m.name.contains('حواوشي'));

      // Edit Hawawshi prep time from 30 to 25 mins
      await coordinator.mealsDao.updateMeal(hawawshi.copyWith(prepTimeMinutes: 25));
      final updatedHawawshi = await coordinator.mealsDao.getMealById(hawawshi.id);
      expect(updatedHawawshi!.prepTimeMinutes, equals(25));

      // Add new meal
      final newMealId = await coordinator.mealsDao.insertMeal(
        const MealsCompanion(
          name: 'طاجن لسان عصفور باللحمة',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.pasta,
          category: MealCategory.ovenBaked,
          prepTimeMinutes: 45,
          isFavorite: true,
        ),
      );
      expect(newMealId, greaterThan(0));

      // 3. Settings Tab: User changes cooldown to 7 days, sets dark theme, sets notification to 12:30 PM
      await coordinator.settingsDao.updateCooldownDays(7);
      await coordinator.settingsDao.updateThemeMode(AppThemeModePreference.dark);
      await coordinator.settingsDao.updateNotificationTime(12, 30);

      final settings = await coordinator.settingsDao.getSettings();
      expect(settings.cooldownDays, equals(7));
      expect(settings.themeMode, equals(AppThemeModePreference.dark));
      expect(settings.notificationHour, equals(12));
      expect(settings.notificationMinute, equals(30));

      // 4. History Tab: Log a cooked meal from recommendations, verify in timeline, then delete/undo it
      final topRecommendedMeal = homeRecs.recommendations.first;
      await coordinator.markMealCookedToday(topRecommendedMeal);

      var history = await coordinator.historyDao.getRecentHistory();
      expect(history.first.mealId, equals(topRecommendedMeal.id));

      // Recommendation stack reflects cooldown
      var recsAfterCook = await coordinator.getRecommendations();
      expect(recsAfterCook.recommendations.any((m) => m.id == topRecommendedMeal.id), isFalse);

      // User undoes the log in History
      await coordinator.historyDao.deleteHistoryEntry(history.first.id);
      history = await coordinator.historyDao.getRecentHistory();
      expect(history.isEmpty, isTrue);

      // Recommendation stack immediately restores topRecommendedMeal
      var recsAfterUndo = await coordinator.getRecommendations();
      expect(recsAfterUndo.recommendations.any((m) => m.id == topRecommendedMeal.id), isTrue,
          reason: 'Undoing in History must restore meal to recommendations!');
    });
  });
}
