# Milestone 3: Riverpod State Management Hierarchy & Provider Architecture Blueprint
**App**: أكلة النهاردة (Daily Meal) — Offline-First Egyptian Daily Meal Recommender  
**Document**: `m3_riverpod_plan.md`  
**Status**: Architecture Design & Specification  
**Target Milestone**: Milestone 3 (Presentation Layer & Riverpod State)  
**Dependencies**: Milestone 1 (Drift Database & DAOs), Milestone 2 (CooldownEngine Domain Logic)

---

## 1. Executive Summary & Architectural Vision

The Riverpod state management hierarchy for "أكلة النهاردة" is designed on three fundamental tenets:
1. **Offline-First Reactive Single Source of Truth**: Drift SQLite is the persistent source of truth. All data reads are streamed directly from Drift queries into Riverpod `StreamProvider`s. Any mutation to SQLite immediately broadcasts database updates to active stream subscriptions without requiring manual refresh triggers or polling.
2. **Deterministic Unidirectional Data Flow (UDF)**:
   ```
   [ User Action / UI ] 
          │
          ▼
   [ Mutation Controller (AsyncNotifier) ]
          │ (Executes DAO CRUD / Write)
          ▼
   [ Drift SQLite Database & DAOs ]
          │ (Drift TableUpdate Stream Event)
          ▼
   [ Core StreamProviders (allMeals, mealHistory, appSettings) ]
          │ (Auto-Invalidates & Triggers Recomputation)
          ▼
   [ Derived Domain Provider (recommendationProvider) ]
          │ (Runs CooldownEngine.compute() in microtask)
          ▼
   [ Presentation UI (Home 3-Card Stack, Vault, History, Settings) ]
   ```
3. **Zero-Stale-State Immediate UI Reflection**: When a user adds a meal in the Vault, marks a recommendation as cooked/leftover on the Home Screen, or alters cooldown days in Settings, the downstream UI recalculates within the same frame cycle (0ms latency).

---

## 2. Dependency Management & Package Requirements

For Milestone 3 implementation, the following packages are integrated into `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  go_router: ^14.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
```
*Note*: The architecture uses standard, explicit `flutter_riverpod` (v2.x) patterns (`StreamProvider`, `Provider`, `AsyncNotifier`, `AsyncNotifierProvider`). This eliminates mandatory `build_runner` code generation steps for state changes while remaining 100% compatible with future code generation annotations.

---

## 3. Directory & File Placement Structure

Following `PROJECT.md` layout conventions:
```text
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart
│   │   ├── daos/
│   │   │   ├── app_settings_dao.dart
│   │   │   ├── meal_history_dao.dart
│   │   │   └── meals_dao.dart
│   │   └── database_providers.dart          <-- [NEW] Core Database & DAO Providers
│   ├── router/
│   │   └── app_router.dart                  <-- GoRouter configuration
│   └── services/
│       └── notification_service.dart
├── features/
│   ├── home/
│   │   ├── domain/
│   │   │   └── cooldown_engine.dart
│   │   ├── presentation/
│   │   │   ├── home_screen.dart
│   │   │   └── widgets/
│   │   │       ├── meal_card.dart
│   │   │       ├── quick_actions.dart
│   │   │       └── spin_wheel_dialog.dart
│   │   └── providers/
│   │       └── recommendation_provider.dart <-- [NEW] Domain recommendations & Roulette
│   ├── vault/
│   │   ├── presentation/
│   │   │   ├── add_edit_meal_dialog.dart
│   │   │   ├── meal_vault_screen.dart
│   │   │   └── widgets/
│   │   └── providers/
│   │       └── vault_providers.dart          <-- [NEW] Vault stream, filter & CRUD controller
│   ├── history/
│   │   ├── presentation/
│   │   │   ├── history_screen.dart
│   │   │   └── widgets/
│   │   └── providers/
│   │       └── history_providers.dart        <-- [NEW] History stream & logging controller
│   └── settings/
│       ├── presentation/
│       │   └── settings_screen.dart
│       └── providers/
│           └── settings_providers.dart       <-- [NEW] Settings stream, theme & mutation controller
└── main.dart                                 <-- ProviderScope root setup
```

