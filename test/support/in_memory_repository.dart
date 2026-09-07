// test/support/in_memory_repository.dart
// In-memory reactive repository implementing DAOs and state propagation
// strictly adhering to PROJECT.md § Interface Contracts.

import 'dart:async';
import 'contracts.dart';
import 'reference_engine.dart';
import 'seed_catalog.dart';

class InMemoryMealsDao {
  final List<Meal> _meals = [];
  final _controller = StreamController<List<Meal>>.broadcast();
  int _nextId = 1;

  InMemoryMealsDao({bool seedDefaults = false}) {
    if (seedDefaults) {
      _meals.addAll(initialEgyptianMealsSeed);
      _nextId = 21;
    }
    _emit();
  }

  void _emit() {
    _controller.add(List.unmodifiable(_meals));
  }

  Stream<List<Meal>> watchAllMeals() => _controller.stream;

  Future<List<Meal>> getAllMeals() async => List.unmodifiable(_meals);

  Future<Meal?> getMealById(int id) async {
    try {
      return _meals.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<int> insertMeal(MealsCompanion companion) async {
    if (companion.name.trim().isEmpty) {
      throw ArgumentError('Meal name cannot be empty or whitespace.');
    }
    if (companion.prepTimeMinutes <= 0) {
      throw ArgumentError('Prep time must be positive.');
    }

    final id = _nextId++;
    final meal = Meal(
      id: id,
      name: companion.name.trim(),
      photoPath: companion.photoPath,
      proteinType: companion.proteinType,
      carbsType: companion.carbsType,
      category: companion.category,
      prepTimeMinutes: companion.prepTimeMinutes,
      isFridaySpecial: companion.isFridaySpecial,
      isBudgetFriendly: companion.isBudgetFriendly,
      isFavorite: companion.isFavorite,
      createdAt: DateTime.now(),
    );
    _meals.add(meal);
    _emit();
    return id;
  }

  Future<bool> updateMeal(Meal updated) async {
    final idx = _meals.indexWhere((m) => m.id == updated.id);
    if (idx == -1) return false;
    _meals[idx] = updated.copyWith(updatedAt: DateTime.now());
    _emit();
    return true;
  }

  Future<int> deleteMeal(int id) async {
    final before = _meals.length;
    _meals.removeWhere((m) => m.id == id);
    final deleted = before - _meals.length;
    if (deleted > 0) {
      _emit();
    }
    return deleted;
  }

  Future<void> toggleFavorite(int id) async {
    final idx = _meals.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final m = _meals[idx];
      _meals[idx] = m.copyWith(isFavorite: !m.isFavorite);
      _emit();
    }
  }

  void dispose() {
    _controller.close();
  }
}

class InMemoryMealHistoryDao {
  final List<MealHistoryData> _history = [];
  final _controller = StreamController<List<MealHistoryData>>.broadcast();
  int _nextId = 1;

  InMemoryMealHistoryDao() {
    _emit();
  }

  void _emit() {
    _controller.add(List.unmodifiable(_history));
  }

  Stream<List<MealHistoryData>> watchHistory() => _controller.stream;

  Future<List<MealHistoryData>> getRecentHistory([int limit = 50]) async {
    final sorted = List<MealHistoryData>.from(_history)
      ..sort((a, b) => b.cookedDate.compareTo(a.cookedDate));
    return sorted.take(limit).toList();
  }

  Future<int> logMeal({
    required int mealId,
    required String mealName,
    required ProteinType protein,
    required CarbsType carbs,
    required DateTime cookedAt,
    required MealHistoryStatus entryType,
    String? notes,
  }) async {
    final id = _nextId++;
    final entry = MealHistoryData(
      id: id,
      mealId: mealId,
      mealName: mealName,
      proteinType: protein,
      carbsType: carbs,
      cookedDate: cookedAt,
      status: entryType,
      notes: notes,
      createdAt: DateTime.now(),
    );
    _history.add(entry);
    _emit();
    return id;
  }

  Future<int> deleteHistoryEntry(int id) async {
    final before = _history.length;
    _history.removeWhere((h) => h.id == id);
    final deleted = before - _history.length;
    if (deleted > 0) {
      _emit();
    }
    return deleted;
  }

  /// Implements SetNull cascade when meal is deleted
  void handleMealDeleted(int mealId) {
    bool changed = false;
    for (int i = 0; i < _history.length; i++) {
      if (_history[i].mealId == mealId) {
        final current = _history[i];
        _history[i] = MealHistoryData(
          id: current.id,
          mealId: null, // Nullified
          mealName: current.mealName,
          proteinType: current.proteinType,
          carbsType: current.carbsType,
          cookedDate: current.cookedDate,
          status: current.status,
          notes: current.notes,
          createdAt: current.createdAt,
        );
        changed = true;
      }
    }
    if (changed) {
      _emit();
    }
  }

  void dispose() {
    _controller.close();
  }
}

class InMemoryAppSettingsDao {
  AppSetting _settings = const AppSetting();
  final _controller = StreamController<AppSetting>.broadcast();

