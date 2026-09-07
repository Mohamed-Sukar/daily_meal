# Milestone 1: Changes Report

**Identity:** `teamwork_preview_worker_m1`  
**Milestone:** M1 — Core Database & Drift Layer  
**Date:** 2026-09-07T00:14:00+03:00  

---

## 1. Summary of Changes

Milestone 1 implements the complete offline-first persistence layer using Drift SQLite, supporting reactive streams, singleton configuration, foreign key snapshot preservation, and 20 authentic Egyptian starter recipes.

### Files Created / Modified

1. `pubspec.yaml`:
   - Added runtime dependencies: `drift: ^2.24.0`, `drift_flutter: ^0.2.4`, `sqlite3_flutter_libs: ^0.5.24`, `path_provider: ^2.1.5`, `path: ^1.9.1`.
   - Added dev dependencies: `build_runner: ^2.4.13`, `drift_dev: ^2.24.0`.

2. `build.yaml`:
   - Configured Drift builder options: `store_date_time_values_as_text: true`, `named_parameters: true`.

3. `lib/core/database/tables/meals_table.dart`:
   - Defined `Meals` table with columns: `id`, `name`, `photoPath`, `proteinType`, `carbsType`, `category`, `prepTime`, `isFridaySpecial`, `isBudgetFriendly`, `isFavorite`, `createdAt`, `updatedAt`.
   - Defined enums: `ProteinType`, `CarbsType`, `MealCategory`, plus extensions with Arabic labels.

4. `lib/core/database/tables/meal_history_table.dart`:
   - Defined `MealHistory` table with nullable `mealId` foreign key referencing `meals(id)` with `ON DELETE SET NULL`.
   - Defined snapshot columns: `mealName`, `proteinType`, `carbsType`, `cookedAt`, `entryType`, `notes`, `createdAt`.
   - Defined enum: `MealEntryType` (`cooked`, `leftover`) with Arabic label extensions.

5. `lib/core/database/tables/app_settings_table.dart`:
   - Defined singleton `AppSettings` table (`id = 1`) with columns: `cooldownDays`, `preventRepeatProtein`, `preventRepeatCarbs`, `notificationHour`, `notificationMinute`, `notificationsEnabled`, `themeMode`, `isFirstRun`.
   - Defined enum: `AppThemeModePreference` (`system`, `light`, `dark`).

6. `lib/core/database/seed/initial_meals.dart`:
   - Seeded 20 authentic Egyptian starter dishes with complete nutrition tags, prep times, and Friday/Budget/Favorite flags.

7. `lib/core/database/app_database.dart`:
   - Configured `AppDatabase` inheriting from generated `_$AppDatabase`.
   - Production constructor connects via `driftDatabase(name: 'daily_meal_db')`.
   - In-memory constructor accepts optional `QueryExecutor` (for `NativeDatabase.memory()`).
   - `onCreate` migration initializes the singleton `AppSettings` row and bulk inserts all 20 starter meals.
   - `beforeOpen` enables SQLite foreign key enforcement: `PRAGMA foreign_keys = ON`.
   - Added convenience extensions `MealX` (`prepTimeMinutes`), `MealHistoryDataX` (`cookedDate`), and `AppSettingsDataX` (`notificationEnabled`), plus typedef `AppSetting`.
   - Re-exported all table enums, DAOs, and seed catalog.

8. `lib/core/database/daos/meals_dao.dart`:
   - Implemented reactive streams: `watchAllMeals()`, `watchMealById()`, `watchFavorites()`, `watchSearchMeals()`, `watchFilterByTag()`.
   - Implemented snapshot queries: `getAllMeals()`, `getMealById()`, `searchMeals()`, `filterByTag()`.
   - Implemented mutations: `insertMeal()` (with validation for non-empty name and positive prep time), `insertMealsBatch()`, `updateMeal()`, `updateMealCompanion()`, `toggleFavorite()`, `deleteMeal()`, `deleteAllMeals()`.

9. `lib/core/database/daos/meal_history_dao.dart`:
   - Implemented reactive streams: `watchHistory()`, `watchHistoryWithMeal()`, `watchLatestCookedMeal()`.
   - Implemented snapshot queries: `getAllHistory()`, `getRecentHistory()`, `getHistoryWithinDays()`, `getLatestCookedMeal()`.
   - Implemented logging mutations: `logMeal()`, `logMealFromMeal()`, `logCookedMeal()`, `logLeftoverMeal()`.
   - Implemented deletion: `deleteHistoryEntry()`, `deleteHistoryForMeal()`, `clearAllHistory()`.

