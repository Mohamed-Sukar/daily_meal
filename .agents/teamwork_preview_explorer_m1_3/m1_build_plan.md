# Milestone 1: Build Configuration, Dependencies & Database Unit Test Plan

**Agent Identity:** `teamwork_preview_explorer_m1_3`  
**Milestone:** M1 — Core Database & Drift Layer  
**Target Environment:** Flutter 3.44.0 (Android target), Dart 3.12.0  
**Project Root:** `E:\Mohamed\Personal_Project\daily-meal\daily_meal`  
**Status:** Approved for Implementation by Worker  

---

## 1. Executive Summary

This specification delivers the exact configuration, code generation workflows, and database verification testing for **Milestone 1** of the "أكلة النهاردة" (Daily Meal) application:
1. **Dependency Specifications (`pubspec.yaml`)**:
   - Exact runtime and dev dependencies for Drift persistence (`drift`, `drift_flutter`, `sqlite3_flutter_libs`, `path_provider`, `path`) and code generation (`drift_dev`, `build_runner`).
   - Verified 100% dependency resolution compatibility on Flutter 3.44.0 / Dart 3.12.0.
   - Critical technical alert regarding PowerShell caret-escaping causing Flutter SDK `path: 1.9.1` pinning violations when using CLI commands.
2. **Build Configuration (`build.yaml`)**:
   - Drift builder configuration enabling `store_date_time_values_as_text: true`, storing all timestamps as ISO-8601 strings to ensure human readability in SQLite inspectors, robust timezone handling, and avoiding 2038 unix-epoch integer limits.
3. **Code Generation Workflow**:
   - Exact build, watch, and clean commands via `dart run build_runner`.
   - Explicit `part '<filename>.g.dart';` requirements for the database and all three DAOs (`MealsDao`, `MealHistoryDao`, `AppSettingsDao`).
   - Troubleshooting playbook for conflicting outputs and generator cache invalidation.
4. **Comprehensive Unit Test Suite Outline (`test/unit/database_test.dart`)**:
   - In-memory database testing harness utilizing `NativeDatabase.memory()`.
   - 5 comprehensive test groups covering:
     1. Database initialization and seeding on `onCreate` (20 starter Egyptian meals and singleton settings).
     2. Meals Table & `MealsDao` reactive CRUD operations.
     3. MealHistory Table & `MealHistoryDao` chronological logging and entry types (`cooked` vs `leftover`).
     4. Foreign key safety, cascade behavior, and snapshot preservation on meal deletion (`KeyAction.setNull`).
     5. AppSettings Table & `AppSettingsDao` mutations, singleton row integrity, and stream watches.

---

## 2. Dependency Additions (`pubspec.yaml`)

### 2.1 Package Analysis & Rationale

| Package | Category | Version Constraint | Role & Rationale |
|---|---|---|---|
| `drift` | Runtime | `^2.24.0` | Core reactive persistence engine. Provides type-safe SQL, DAOs, schema definitions, and stream queries. |
| `drift_flutter` | Runtime | `^0.2.4` | Official Flutter integration for Drift. Provides `driftDatabase(name: 'daily_meal_db')` helper for zero-boilerplate background isolate connection setup. |
| `sqlite3_flutter_libs` | Runtime | `^0.5.24` | Bundles the latest native SQLite binary across Android (arm64, armv7, x86_64) and desktop platforms. |
| `path_provider` | Runtime | `^2.1.5` | Resolves standard platform file system paths (e.g. app support directory) for SQLite file storage. |
| `path` | Runtime | `^1.9.1` | Path manipulation library. **Crucial:** Flutter SDK `flutter_test` pins `path` to `1.9.1`; constraint must be `^1.9.1` (or unpinned in CLI) to avoid solver conflicts. |
| `build_runner` | Dev | `^2.4.13` | Universal Dart build and code-generation tool orchestrator. |
| `drift_dev` | Dev | `^2.24.0` | Drift code generator. Translates table definitions and DAOs into `.g.dart` data classes and companion objects. |