---

## 4. Detailed Provider Specifications

### 4.1 Core Database Providers (`lib/core/database/database_providers.dart`)

These providers expose the singleton database and accessor DAOs. They are easily overridden in unit and widget tests using `databaseProvider.overrideWithValue(inMemoryDb)`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import 'daos/meals_dao.dart';
import 'daos/meal_history_dao.dart';
import 'daos/app_settings_dao.dart';

/// Singleton Drift AppDatabase provider.
/// Automatically closes the database connection on provider disposal.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Exposes MealsDao from the database instance.
final mealsDaoProvider = Provider<MealsDao>((ref) {
  return ref.watch(databaseProvider).mealsDao;
});

/// Exposes MealHistoryDao from the database instance.
final mealHistoryDaoProvider = Provider<MealHistoryDao>((ref) {
  return ref.watch(databaseProvider).mealHistoryDao;
});

/// Exposes AppSettingsDao from the database instance.
final appSettingsDaoProvider = Provider<AppSettingsDao>((ref) {
  return ref.watch(databaseProvider).appSettingsDao;
});
```

---

### 4.2 StreamProviders (Persistent Drift Streams)

#### A. Vault Streams (`lib/features/vault/providers/vault_providers.dart`)
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

/// Reactive stream watching all meals in the vault ordered alphabetically.
final allMealsProvider = StreamProvider<List<Meal>>((ref) {
  final dao = ref.watch(mealsDaoProvider);
  return dao.watchAllMeals();
});

/// Reactive stream watching only favorite meals.
final favoriteMealsProvider = StreamProvider<List<Meal>>((ref) {
  final dao = ref.watch(mealsDaoProvider);
  return dao.watchFavorites();
});
```

#### B. History Streams (`lib/features/history/providers/history_providers.dart`)
```dart
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
```

#### C. Settings Streams (`lib/features/settings/providers/settings_providers.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';

/// Reactive stream watching the singleton AppSettings row.
final appSettingsProvider = StreamProvider<AppSettingsData>((ref) {
  final dao = ref.watch(appSettingsDaoProvider);
  return dao.watchSettings();
});

/// Derived provider mapping AppThemeModePreference to Flutter's ThemeMode.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settingsAsync = ref.watch(appSettingsProvider);
  return settingsAsync.maybeWhen(
    data: (s) {
      switch (s.themeMode) {
        case AppThemeModePreference.light:
          return ThemeMode.light;
        case AppThemeModePreference.dark:
          return ThemeMode.dark;
        case AppThemeModePreference.system:
          return ThemeMode.system;
      }
    },
    orElse: () => ThemeMode.system,
  );
});
```

---

### 4.3 Domain Recommendations & Roulette Provider (`lib/features/home/providers/recommendation_provider.dart`)

This is the brain of the presentation layer. It consumes `allMealsProvider`, `mealHistoryProvider`, and `appSettingsProvider`, feeding them directly into `CooldownEngine.compute()`.

```dart
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../vault/providers/vault_providers.dart';
import '../../history/providers/history_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../domain/cooldown_engine.dart';

/// Provides the pure Dart CooldownEngine instance.
final engineProvider = Provider<CooldownEngine>((ref) {
  return const CooldownEngine();
});

/// Overridable provider for current DateTime (enables deterministic time traveling in tests).
final currentTimeProvider = Provider<DateTime>((ref) {
  return DateTime.now();
});

