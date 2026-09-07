// test/widget/riverpod_reactivity_test.dart
// Tier 1 (Feature Coverage), Tier 2 (Boundary Cases), & Tier 3 (Cross-Feature)
// for Riverpod Unidirectional Data Flow, Auto-Recalculation & Spin the Wheel Roulette

import 'package:flutter_test/flutter_test.dart';
import '../support/contracts.dart';
import '../support/in_memory_repository.dart';
import '../support/seed_catalog.dart';

void main() {
  group('Tier 1: Feature Coverage (Riverpod Reactivity & Discovery)', () {
    late AppStateCoordinator coordinator;

    setUp(() {
      coordinator = AppStateCoordinator(seedDefaults: false);
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('R4.1: Adding a new meal immediately emits updated List<Meal> stream', () async {
      final expectation = expectLater(
        coordinator.mealsDao.watchAllMeals(),
        emits(
          predicate<List<Meal>>((list) => list.length == 1 && list.first.name == 'طاجن تورلي'),
        ),
      );

      await coordinator.mealsDao.insertMeal(
        const MealsCompanion(
          name: 'طاجن تورلي',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.potato,
          category: MealCategory.ovenBaked,
          prepTimeMinutes: 50,
        ),
      );

      await expectation;
    });

    test('R4.2: Logging a cooked meal immediately emits updated history stream', () async {
      final mealId = await coordinator.mealsDao.insertMeal(
        const MealsCompanion(
          name: 'كفتة داوود باشا',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 40,
        ),
      );
      final meal = await coordinator.mealsDao.getMealById(mealId);

      final historyExpectation = expectLater(
        coordinator.historyDao.watchHistory(),
        emitsInOrder([
          predicate<List<MealHistoryData>>((list) => list.length == 1 && list.first.mealName == 'كفتة داوود باشا'),
        ]),
      );

      await coordinator.markMealCookedToday(meal!);
      await historyExpectation;
    });

    test('R4.3: Changing cooldown setting immediately emits updated AppSetting stream', () async {
      final settingsExpectation = expectLater(
        coordinator.settingsDao.watchSettings(),
        emitsInOrder([
          predicate<AppSetting>((s) => s.cooldownDays == 7),
        ]),
      );

      await coordinator.settingsDao.updateCooldownDays(7);
      await settingsExpectation;
    });

    test('R4.4: Adding a new meal automatically triggers recommendation recalculation', () async {
      final recsExpectation = expectLater(
        coordinator.watchRecommendations(),
        emitsThrough(
          predicate<RecommendationResult>((res) =>
              res.recommendations.any((m) => m.name == 'مكرونة نجرسكو')),
        ),
      );

      await coordinator.mealsDao.insertMeal(
        const MealsCompanion(
          name: 'مكرونة نجرسكو',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.pasta,
          category: MealCategory.ovenBaked,
          prepTimeMinutes: 45,
          isFavorite: true,
        ),
      );

      await recsExpectation;
    });

    test('R4.5: Spin the Wheel candidates are populated from current recommendations', () async {
      // Seed starter catalog
      for (final seed in initialEgyptianMealsSeed.take(6)) {
        await coordinator.mealsDao.insertMeal(
          MealsCompanion(
            name: seed.name,
            proteinType: seed.proteinType,
            carbsType: seed.carbsType,
            category: seed.category,
            prepTimeMinutes: seed.prepTimeMinutes,
            isFavorite: seed.isFavorite,
            isFridaySpecial: seed.isFridaySpecial,
            isBudgetFriendly: seed.isBudgetFriendly,
          ),
        );
      }

      final recs = await coordinator.getRecommendations();
      expect(recs.recommendations.length, equals(3));

      // Spin the wheel
      final selected = await coordinator.spinTheWheel();
      expect(selected, isNotNull);
      expect(recs.recommendations.any((m) => m.id == selected!.id), isTrue,
          reason: 'Spin the wheel winner must belong to the recommendation pool!');
    });
  });

  group('Tier 2 & 3: Boundary & Cross-Feature Interactions', () {
    late AppStateCoordinator coordinator;

    setUp(() {
      coordinator = AppStateCoordinator(seedDefaults: false);
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('T2.1: Spin the Wheel with fewer than 2 candidates returns null (disabled)', () async {
      // Empty vault
      var wheelWinner = await coordinator.spinTheWheel();
      expect(wheelWinner, isNull, reason: 'Wheel cannot spin with 0 meals!');

      // Exactly 1 meal
      await coordinator.mealsDao.insertMeal(
        const MealsCompanion(
          name: 'كشري',
          proteinType: ProteinType.legume,
          carbsType: CarbsType.rice,
          category: MealCategory.egyptianTraditional,
          prepTimeMinutes: 50,
        ),
      );

      wheelWinner = await coordinator.spinTheWheel();
      expect(wheelWinner, isNull, reason: 'Wheel requires at least 2 candidates to spin!');
    });

    test('T3.1: Spin the wheel winner can be immediately marked cooked and enters cooldown', () async {
      // Insert 5 meals
      for (final seed in initialEgyptianMealsSeed.take(5)) {
        await coordinator.mealsDao.insertMeal(
          MealsCompanion(
            name: seed.name,
            proteinType: seed.proteinType,
            carbsType: seed.carbsType,
            category: seed.category,
            prepTimeMinutes: seed.prepTimeMinutes,
          ),
        );
      }

      final winner = await coordinator.spinTheWheel();
      expect(winner, isNotNull);

      // Cook the winner
      await coordinator.markMealCookedToday(winner!);

      // Check history
      final history = await coordinator.historyDao.getRecentHistory();
      expect(history.first.mealId, equals(winner.id));

      // Check that winner is now excluded from recommendations under strict mode
      final newRecs = await coordinator.getRecommendations();
      expect(newRecs.recommendations.any((m) => m.id == winner.id), isFalse,
          reason: 'Winner marked cooked must immediately enter cooldown!');
    });

    test('T3.2: Deleting an accidental history entry restores the meal to recommendations', () async {
      // Insert 5 meals
      for (final seed in initialEgyptianMealsSeed.take(5)) {
        await coordinator.mealsDao.insertMeal(
          MealsCompanion(
            name: seed.name,
            proteinType: seed.proteinType,
            carbsType: seed.carbsType,
            category: seed.category,
            prepTimeMinutes: seed.prepTimeMinutes,
          ),
        );
      }

      final allMeals = await coordinator.mealsDao.getAllMeals();
      final targetMeal = allMeals.first;

      // Mark cooked
      await coordinator.markMealCookedToday(targetMeal);
      var recsAfterCook = await coordinator.getRecommendations();
      expect(recsAfterCook.recommendations.any((m) => m.id == targetMeal.id), isFalse);

      // Undo/Delete the log
      final history = await coordinator.historyDao.getRecentHistory();
      await coordinator.historyDao.deleteHistoryEntry(history.first.id);

      // Meal should now be eligible again
      final recsAfterUndo = await coordinator.getRecommendations();
      expect(recsAfterUndo.recommendations.any((m) => m.id == targetMeal.id), isTrue,
          reason: 'Undoing cooking log must immediately restore meal to candidate pool!');
    });
  });
}