### 2.2 Critical Platform & CLI Caveats

> **CRITICAL POWERSHELL CLI WARNING:**  
> In Windows PowerShell, running:
> ```powershell
> # DO NOT RUN THIS - PowerShell strips the '^' character!
> flutter pub add drift:^2.24.0 path:^1.9.0
> ```
> In PowerShell, the caret (`^`) is an escape character. When passed unquoted or double-quoted without escaping, PowerShell strips the `^`, converting the argument to `path:1.9.0` (exact version 1.9.0). Because the Flutter 3.44.0 SDK explicitly pins `path: 1.9.1` via `flutter_test`, pub version resolution will fail with:
> `Because every version of flutter_test from sdk depends on path 1.9.1 and daily_meal depends on path 1.9.0, flutter_test from sdk is forbidden.`
>
> **Solution:** Either edit `pubspec.yaml` directly (recommended) or use package names without version flags in CLI:
> ```powershell
> flutter pub add drift drift_flutter sqlite3_flutter_libs path_provider path dev:drift_dev dev:build_runner
> ```

### 2.3 Exact `pubspec.yaml` Modifications for Milestone 1

Edit `pubspec.yaml` at project root:

```yaml
name: daily_meal
description: "أكلة النهاردة - Offline-First Daily Meal Recommender"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # Persistence (Milestone 1)
  drift: ^2.24.0
  drift_flutter: ^0.2.4
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.5
  path: ^1.9.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

  # Code Generation (Milestone 1)
  build_runner: ^2.4.13
  drift_dev: ^2.24.0

flutter:
  uses-material-design: true
```

### 2.4 Verified Full Project Dependencies (Future Milestones Compatibility)

A comprehensive dry-run resolution was executed and verified (`exit code 0`, 92 dependencies resolved) proving that the M1 packages resolve harmoniously with all planned packages for Milestones 2, 3, and 4:
- State Management: `flutter_riverpod: ^3.4.0`, `riverpod_annotation: ^4.0.0`, `riverpod_generator: ^4.0.0`
- Navigation: `go_router: ^17.5.0`
- Notifications: `flutter_local_notifications: ^22.3.0`, `timezone: ^0.11.0`
- Localization: `intl: ^0.20.0`

---

## 3. Drift Builder Configuration (`build.yaml`)

### 3.1 Rationale for `build.yaml`

While Drift can function with zero configuration, introducing `build.yaml` at the project root is essential for production quality:
1. **`store_date_time_values_as_text: true`**:
   - By default, Drift stores `DateTime` as Unix timestamps (integer seconds since epoch).
   - Enabling `store_date_time_values_as_text: true` stores dates as standardized **ISO-8601 strings** (e.g. `2026-09-07T12:00:00.000Z`).
   - **Why this is essential:**
     - Enables direct human readability when inspecting SQLite database files using Android Studio App Inspection or DB Browser for SQLite.
     - Preserves complete timezone offsets and millisecond precision.
     - Prevents integer timestamp overflow and simplifies SQLite string date queries.
2. **`named_parameters: true`**:
   - Ensures generated methods take named parameters for readability and maintainability.
3. **`apply_converters_on_records: true`**:
   - Leverages Dart 3 record syntax when generating type converters.

### 3.2 Exact `build.yaml` Content

Create `build.yaml` in the root directory (`E:\Mohamed\Personal_Project\daily-meal\daily_meal\build.yaml`):

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          store_date_time_values_as_text: true
          named_parameters: true
          apply_converters_on_records: true