/// Primary derived domain provider returning full recommendation result (top 3 meals + metadata).
final recommendationProvider = Provider<AsyncValue<RecommendationResult<Meal>>>((ref) {
  final mealsAsync = ref.watch(allMealsProvider);
  final historyAsync = ref.watch(mealHistoryProvider);
  final settingsAsync = ref.watch(appSettingsProvider);
  final engine = ref.watch(engineProvider);
  final now = ref.watch(currentTimeProvider);

  // 1. Propagate Loading State if any dependency is initial loading
  if (mealsAsync.isLoading || historyAsync.isLoading || settingsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  // 2. Propagate Errors if any dependency failed
  if (mealsAsync.hasError) {
    return AsyncValue.error(mealsAsync.error!, mealsAsync.stackTrace!);
  }
  if (historyAsync.hasError) {
    return AsyncValue.error(historyAsync.error!, historyAsync.stackTrace!);
  }
  if (settingsAsync.hasError) {
    return AsyncValue.error(settingsAsync.error!, settingsAsync.stackTrace!);
  }

  final meals = mealsAsync.valueOrNull ?? const [];
  final history = historyAsync.valueOrNull ?? const [];
  final settings = settingsAsync.valueOrNull ?? AppSettingsDao.defaultSettings;

  // 3. Compute recommendations via CooldownEngine
  try {
    final result = engine.compute<Meal>(
      meals: meals,
      history: history,
      settings: settings,
      today: now,
    );
    return AsyncValue.data(result);
  } catch (err, st) {
    return AsyncValue.error(err, st);
  }
});

/// Convenience alias exposing List<Meal> for UI components that only need the 3 cards.
final todayRecommendationsProvider = Provider<AsyncValue<List<Meal>>>((ref) {
  return ref.watch(recommendationProvider).whenData((r) => r.recommendations);
});

/// Provider for Spin the Wheel Roulette candidate pool.
/// Requires at least 2 distinct recommendation candidates; otherwise returns empty list (disabled).
final spinWheelCandidatesProvider = Provider<List<Meal>>((ref) {
  final recsAsync = ref.watch(todayRecommendationsProvider);
  final recs = recsAsync.valueOrNull ?? const [];
  if (recs.length < 2) {
    return const []; // Tier 2 invariant: Wheel disabled when candidates < 2
  }
  return recs;
});

/// Controller handling Spin the Wheel randomization
class HomeController {
  final Ref _ref;
  HomeController(this._ref);

  /// Spins the wheel and returns a randomly selected eligible meal, or null if < 2 candidates.
  Meal? spinTheWheel() {
    final candidates = _ref.read(spinWheelCandidatesProvider);
    if (candidates.length < 2) return null;
    final randomIndex = Random().nextInt(candidates.length);
    return candidates[randomIndex];
  }
}

final homeControllerProvider = Provider<HomeController>((ref) {
  return HomeController(ref);
});
```

---

## 5. Mechanism of Immediate Reactivity

The UI reactivity operates strictly through SQLite table update notifications propagated via Riverpod:

```
[User taps "طبخت دي النهاردة" / "Add Meal" / "Change Cooldown"]
                        │
                        ▼
   [Controller invokes DAO method: insertMeal / logMeal / updateCooldownDays]
                        │
                        ▼
   [Drift writes row to SQLite and executes: PRAGMA table_info / notifyUpdates]
                        │
                        ▼
   [Drift Query Stream catches table dirty flag and pushes fresh Query result]
                        │
                        ▼
   [StreamProvider receives new List<Meal> or List<MealHistoryData> or AppSetting]
                        │
                        ▼
   [recommendationProvider ref.watch() dependencies detect emission]
                        │
                        ▼
   [CooldownEngine.compute() evaluates 5-level degradation cascade]
                        │
                        ▼
   [Home Screen 3-Card Stack ConsumerWidget re-renders with fresh cards]
```

### Reactivity Guarantees:
1. **Zero Manual Refreshing**: No `setState()`, no `ref.refresh()`, and no manual callbacks are required when logging meals or adding meals.
2. **Instant Cooldown Enforcement**: When a meal is marked "Cooked Today", it immediately enters the cooldown exclusion window. `recommendationProvider` recomputes and immediately replaces the card with the next eligible candidate.
3. **Instant Undo / Deletion Recovery**: When an accidental history entry is deleted from the History screen, `mealHistoryProvider` immediately pushes the updated history, and `recommendationProvider` instantly restores the meal back into the candidate pool.
4. **Dynamic Cooldown Slider Adjustment**: When the user slides cooldown days from 14 down to 3 days, meals cooked 4 days ago instantly become eligible and reappear in recommendations without leaving the screen.

---

## 6. Mutation Notifiers / Controllers Specification

To separate UI presentation from business operations, mutation controllers are implemented using Riverpod's `AsyncNotifier<void>`. This provides automatic loading state tracking, error handling, and testability.

### 6.1 VaultController (`lib/features/vault/providers/vault_providers.dart`)

Handles all Meal Vault CRUD operations.

```dart
class VaultController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Inserts a new meal into the vault.
  /// Validates non-empty name and positive preparation time.
  Future<int> addMeal({
    required String name,
    required ProteinType proteinType,
    required CarbsType carbsType,
    required MealCategory category,
    required int prepTimeMinutes,
    String? photoPath,
    bool isFridaySpecial = false,
    bool isBudgetFriendly = false,
    bool isFavorite = false,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Meal name cannot be empty');
    }
    if (prepTimeMinutes <= 0) {
      throw ArgumentError('Prep time must be positive');
    }

    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealsDaoProvider);
      final id = await dao.insertMeal(
        MealsCompanion(
          name: Value(cleanName),
          proteinType: Value(proteinType),
          carbsType: Value(carbsType),
          category: Value(category),
          prepTime: Value(prepTimeMinutes),
          photoPath: Value(photoPath),
          isFridaySpecial: Value(isFridaySpecial),
          isBudgetFriendly: Value(isBudgetFriendly),
          isFavorite: Value(isFavorite),
        ),
      );
      state = const AsyncValue.data(null);
      return id;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Updates an existing meal entity.
  Future<bool> updateMeal(Meal meal) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealsDaoProvider);
      final success = await dao.updateMeal(meal);
      state = const AsyncValue.data(null);
      return success;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Deletes a meal from the vault.
  /// SQLite foreign key 'ON DELETE SET NULL' preserves existing history records.
  Future<int> deleteMeal(int id) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(mealsDaoProvider);
      final deleted = await dao.deleteMeal(id);
      state = const AsyncValue.data(null);
      return deleted;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Toggles favorite status of a meal.
  Future<void> toggleFavorite(int id, [bool? currentStatus]) async {
    try {
      final dao = ref.read(mealsDaoProvider);
      await dao.toggleFavorite(id, currentStatus);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }
}

