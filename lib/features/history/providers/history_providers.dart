import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

/// Reactive stream watching chronological cooking history ordered descending by cookedAt.
final mealHistoryProvider = StreamProvider<List<MealHistoryData>>((ref) {
  final dao = ref.watch(mealHistoryDaoProvider);
  return dao.watchHistory();
});

/// Reactive stream joining history with meals for display (with nullable meal if deleted).
final mealHistoryWithMealProvider = StreamProvider<List<MealHistoryWithMeal>>((ref) {
  final dao = ref.watch(mealHistoryDaoProvider);
  return dao.watchHistoryWithMeal();
});

/// Reactive stream for the latest single cooked meal entry.
final latestCookedMealProvider = StreamProvider<MealHistoryData?>((ref) {
  final dao = ref.watch(mealHistoryDaoProvider);
  return dao.watchLatestCookedMeal();
});

/// Mutation controller for meal history operations.
class HistoryController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Logs a meal as 'cooked today' with snapshot fields.
  Future<int> logCookedMeal(Meal meal, {DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealHistoryDaoProvider);
      final id = await dao.logCookedMeal(
        meal,
        cookedAt: cookedAt,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Logs a meal as 'leftover' with snapshot fields.
  Future<int> logLeftoverMeal(Meal meal, {DateTime? cookedAt, String? notes}) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealHistoryDaoProvider);
      final id = await dao.logLeftoverMeal(
        meal,
        cookedAt: cookedAt,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Deletes a history entry by ID (e.g. undo action).
  Future<int> deleteHistoryEntry(int id) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealHistoryDaoProvider);
      final deleted = await dao.deleteHistoryEntry(id);
      state = const AsyncValue.data(null);
      return deleted;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Clears all history entries.
  Future<int> clearAllHistory() async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealHistoryDaoProvider);
      final deleted = await dao.clearAllHistory();
      state = const AsyncValue.data(null);
      return deleted;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }
}

final historyControllerProvider = AsyncNotifierProvider<HistoryController, void>(() {
  return HistoryController();
});