10. `lib/core/database/daos/app_settings_dao.dart`:
    - Implemented reactive stream: `watchSettings()`.
    - Implemented snapshot getter: `getSettings()`, `ensureSettings()`.
    - Implemented mutators: `updateCooldownDays()` (clamped between 1 and 60), `updateThemeMode()`, `updateNotificationTime()`, `toggleNotifications()`, `updateNotificationsEnabled()`, `togglePreventRepeatProtein()`, `togglePreventRepeatCarbs()`, `updateDietaryRules()`, `updateFirstRun()`, `resetToDefaults()`.

11. `test/unit/database_test.dart`:
    - Implemented comprehensive in-memory test suite with 21 unit tests covering all 5 groups from `m1_build_plan.md`.

---

## 2. Command Execution Evidence

### A. `flutter pub get`
```
Resolving dependencies...
Downloading packages...
...
Got dependencies!
```
Exit code: 0.

### B. `dart run build_runner build`
```
  0s drift_dev on 76 inputs; lib/core/database/app_database.dart
  0s drift_dev on 76 inputs: 1 same; lib/core/database/daos/app_settings_dao.dart
  1s drift_dev on 76 inputs: 58 skipped, 3 output, 13 same, 2 no-op
  0s source_gen:combining_builder on 38 inputs; lib/core/database/app_database.dart
  0s source_gen:combining_builder on 38 inputs: 34 skipped, 2 output, 2 same
  Built with build_runner/aot in 2s; wrote 21 outputs.
```
Exit code: 0 (zero errors, zero warnings).

### C. `flutter test test/unit/database_test.dart`
```
00:00 +0: loading E:/Mohamed/Personal_Project/daily-meal/daily_meal/test/unit/database_test.dart
00:00 +0: Group 1: Database Initialization & Seeding (onCreate) seeds exactly 20 starter Egyptian meals on first creation
00:00 +1: Group 1: Database Initialization & Seeding (onCreate) seeds singleton AppSettings with default parameters
00:00 +2: Group 2: Meals Table & MealsDao CRUD Operations insertMeal creates a new meal and returns valid auto-increment ID
00:00 +3: Group 2: Meals Table & MealsDao CRUD Operations updateMeal updates existing meal properties
00:00 +4: Group 2: Meals Table & MealsDao CRUD Operations toggleFavorite updates favorite flag
00:00 +5: Group 2: Meals Table & MealsDao CRUD Operations watchAllMeals emits stream updates on insertion
00:00 +6: Group 2: Meals Table & MealsDao CRUD Operations deleteMeal removes meal from database
00:00 +7: Group 2: Meals Table & MealsDao CRUD Operations searchMeals finds meals matching query string
00:00 +8: Group 2: Meals Table & MealsDao CRUD Operations filterByTag filters meals by category, protein, and tags
00:00 +9: Group 2: Meals Table & MealsDao CRUD Operations insertMeal throws ArgumentError on empty name or non-positive prepTime
00:00 +10: Group 3: MealHistory Table & MealHistoryDao Logging logs cooked meal and leftover meal with distinct entry types
00:00 +11: Group 3: MealHistory Table & MealHistoryDao Logging getRecentHistory returns entries ordered chronologically descending
00:00 +12: Group 3: MealHistory Table & MealHistoryDao Logging getHistoryWithinDays filters records within date cutoff
00:00 +13: Group 3: MealHistory Table & MealHistoryDao Logging deleteHistoryEntry deletes entry for undo support
00:00 +14: Group 4: Foreign Key Cascades & Snapshot Preservation preserves history snapshot and sets mealId to null when meal is deleted
00:00 +15: Group 5: AppSettings Table & AppSettingsDao Mutations updates cooldown days and clamps between 1 and 60 days
00:00 +16: Group 5: AppSettings Table & AppSettingsDao Mutations updates theme mode preference
00:00 +17: Group 5: AppSettings Table & AppSettingsDao Mutations updates notification time and toggle
00:00 +18: Group 5: AppSettings Table & AppSettingsDao Mutations updates dietary diversity rules
00:00 +19: Group 5: AppSettings Table & AppSettingsDao Mutations singleton row integrity is preserved
00:00 +20: Group 5: AppSettings Table & AppSettingsDao Mutations watchSettings emits updates reactively
00:00 +21: All tests passed!
```
Exit code: 0 (21/21 tests passed, 100% pass rate).

### D. `flutter analyze`
```
Analyzing daily_meal...                                         
No issues found! (ran in 1.6s)
```
Exit code: 0 (0 issues found).