final vaultControllerProvider = AsyncNotifierProvider<VaultController, void>(() {
  return VaultController();
});
```

#### Vault Search & Filter Providers:
```dart
/// Filter state model for the Meal Vault list.
class VaultFilterState {
  final String searchQuery;
  final ProteinType? proteinType;
  final CarbsType? carbsType;
  final MealCategory? category;
  final bool? isFavoriteOnly;
  final bool? isFridaySpecialOnly;
  final bool? isBudgetFriendlyOnly;
  final int? maxPrepTime;

  const VaultFilterState({
    this.searchQuery = '',
    this.proteinType,
    this.carbsType,
    this.category,
    this.isFavoriteOnly,
    this.isFridaySpecialOnly,
    this.isBudgetFriendlyOnly,
    this.maxPrepTime,
  });

  VaultFilterState copyWith({
    String? searchQuery,
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFavoriteOnly,
    bool? isFridaySpecialOnly,
    bool? isBudgetFriendlyOnly,
    int? maxPrepTime,
  }) {
    return VaultFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      proteinType: proteinType ?? this.proteinType,
      carbsType: carbsType ?? this.carbsType,
      category: category ?? this.category,
      isFavoriteOnly: isFavoriteOnly ?? this.isFavoriteOnly,
      isFridaySpecialOnly: isFridaySpecialOnly ?? this.isFridaySpecialOnly,
      isBudgetFriendlyOnly: isBudgetFriendlyOnly ?? this.isBudgetFriendlyOnly,
      maxPrepTime: maxPrepTime ?? this.maxPrepTime,
    );
  }
}

final vaultFilterProvider = StateProvider<VaultFilterState>((ref) {
  return const VaultFilterState();
});