  InMemoryAppSettingsDao() {
    _emit();
  }

  void _emit() {
    _controller.add(_settings);
  }

  Stream<AppSetting> watchSettings() => _controller.stream;

  Future<AppSetting> getSettings() async => _settings;

  Future<void> updateCooldownDays(int days) async {
    final clamped = days.clamp(1, 60);
    _settings = _settings.copyWith(cooldownDays: clamped);
    _emit();
  }

  Future<void> updateThemeMode(AppThemeModePreference mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    _emit();
  }

  Future<void> updateNotificationTime(int hour, int minute) async {
    _settings = _settings.copyWith(
      notificationHour: hour.clamp(0, 23),
      notificationMinute: minute.clamp(0, 59),
    );
    _emit();
  }

  Future<void> toggleNotifications(bool enabled) async {
    _settings = _settings.copyWith(notificationsEnabled: enabled);
    _emit();
  }

  Future<void> updateDietaryRules({bool? preventProtein, bool? preventCarbs}) async {
    _settings = _settings.copyWith(
      preventRepeatProtein: preventProtein ?? _settings.preventRepeatProtein,
      preventRepeatCarbs: preventCarbs ?? _settings.preventRepeatCarbs,
    );
    _emit();
  }

  void dispose() {
    _controller.close();
  }
}

/// Simulated Riverpod-style Coordinator replicating the unidirectional data flow
class AppStateCoordinator {
  final InMemoryMealsDao mealsDao;
  final InMemoryMealHistoryDao historyDao;
  final InMemoryAppSettingsDao settingsDao;
  final RecommendationEngine engine;

  final _recommendationsController = StreamController<RecommendationResult>.broadcast();
  DateTime Function() nowProvider;
  StreamSubscription? _mealsSub;
  StreamSubscription? _historySub;
  StreamSubscription? _settingsSub;

  AppStateCoordinator({
    bool seedDefaults = true,
    DateTime Function()? nowProvider,
  })  : mealsDao = InMemoryMealsDao(seedDefaults: seedDefaults),
        historyDao = InMemoryMealHistoryDao(),
        settingsDao = InMemoryAppSettingsDao(),
        engine = const RecommendationEngine(),
        nowProvider = nowProvider ?? DateTime.now {
    // Listen to changes across all notifiers and auto-recalculate recommendations
    _mealsSub = mealsDao.watchAllMeals().listen((_) => _recalculateRecommendations());
    _historySub = historyDao.watchHistory().listen((_) => _recalculateRecommendations());
    _settingsSub = settingsDao.watchSettings().listen((_) => _recalculateRecommendations());

    _recalculateRecommendations();
  }

  Stream<RecommendationResult> watchRecommendations() =>
      _recommendationsController.stream;

  Future<RecommendationResult> getRecommendations() async {
    final meals = await mealsDao.getAllMeals();
    final history = await historyDao.getRecentHistory();
    final settings = await settingsDao.getSettings();
    return engine.compute(
      meals: meals,
      history: history,
      settings: settings,
      today: nowProvider(),
    );
  }

  Future<void> _recalculateRecommendations() async {
    if (_recommendationsController.isClosed) return;
    final result = await getRecommendations();
    if (!_recommendationsController.isClosed) {
      _recommendationsController.add(result);
    }
  }

  Future<void> deleteMealWithCascade(int mealId) async {
    await mealsDao.deleteMeal(mealId);
    historyDao.handleMealDeleted(mealId);
    await _recalculateRecommendations();
  }

  Future<void> markMealCookedToday(Meal meal, {String? notes}) async {
    await historyDao.logMeal(
      mealId: meal.id,
      mealName: meal.name,
      protein: meal.proteinType,
      carbs: meal.carbsType,
      cookedAt: nowProvider(),
      entryType: MealHistoryStatus.cookedToday,
      notes: notes,
    );
  }

  Future<void> markMealLeftover(Meal meal, {String? notes}) async {
    await historyDao.logMeal(
      mealId: meal.id,
      mealName: meal.name,
      protein: meal.proteinType,
      carbs: meal.carbsType,
      cookedAt: nowProvider(),
      entryType: MealHistoryStatus.leftover,
      notes: notes,
    );
  }

  /// Spin the wheel roulette logic: picks a random eligible candidate
  Future<Meal?> spinTheWheel() async {
    final recs = await getRecommendations();
    if (recs.recommendations.length < 2) {
      return null; // Requires at least 2 candidates
    }
    final randomIndex = DateTime.now().millisecondsSinceEpoch % recs.recommendations.length;
    return recs.recommendations[randomIndex];
  }

  void dispose() {
    _mealsSub?.cancel();
    _historySub?.cancel();
    _settingsSub?.cancel();
    mealsDao.dispose();
    historyDao.dispose();
    settingsDao.dispose();
    if (!_recommendationsController.isClosed) {
      _recommendationsController.close();
    }
  }
}