```

---

## 4. Code Generation Workflow

### 4.1 Required Source File `part` Directives

Drift requires each file declaring a `@DriftDatabase` or `@DriftAccessor` to include a corresponding `part` directive matching the output filename:

| Source File | Required Part Directive | Generated Artifact |
|---|---|---|
| `lib/core/database/app_database.dart` | `part 'app_database.g.dart';` | `lib/core/database/app_database.g.dart` |
| `lib/core/database/daos/meals_dao.dart` | `part 'meals_dao.g.dart';` | `lib/core/database/daos/meals_dao.g.dart` |
| `lib/core/database/daos/meal_history_dao.dart` | `part 'meal_history_dao.g.dart';` | `lib/core/database/daos/meal_history_dao.g.dart` |
| `lib/core/database/daos/app_settings_dao.dart` | `part 'app_settings_dao.g.dart';` | `lib/core/database/daos/app_settings_dao.g.dart` |

### 4.2 Generation Commands

1. **One-Time Build (Standard for CI / Worker Steps)**:
   ```powershell
   dart run build_runner build --delete-conflicting-outputs
   ```
   *Flags:* `--delete-conflicting-outputs` instructs build_runner to overwrite any stale or conflicting `.g.dart` files without prompting for interactive input.

2. **Continuous Watch Mode (For Active Development)**:
   ```powershell
   dart run build_runner watch --delete-conflicting-outputs
   ```
   *Behavior:* Automatically re-generates `.g.dart` code upon saving any table or DAO modifications.

3. **Cache Invalidation & Clean (If Build Is Corrupted)**:
   ```powershell
   dart run build_runner clean
   dart run build_runner build --delete-conflicting-outputs
   ```
   *Behavior:* Purges `.dart_tool/build` cache and performs a cold re-generation.

---

## 5. Verification Test Suite Outline (`test/unit/database_test.dart`)

### 5.1 In-Memory Test Harness Design

Unit tests must execute rapidly in an isolated, headless environment without persisting files to disk. Drift provides `NativeDatabase.memory()` specifically for this purpose:

```dart
// Test lifecycle structure:
late AppDatabase db;

setUp(() {
  // Fresh in-memory SQLite database per test
  db = AppDatabase(NativeDatabase.memory());
});