/// In-memory filtered stream of meals based on user search query and filter chips.
final filteredVaultMealsProvider = Provider<AsyncValue<List<Meal>>>((ref) {
  final allMealsAsync = ref.watch(allMealsProvider);
  final filter = ref.watch(vaultFilterProvider);

  return allMealsAsync.whenData((meals) {
    return meals.where((meal) {
      if (filter.searchQuery.trim().isNotEmpty) {
        if (!meal.name.contains(filter.searchQuery.trim())) return false;
      }
      if (filter.proteinType != null && meal.proteinType != filter.proteinType) {
        return false;
      }
      if (filter.carbsType != null && meal.carbsType != filter.carbsType) {
        return false;
      }
      if (filter.category != null && meal.category != filter.category) {
        return false;
      }
      if (filter.isFavoriteOnly == true && !meal.isFavorite) {
        return false;
      }
      if (filter.isFridaySpecialOnly == true && !meal.isFridaySpecial) {
        return false;
      }
      if (filter.isBudgetFriendlyOnly == true && !meal.isBudgetFriendly) {
        return false;
      }
      if (filter.maxPrepTime != null && meal.prepTime > filter.maxPrepTime!) {
        return false;
      }
      return true;
    }).toList();
  });
});
```

---

### 6.2 HistoryController (`lib/features/history/providers/history_providers.dart`)

Handles recording cooked and leftover meals and deleting history logs.

```dart
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
        cookedAt: cookedAt ?? ref.read(currentTimeProvider),
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
        cookedAt: cookedAt ?? ref.read(currentTimeProvider),
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
```

---

### 6.3 SettingsController (`lib/features/settings/providers/settings_providers.dart`)

Handles user configuration mutations.

```dart
class SettingsController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Updates cooldown window in days (clamped 1 to 60 days).
  Future<void> updateCooldownDays(int days) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateCooldownDays(days);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Updates application theme mode (System / Light / Dark).
  Future<void> updateThemeMode(AppThemeModePreference mode) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateThemeMode(mode);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Updates daily notification reminder time.
  Future<void> updateNotificationTime(int hour, int minute) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateNotificationTime(hour, minute);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Toggles daily notification reminder status.
  Future<void> toggleNotifications(bool enabled) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.toggleNotifications(enabled);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Updates dietary repeat prevention rules (protein / carbs).
  Future<void> updateDietaryRules({bool? preventProtein, bool? preventCarbs}) async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.updateDietaryRules(preventProtein: preventProtein, preventCarbs: preventCarbs);
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Resets settings to default values.
  Future<void> resetToDefaults() async {
    state = const AsyncValue.loading();
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.resetToDefaults();
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }
}

final settingsControllerProvider = AsyncNotifierProvider<SettingsController, void>(() {
  return SettingsController();
});
```

---

## 7. Presentation UI Integration & Code Snippets

### 7.1 Home Screen 3-Card Stack & Quick Actions
In `lib/features/home/presentation/home_screen.dart`:
```dart
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(recommendationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('أكلة النهاردة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino),
            tooltip: 'عجلة الحظ',
            onPressed: () => _openSpinWheelDialog(context, ref),
          ),
        ],
      ),
      body: recsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('حدث خطأ: $err')),
        data: (result) {
          if (result.recommendations.isEmpty) {
            return const Center(child: Text('لا توجد وجبات في بنك الوجبات!'));
          }
          return Column(
            children: [
              if (result.relaxationLevel > 0)
                Container(
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    result.relaxationReason,
                    style: TextStyle(color: Colors.brown.shade800),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: result.recommendations.length,
                  itemBuilder: (context, index) {
                    final meal = result.recommendations[index];
                    return MealCard(
                      meal: meal,
                      onCooked: () async {
                        await ref.read(historyControllerProvider.notifier)
                            .logCookedMeal(meal);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('بالهنا والشفا! تم تسجيل ${meal.name}')),
                        );
                      },
                      onLeftover: () async {
                        await ref.read(historyControllerProvider.notifier)
                            .logLeftoverMeal(meal);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم تسجيل ${meal.name} كبواقي أكل')),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openSpinWheelDialog(BuildContext context, WidgetRef ref) {
    final candidates = ref.read(spinWheelCandidatesProvider);
    if (candidates.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عجلة الحظ تحتاج إلى وجبتين على الأقل في الاقتراحات!')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => const SpinWheelDialog(),
    );
  }
}
```

### 7.2 Root Application Setup (`lib/main.dart`)
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: DailyMealApp(),
    ),
  );
}

class DailyMealApp extends ConsumerWidget {
  const DailyMealApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'أكلة النهاردة',
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
```

---

## 8. Verification & Testing Blueprint

To independently verify this Riverpod architecture without requiring the full UI build:

### 8.1 Unit & Container Reactivity Test Specification
Create `test/unit/riverpod_container_reactivity_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/database_providers.dart';
import 'package:daily_meal/features/vault/providers/vault_providers.dart';
import 'package:daily_meal/features/history/providers/history_providers.dart';
import 'package:daily_meal/features/settings/providers/settings_providers.dart';
import 'package:daily_meal/features/home/providers/recommendation_provider.dart';

void main() {
  group('Riverpod Provider Reactivity Verification', () {
    late AppDatabase inMemoryDb;
    late ProviderContainer container;

    setUp(() async {
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      // Seed default settings and meals
      await inMemoryDb.appSettingsDao.ensureSettings();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await inMemoryDb.close();
    });

    test('1. allMealsProvider emits when VaultController.addMeal is called', () async {
      final sub = container.listen(allMealsProvider, (_, __) {});
      
      final initialMeals = await container.read(allMealsProvider.future);
      expect(initialMeals.isEmpty, isTrue);

      // Add meal via controller
      await container.read(vaultControllerProvider.notifier).addMeal(
        name: 'طاجن مكرونة باللحمة',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.pasta,
        category: MealCategory.ovenBaked,
        prepTimeMinutes: 45,
      );

      final updatedMeals = await container.read(allMealsProvider.future);
      expect(updatedMeals.length, equals(1));
      expect(updatedMeals.first.name, equals('طاجن مكرونة باللحمة'));
      sub.close();
    });

    test('2. recommendationProvider automatically updates when meal is marked cooked', () async {
      // Insert 5 meals
      final mealId = await container.read(vaultControllerProvider.notifier).addMeal(
        name: 'شاورما دجاج',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.bread,
        category: MealCategory.fastFood,
        prepTimeMinutes: 30,
      );
      final meal = await inMemoryDb.mealsDao.getMealById(mealId);

      // Listen to recommendationProvider
      final sub = container.listen(recommendationProvider, (_, __) {});
      
      // Wait for initial recommendation to reflect
      await container.read(allMealsProvider.future);
      var recs = container.read(recommendationProvider).value?.recommendations ?? [];
      expect(recs.any((m) => m.id == meal!.id), isTrue);

      // Mark meal cooked
      await container.read(historyControllerProvider.notifier).logCookedMeal(meal!);

      // Wait for history stream
      await container.read(mealHistoryProvider.future);
      
      // Verify recommendationProvider immediately removed the cooked meal
      recs = container.read(recommendationProvider).value?.recommendations ?? [];
      expect(recs.any((m) => m.id == meal.id), isFalse);
      sub.close();
    });
  });
}
```

---

## 9. Next Steps for Implementation (Milestone 3 Execution)
1. Add `flutter_riverpod: ^2.6.1` and `go_router: ^14.8.1` to `pubspec.yaml`.
2. Implement `database_providers.dart` in `lib/core/database/`.
3. Implement `vault_providers.dart`, `history_providers.dart`, `settings_providers.dart`, and `recommendation_provider.dart`.
4. Run `test/widget/riverpod_reactivity_test.dart` and `flutter test` to ensure 100% pass across all tiers.
5. Proceed to build UI presentation screens (Home 3-card stack, Spin the Wheel dialog, Vault Screen, Add/Edit dialog).