tearDown(() async {
  // Graceful cleanup after each test
  await db.close();
});
```

### 5.2 Detailed Test Outline by Group

#### Group 1: Database Initialization & Seeding (`onCreate`)
- **Test 1.1: Seeds Exactly 20 Starter Egyptian Meals on First Open**
  - Verify `await db.mealsDao.getAllMeals()` returns 20 items.
  - Verify essential seed meals are present by name:
    - `'كشري مصري أصلي بالصلصة والدقة'` (legume, rice, egyptianTraditional, budget-friendly).
    - `'ملوخية خضراء بالفراخ المحمرة وأرز بالشعرية'` (chicken, rice).
    - `'صينية بطاطس باللحمة في الفرن وأرز مصري'` (beef, potato).
    - `'سمك بلطي مشوي بالردة ورز صيادية وسلطة بلدي'` (fish, rice, Friday special).
  - Verify default boolean flags (`isFridaySpecial`, `isBudgetFriendly`, `isFavorite`).
- **Test 1.2: Seeds Singleton AppSettings Row with Default Values**
  - Verify `await db.appSettingsDao.getSettings()` returns row with `id = 1`.
  - Verify default parameters:
    - `cooldownDays == 14`
    - `preventRepeatProtein == true`
    - `preventRepeatCarbs == true`
    - `notificationHour == 12`
    - `notificationMinute == 0`
    - `notificationsEnabled == true`
    - `themeMode == AppThemeModePreference.system`

#### Group 2: Meals Table & `MealsDao` CRUD Operations
- **Test 2.1: Insert Meal Returns Valid Generated ID and Emits Stream Event**
  - Insert new custom meal via `MealsCompanion.insert(...)`.
  - Verify returned ID is positive and equals 21 (after the 20 seed meals).
  - Verify `getMealById(21)` returns matching meal data.
- **Test 2.2: Update Meal Properties**
  - Fetch existing meal (e.g. ID 1).
  - Update `name`, `prepTimeMinutes`, or toggle `isFavorite`.
  - Verify `updateMeal` persists modifications.
- **Test 2.3: Reactive Stream `watchAllMeals` Emits Updates**
  - Listen to `db.mealsDao.watchAllMeals()`.
  - Expect initial 20 items.
  - Insert a new meal.
  - Expect second emission containing 21 items.
- **Test 2.4: Delete Meal Removes from Vault**
  - Delete meal ID 20.
  - Verify `getMealById(20)` returns `null`.
  - Verify `getAllMeals()` count decreases by 1.

#### Group 3: MealHistory Table & `MealHistoryDao` Operations
- **Test 3.1: Log Cooked Meal (`MealEntryType.cooked`)**
  - Fetch meal ID 1.
  - Call `db.mealHistoryDao.logMealFromMeal(meal1, cookedAt: DateTime.now(), entryType: MealEntryType.cooked)`.
  - Verify log entry has correct `mealId`, `mealName`, `proteinType`, `carbsType`, and `entryType`.
- **Test 3.2: Log Leftover Meal (`MealEntryType.leftover`)**
  - Call `logMealFromMeal` with `entryType: MealEntryType.leftover`.
  - Verify `entryType` is persisted as `leftover`.
- **Test 3.3: Chronological History Retrieval (`getRecentHistory`)**
  - Insert 3 logs on different dates: today, 3 days ago, 7 days ago.
  - Call `getRecentHistory(limit: 10)`.
  - Verify entries are returned in descending chronological order (newest first).
- **Test 3.4: Delete History Entry (Undo Functionality)**
  - Insert a log entry.
  - Call `deleteHistoryEntry(id)`.
  - Verify entry is removed from history.

#### Group 4: Foreign Key Safety & Snapshot Preservation (Crucial Architecture Rule)
- **Test 4.1: Preserves History Snapshot and Sets `mealId` to Null When Meal Is Deleted**
  - Log a meal history record for meal ID 2 (`ملوخية خضراء بالفراخ المحمرة`).
  - Verify history record has `mealId = 2`, `mealName = 'ملوخية خضراء بالفراخ المحمرة'`, `proteinType = ProteinType.chicken`.
  - Execute `db.mealsDao.deleteMeal(2)`.
  - Verify meal ID 2 is deleted from `meals`.
  - Verify history log still exists in `meal_history`.
  - Verify `mealId` is now `null` (enforcing `KeyAction.setNull`).
  - Verify snapshot fields (`mealName`, `proteinType`, `carbsType`, `cookedAt`) remain completely intact and readable!

#### Group 5: AppSettings Table & `AppSettingsDao` Mutations
- **Test 5.1: Update Cooldown Days Persists and Enforces Positive Values**
  - Call `updateCooldownDays(21)`.
  - Verify `getSettings().cooldownDays == 21`.
- **Test 5.2: Update Theme Mode Preference**
  - Call `updateThemeMode(AppThemeModePreference.dark)`.
  - Verify `getSettings().themeMode == AppThemeModePreference.dark`.
- **Test 5.3: Update Notification Time and Toggle**
  - Call `updateNotificationTime(14, 30)` and `toggleNotifications(false)`.
  - Verify `notificationHour == 14`, `notificationMinute == 30`, `notificationsEnabled == false`.
- **Test 5.4: Singleton Row Integrity**
  - Verify that no matter how many updates are performed, table contains exactly 1 row (`id = 1`).

---

## 6. Complete Verification Test Code (`test/unit/database_test.dart`)

```dart
// test/unit/database_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/tables/meals_table.dart';
import 'package:daily_meal/core/database/tables/meal_history_table.dart';
import 'package:daily_meal/core/database/tables/app_settings_table.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory isolated SQLite instance for every test
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Group 1: Database Initialization & Seeding (onCreate)', () {
    test('seeds exactly 20 starter Egyptian meals on first creation', () async {
      final meals = await db.mealsDao.getAllMeals();
      expect(meals.length, equals(20));

      final koshary = meals.firstWhere((m) => m.name.contains('كشري'));
      expect(koshary.proteinType, equals(ProteinType.legume));
      expect(koshary.carbsType, equals(CarbsType.rice));
      expect(koshary.isBudgetFriendly, isTrue);

      final fish = meals.firstWhere((m) => m.name.contains('سمك بلطي'));
      expect(fish.proteinType, equals(ProteinType.fish));
      expect(fish.isFridaySpecial, isTrue);
    });

    test('seeds singleton AppSettings with default parameters', () async {
      final settings = await db.appSettingsDao.getSettings();
      expect(settings.id, equals(1));
      expect(settings.cooldownDays, equals(14));
      expect(settings.preventRepeatProtein, isTrue);
      expect(settings.preventRepeatCarbs, isTrue);
      expect(settings.notificationHour, equals(12));
      expect(settings.notificationMinute, equals(0));
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.themeMode, equals(AppThemeModePreference.system));
    });
  });

  group('Group 2: Meals Table & MealsDao CRUD Operations', () {
    test('insertMeal creates a new meal and returns valid auto-increment ID', () async {
      final id = await db.mealsDao.insertMeal(
        MealsCompanion.insert(
          name: 'شاورما دجاج سوري بالثومية',
          proteinType: ProteinType.chicken,
          carbsType: CarbsType.bread,
          category: MealCategory.fastFood,
          prepTimeMinutes: 30,
        ),
      );
      expect(id, equals(21));

      final meal = await db.mealsDao.getMealById(21);
      expect(meal, isNotNull);
      expect(meal!.name, equals('شاورما دجاج سوري بالثومية'));
      expect(meal.isFridaySpecial, isFalse);
    });

    test('updateMeal updates existing meal properties', () async {
      final meal = await db.mealsDao.getMealById(1);
      expect(meal, isNotNull);

      final updated = meal!.copyWith(
        name: 'كشري مصري مخصوص مع دقة مضاعفة',
        prepTimeMinutes: 55,
        isFavorite: true,
      );
      final success = await db.mealsDao.updateMeal(updated);
      expect(success, isTrue);

      final reFetched = await db.mealsDao.getMealById(1);
      expect(reFetched!.name, equals('كشري مصري مخصوص مع دقة مضاعفة'));
      expect(reFetched.prepTimeMinutes, equals(55));
      expect(reFetched.isFavorite, isTrue);
    });

    test('watchAllMeals emits stream updates on insertion', () async {
      final stream = db.mealsDao.watchAllMeals();
      
      expectLater(
        stream.map((list) => list.length),
        emitsInOrder([20, 21]),
      );

      await db.mealsDao.insertMeal(
        MealsCompanion.insert(
          name: 'كفتة مشوية على الفحم',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.bread,
          category: MealCategory.ovenBaked,
          prepTimeMinutes: 45,
        ),
      );
    });

    test('deleteMeal removes meal from database', () async {
      final deletedCount = await db.mealsDao.deleteMeal(20);
      expect(deletedCount, equals(1));

      final meal = await db.mealsDao.getMealById(20);
      expect(meal, isNull);

      final allMeals = await db.mealsDao.getAllMeals();
      expect(allMeals.length, equals(19));
    });
  });

  group('Group 3: MealHistory Table & MealHistoryDao Logging', () {
    test('logs cooked meal and leftover meal with distinct entry types', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      final now = DateTime.now();

      final cookedId = await db.mealHistoryDao.logMealFromMeal(
        meal,
        cookedAt: now,
        entryType: MealEntryType.cooked,
      );
      expect(cookedId, greaterThan(0));

      final leftoverId = await db.mealHistoryDao.logMealFromMeal(
        meal,
        cookedAt: now.add(const Duration(days: 1)),
        entryType: MealEntryType.leftover,
      );
      expect(leftoverId, greaterThan(cookedId));

      final history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(2));
      expect(history[0].entryType, equals(MealEntryType.cooked));
      expect(history[1].entryType, equals(MealEntryType.leftover));
    });

    test('getRecentHistory returns entries ordered chronologically descending', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      final t1 = DateTime(2026, 9, 1);
      final t2 = DateTime(2026, 9, 3);
      final t3 = DateTime(2026, 9, 5);

      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: t1);
      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: t3);
      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: t2);

      final recent = await db.mealHistoryDao.getRecentHistory(limit: 10);
      expect(recent.length, equals(3));
      expect(recent[0].cookedAt, equals(t3));
      expect(recent[1].cookedAt, equals(t2));
      expect(recent[2].cookedAt, equals(t1));
    });

    test('deleteHistoryEntry deletes entry for undo support', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      final id = await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: DateTime.now());

      var history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(1));

      await db.mealHistoryDao.deleteHistoryEntry(id);
      history = await db.mealHistoryDao.getAllHistory();
      expect(history, isEmpty);
    });
  });

  group('Group 4: Foreign Key Cascades & Snapshot Preservation', () {
    test('preserves history snapshot and sets mealId to null when meal is deleted', () async {
      final meal = (await db.mealsDao.getMealById(2))!;
      expect(meal.name, contains('ملوخية'));

      await db.mealHistoryDao.logMealFromMeal(
        meal,
        cookedAt: DateTime(2026, 9, 2),
        entryType: MealEntryType.cooked,
        notes: 'عزومة عائلية',
      );

      var history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(1));
      expect(history.first.mealId, equals(2));
      expect(history.first.mealName, equals(meal.name));
      expect(history.first.proteinType, equals(ProteinType.chicken));
      expect(history.first.carbsType, equals(CarbsType.rice));

      // Delete the parent meal
      await db.mealsDao.deleteMeal(2);
      expect(await db.mealsDao.getMealById(2), isNull);

      // Verify history row is preserved with null mealId and intact snapshot fields
      history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(1));
      expect(history.first.mealId, isNull);
      expect(history.first.mealName, contains('ملوخية'));
      expect(history.first.proteinType, equals(ProteinType.chicken));
      expect(history.first.carbsType, equals(CarbsType.rice));
      expect(history.first.notes, equals('عزومة عائلية'));
    });
  });

  group('Group 5: AppSettings Table & AppSettingsDao Mutations', () {
    test('updates cooldown days and persists setting', () async {
      await db.appSettingsDao.updateCooldownDays(21);
      final settings = await db.appSettingsDao.getSettings();
      expect(settings.cooldownDays, equals(21));
    });

    test('updates theme mode preference', () async {
      await db.appSettingsDao.updateThemeMode(AppThemeModePreference.dark);
      final settings = await db.appSettingsDao.getSettings();
      expect(settings.themeMode, equals(AppThemeModePreference.dark));
    });

    test('updates notification time and toggle', () async {
      await db.appSettingsDao.updateNotificationTime(13, 45);
      await db.appSettingsDao.toggleNotifications(false);

      final settings = await db.appSettingsDao.getSettings();
      expect(settings.notificationHour, equals(13));
      expect(settings.notificationMinute, equals(45));
      expect(settings.notificationsEnabled, isFalse);
    });

    test('singleton row integrity is preserved', () async {
      await db.appSettingsDao.updateCooldownDays(7);
      await db.appSettingsDao.updateCooldownDays(14);
      await db.appSettingsDao.updateThemeMode(AppThemeModePreference.light);

      final allRows = await db.select(db.appSettings).get();
      expect(allRows.length, equals(1));
      expect(allRows.first.id, equals(1));
    });
  });
}
```

---

## 7. Step-by-Step Execution Playbook for the Worker

The Worker can execute Milestone 1 following these exact verification steps:

```powershell
# 1. Update pubspec.yaml with dependencies and dev_dependencies
# Run pub get
flutter pub get

# 2. Add build.yaml to root directory
# (Enabling store_date_time_values_as_text: true)

# 3. Create database source files under lib/core/database/
#    - tables/meals_table.dart
#    - tables/meal_history_table.dart
#    - tables/app_settings_table.dart
#    - seed/initial_meals.dart
#    - daos/meals_dao.dart
#    - daos/meal_history_dao.dart
#    - daos/app_settings_dao.dart
#    - app_database.dart

# 4. Run Drift code generator
dart run build_runner build --delete-conflicting-outputs

# 5. Create and run unit tests
flutter test test/unit/database_test.dart

# 6. Verify zero static analysis issues
flutter analyze
```
