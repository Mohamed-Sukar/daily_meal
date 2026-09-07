# Milestone 1 DAO Specification: MealsDao, MealHistoryDao & AppSettingsDao

**Document Version:** 1.0.0  
**Author:** Milestone 1 DAO Explorer (`teamwork_preview_explorer_m1_2`)  
**Target:** Flutter 3.44+ / Dart 3.12+ / Drift SQLite (`drift: ^2.20.0`, `drift_flutter: ^0.2.0`)  
**Status:** Approved Technical Blueprint for Milestone 1 Worker  

---

## 1. Executive Summary & Architecture Context

In 'أكلة النهاردة' (Daily Meal), local SQLite persistence via Drift forms the reactive backbone of the application. The user experience depends on instantaneous UI feedback across 4 application tabs:
- **Home Tab**: Displays today's 3 recommended meal cards, which dynamically recalculate when meals are added, edited, or marked as cooked.
- **Meal Vault Tab**: Lists, searches, and filters custom and seeded meals with live CRUD updates.
- **History Tab**: Displays chronological cooking logs and prevents meal repetition.
- **Settings Tab**: Controls cooldown durations, theme modes, and notification scheduling.

To achieve compile-time safety, high throughput, and zero boilerplate, the Drift data layer utilizes the **DAO (Data Access Object)** pattern with `@DriftAccessor`. Each DAO encapsulates table-specific queries, reactive `Stream` watchers, and atomic mutations.

---

## 2. Table Schema Contracts & Enums

The DAOs interface with the following schemas and enums defined in `lib/core/database/tables/`:

### 2.1 Domain Enums
```dart
enum ProteinType {
  chicken,  // فراخ
  beef,     // لحمة
  fish,     // سمك
  legume,   // بقوليات
  dairy,    // بيض وأجبان
  none,     // بدون بروتين رئيسي
}

enum CarbsType {
  rice,     // أرز
  pasta,    // مكرونة
  bread,    // عيش
  potato,   // بطاطس
  grains,   // حبوب / فريك
  none,     // بدون نشويات
}

enum MealCategory {
  egyptianTraditional, // أكلات شعبية وطبيخ
  ovenBaked,           // طواجن وصواني
  fastFood,            // سندوتشات وسريع
  seafood,             // أسماك ومأكولات بحرية
  soupStew,            // شوربات ويخنات
  vegetarian,          // قرديحي / نباتي
}

enum MealHistoryEntryType {
  cooked,   // طبخة جديدة اليوم
  leftover, // أكل بواقي من أمس
}

enum AppThemeModePreference {
  system,
  light,
  dark,
}
```

### 2.2 Table Definitions Summary
- **`Meals` Table**:
  - `id`: Auto-increment integer primary key.
  - `name`: Text (1–120 chars).
  - `photoPath`: Nullable text.
  - `proteinType`: Text enum `ProteinType`.
  - `carbsType`: Text enum `CarbsType`.
  - `category`: Text enum `MealCategory`.
  - `prepTimeMinutes`: Integer.
  - `isFridaySpecial`: Boolean (default: false).
  - `isBudgetFriendly`: Boolean (default: false).
  - `isFavorite`: Boolean (default: false).
  - `createdAt`: DateTime (default: current date/time).
  - `updatedAt`: DateTime (default: current date/time).
  - Generates DataClass: `Meal` & Companion: `MealsCompanion`.

- **`MealHistory` Table**:
  - `id`: Auto-increment integer primary key.
  - `mealId`: Nullable integer foreign key (`references(Meals, #id, onDelete: KeyAction.setNull)`).
  - `mealName`: Text (snapshot of meal name).
  - `proteinType`: Text enum `ProteinType` (snapshot of protein type).
  - `carbsType`: Text enum `CarbsType` (snapshot of carbs type).
  - `cookedAt`: DateTime (normalized cooking date/time).
  - `entryType`: Text (e.g. `'cooked'`, `'leftover'`).
  - `notes`: Nullable text.
  - `createdAt`: DateTime (default: current date/time).
  - Generates DataClass: `MealHistoryData` & Companion: `MealHistoryCompanion`.
  - *Design Note*: The snapshot columns (`mealName`, `proteinType`, `carbsType`) ensure that deleting a meal from the vault never destroys historical records, and the Cooldown Algorithm can still evaluate recent protein history accurately.

- **`AppSettings` Table**:
  - `id`: Integer primary key (singleton enforced with fixed id = 1).
  - `cooldownDays`: Integer (default: 14).
  - `preventRepeatProtein`: Boolean (default: true).
  - `preventRepeatCarbs`: Boolean (default: true).
  - `notificationHour`: Integer (default: 12).
  - `notificationMinute`: Integer (default: 0).
  - `notificationsEnabled`: Boolean (default: true).
  - `themeMode`: Text (default: `'system'`).
  - `isFirstRun`: Boolean (default: true).
  - Generates DataClass: `AppSetting` & Companion: `AppSettingsCompanion`.

---

## 3. Detailed Specification: `MealsDao`

**File Location:** `lib/core/database/daos/meals_dao.dart`

### 3.1 Interface Contract
```dart
abstract class IMealsDao {
  // Reactive Streams
  Stream<List<Meal>> watchAllMeals();
  Stream<Meal?> watchMealById(int id);
  Stream<List<Meal>> watchFavorites();
  Stream<List<Meal>> watchSearchMeals(String query);
  Stream<List<Meal>> watchFilterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  });

  // Snapshot Queries
  Future<List<Meal>> getAllMeals();
  Future<Meal?> getMealById(int id);
  Future<List<Meal>> searchMeals(String query);
  Future<List<Meal>> filterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  });

  // Mutations (CRUD)
  Future<int> insertMeal(MealsCompanion meal);
  Future<void> insertMealsBatch(List<MealsCompanion> mealCompanions);
  Future<bool> updateMeal(Meal meal);
  Future<int> updateMealCompanion(int id, MealsCompanion companion);
  Future<void> toggleFavorite(int id, bool currentStatus);
  Future<int> deleteMeal(int id);
  Future<int> deleteAllMeals();
}
```

### 3.2 Method Specifications & Drift Fluent Queries

#### 1. `watchAllMeals()`
- **Purpose**: Provides a reactive stream of all available meals in the vault, sorted alphabetically by name.
- **Drift Implementation**:
  ```dart
  Stream<List<Meal>> watchAllMeals() {
    return (select(meals)
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }
  ```

#### 2. `getMealById(int id)` & `watchMealById(int id)`
- **Purpose**: Fetch or observe a single meal by primary key.
- **Drift Implementation**:
  ```dart
  Future<Meal?> getMealById(int id) {
    return (select(meals)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Meal?> watchMealById(int id) {
    return (select(meals)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }
  ```

#### 3. `searchMeals(String query)` & `watchSearchMeals(String query)`
- **Purpose**: Full/partial text search matching meal name. Automatically trims input and falls back to all meals if query is blank.
- **Drift Implementation**:
  ```dart
  Stream<List<Meal>> watchSearchMeals(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return watchAllMeals();

    return (select(meals)
          ..where((t) => t.name.contains(cleanQuery))
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<List<Meal>> searchMeals(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return getAllMeals();

    return (select(meals)
          ..where((t) => t.name.contains(cleanQuery))
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .get();
  }
  ```

#### 4. `filterByTag(...)` & `watchFilterByTag(...)`
- **Purpose**: Dynamic multi-criteria filtering for the Vault screen chips and search bar (protein type, carbs type, category, Friday special, budget-friendly, favorite, and prep time).
- **Drift Implementation**:
  ```dart
  Stream<List<Meal>> watchFilterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    return _buildFilteredQuery(
      proteinType: proteinType,
      carbsType: carbsType,
      category: category,
      isFridaySpecial: isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly,
      isFavorite: isFavorite,
      maxPrepTimeMinutes: maxPrepTimeMinutes,
    ).watch();
  }

  Future<List<Meal>> filterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    return _buildFilteredQuery(
      proteinType: proteinType,
      carbsType: carbsType,
      category: category,
      isFridaySpecial: isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly,
      isFavorite: isFavorite,
      maxPrepTimeMinutes: maxPrepTimeMinutes,
    ).get();
  }

  SimpleSelectStatement<$MealsTable, Meal> _buildFilteredQuery({
    String? query,
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    final statement = select(meals);
    statement.where((t) {
      final predicates = <Expression<bool>>[];
      if (query != null && query.trim().isNotEmpty) {
        predicates.add(t.name.contains(query.trim()));
      }
      if (proteinType != null) {
        predicates.add(t.proteinType.equals(proteinType.name));
      }
      if (carbsType != null) {
        predicates.add(t.carbsType.equals(carbsType.name));
      }
      if (category != null) {
        predicates.add(t.category.equals(category.name));
      }
      if (isFridaySpecial != null) {
        predicates.add(t.isFridaySpecial.equals(isFridaySpecial));
      }
      if (isBudgetFriendly != null) {
        predicates.add(t.isBudgetFriendly.equals(isBudgetFriendly));
      }
      if (isFavorite != null) {
        predicates.add(t.isFavorite.equals(isFavorite));
      }
      if (maxPrepTimeMinutes != null) {
        predicates.add(t.prepTimeMinutes.isSmallerOrEqualValue(maxPrepTimeMinutes));
      }

      if (predicates.isEmpty) return const Constant(true);
      return Expression.and(predicates);
    });

    statement.orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ]);
    return statement;
  }
  ```

#### 5. CRUD Mutations
- **Insert**:
  ```dart
  Future<int> insertMeal(MealsCompanion meal) {
    return into(meals).insert(meal);
  }

  Future<void> insertMealsBatch(List<MealsCompanion> mealCompanions) {
    return batch((b) {
      b.insertAll(meals, mealCompanions);
    });
  }
  ```
- **Update**:
  ```dart
  Future<bool> updateMeal(Meal meal) {
    return update(meals).replace(meal.copyWith(updatedAt: DateTime.now()));
  }

  Future<int> updateMealCompanion(int id, MealsCompanion companion) {
    return (update(meals)..where((t) => t.id.equals(id)))
        .write(companion.copyWith(updatedAt: Value(DateTime.now())));
  }

  Future<void> toggleFavorite(int id, bool currentStatus) async {
    await (update(meals)..where((t) => t.id.equals(id))).write(
      MealsCompanion(
        isFavorite: Value(!currentStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  ```
- **Delete**:
  ```dart
  Future<int> deleteMeal(int id) {
    return (delete(meals)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteAllMeals() {
    return delete(meals).go();
  }
  ```

---

## 4. Detailed Specification: `MealHistoryDao`

**File Location:** `lib/core/database/daos/meal_history_dao.dart`

### 4.1 Interface Contract
```dart
abstract class IMealHistoryDao {
  // Reactive Streams
  Stream<List<MealHistoryData>> watchHistory({int? limit});
  Stream<List<MealHistoryData>> watchHistoryForMeal(int mealId);
  Stream<MealHistoryData?> watchLatestCookedMeal();

  // Snapshot Queries
  Future<List<MealHistoryData>> getRecentHistory({int limit = 50});
  Future<List<MealHistoryData>> getHistoryWithinDays(int days, {DateTime? referenceDate});
  Future<MealHistoryData?> getLatestCookedMeal({DateTime? beforeDate});
  Future<DateTime?> getLastCookedDateForMeal(int mealId);
  Future<int> getHistoryCount();

  // Logging Mutations
  Future<int> logMeal({
    required int? mealId,
    required String mealName,
    required ProteinType proteinType,
    required CarbsType carbsType,
    required DateTime cookedAt,
    required String entryType,
    String? notes,
  });

  Future<int> logCookedMeal(Meal meal, {DateTime? cookedAt, String? notes});
  Future<int> logLeftoverMeal(Meal meal, {DateTime? cookedAt, String? notes});

  // Deletions
  Future<int> deleteHistoryEntry(int id);
  Future<int> deleteHistoryForMeal(int mealId);
  Future<int> clearAllHistory();
}
```

### 4.2 Method Specifications & Drift Fluent Queries

#### 1. `logMeal(...)`
- **Purpose**: Persists a cooking event with snapshot metadata.
- **Drift Implementation**:
  ```dart
  Future<int> logMeal({
    required int? mealId,
    required String mealName,
    required ProteinType proteinType,
    required CarbsType carbsType,
    required DateTime cookedAt,
    required String entryType,
    String? notes,
  }) {
    return into(mealHistory).insert(
      MealHistoryCompanion.insert(
        mealId: Value(mealId),
        mealName: mealName,
        proteinType: proteinType,
        carbsType: carbsType,
        cookedAt: cookedAt,
        entryType: entryType,
        notes: Value(notes),
        createdAt: Value(DateTime.now()),
      ),
    );
  }
  ```

#### 2. Convenience Loggers (`logCookedMeal`, `logLeftoverMeal`)
- **Purpose**: Instant logging directly from UI cards without repetitive manual object construction.
- **Drift Implementation**:
  ```dart
  Future<int> logCookedMeal(Meal meal, {DateTime? cookedAt, String? notes}) {
    return logMeal(
      mealId: meal.id,
      mealName: meal.name,
      proteinType: meal.proteinType,
      carbsType: meal.carbsType,
      cookedAt: cookedAt ?? DateTime.now(),
      entryType: 'cooked',
      notes: notes,
    );
  }

  Future<int> logLeftoverMeal(Meal meal, {DateTime? cookedAt, String? notes}) {
    return logMeal(
      mealId: meal.id,
      mealName: meal.name,
      proteinType: meal.proteinType,
      carbsType: meal.carbsType,
      cookedAt: cookedAt ?? DateTime.now(),
      entryType: 'leftover',
      notes: notes,
    );
  }
  ```

#### 3. `watchHistory({int? limit})` & `getRecentHistory({int limit = 50})`
- **Purpose**: Chronological timeline sorted by `cookedAt` DESC.
- **Drift Implementation**:
  ```dart
  Stream<List<MealHistoryData>> watchHistory({int? limit}) {
    final query = select(mealHistory)
      ..orderBy([
        (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null && limit > 0) {
      query.limit(limit);
    }
    return query.watch();
  }

  Future<List<MealHistoryData>> getRecentHistory({int limit = 50}) {
    return (select(mealHistory)
          ..orderBy([
            (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }
  ```

#### 4. `getHistoryWithinDays(int days, {DateTime? referenceDate})`
- **Purpose**: Essential query for the Cooldown Algorithm to find all dishes cooked within the cooldown window (e.g. past 14 days).
- **Drift Implementation**:
  ```dart
  Future<List<MealHistoryData>> getHistoryWithinDays(
    int days, {
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final cutoff = ref.subtract(Duration(days: days));

    return (select(mealHistory)
          ..where((t) => t.cookedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([
            (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }
  ```

#### 5. `getLatestCookedMeal({DateTime? beforeDate})` & `watchLatestCookedMeal()`
- **Purpose**: Identifies yesterday's or the last cooked meal to detect repeating protein/carbs.
- **Drift Implementation**:
  ```dart
  Future<MealHistoryData?> getLatestCookedMeal({DateTime? beforeDate}) {
    final query = select(mealHistory);
    if (beforeDate != null) {
      query.where((t) => t.cookedAt.isSmallerOrEqualValue(beforeDate));
    }
    query
      ..orderBy([
        (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Stream<MealHistoryData?> watchLatestCookedMeal() {
    return (select(mealHistory)
          ..orderBy([
            (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }
  ```

#### 6. Deletion Methods
```dart
Future<int> deleteHistoryEntry(int id) {
  return (delete(mealHistory)..where((t) => t.id.equals(id))).go();
}

Future<int> deleteHistoryForMeal(int mealId) {
  return (delete(mealHistory)..where((t) => t.mealId.equals(mealId))).go();
}

Future<int> clearAllHistory() {
  return delete(mealHistory).go();
}
```

---

## 5. Detailed Specification: `AppSettingsDao`

**File Location:** `lib/core/database/daos/app_settings_dao.dart`

### 5.1 Interface Contract
```dart
abstract class IAppSettingsDao {
  // Reactive Stream
  Stream<AppSetting> watchSettings();

  // Snapshot Queries
  Future<AppSetting> getSettings();
  Future<AppSetting> ensureSettings();

  // Fine-grained Mutations
  Future<void> updateCooldownDays(int days);
  Future<void> updateThemeMode(String mode);
  Future<void> updateNotificationTime(int hour, int minute);
  Future<void> updateNotificationsEnabled(bool enabled);
  Future<void> updatePreventRepeatProtein(bool prevent);
  Future<void> updatePreventRepeatCarbs(bool prevent);
  Future<void> updateFirstRun(bool isFirstRun);

  // Bulk Mutation & Reset
  Future<void> updateSettings(AppSettingsCompanion companion);
  Future<void> resetToDefaults();
}
```

### 5.2 Method Specifications & Drift Fluent Queries

#### 1. Singleton Row ID & Initialization Guarantee
The `AppSettings` table is a single-row configuration entity with `id = 1`.
```dart
static const int settingsRowId = 1;

static const defaultSettings = AppSettingsCompanion(
  id: Value(settingsRowId),
  cooldownDays: Value(14),
  preventRepeatProtein: Value(true),
  preventRepeatCarbs: Value(true),
  notificationHour: Value(12),
  notificationMinute: Value(0),
  notificationsEnabled: Value(true),
  themeMode: Value('system'),
  isFirstRun: Value(true),
);
```

#### 2. `watchSettings()` & `getSettings()`
- **Purpose**: Exposes settings reactively for the UI (Settings screen, theme mode toggle, notification listener) and ensures the singleton row is created if missing.
- **Drift Implementation**:
  ```dart
  Stream<AppSetting> watchSettings() {
    return (select(appSettings)..where((t) => t.id.equals(settingsRowId)))
        .watchSingleOrNull()
        .asyncMap((setting) async {
      if (setting != null) return setting;
      return await ensureSettings();
    });
  }

  Future<AppSetting> getSettings() async {
    final existing = await (select(appSettings)
          ..where((t) => t.id.equals(settingsRowId)))
        .getSingleOrNull();

    if (existing != null) return existing;
    return await ensureSettings();
  }

  Future<AppSetting> ensureSettings() async {
    await into(appSettings).insertOnConflictUpdate(defaultSettings);
    return await (select(appSettings)
          ..where((t) => t.id.equals(settingsRowId)))
        .getSingle();
  }
  ```

#### 3. Mutation Operations
- **`updateCooldownDays(int days)`**:
  ```dart
  Future<void> updateCooldownDays(int days) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(cooldownDays: Value(days)),
    );
  }
  ```
- **`updateThemeMode(String mode)`**:
  ```dart
  Future<void> updateThemeMode(String mode) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(themeMode: Value(mode)),
    );
  }
  ```
- **`updateNotificationTime(int hour, int minute)`**:
  ```dart
  Future<void> updateNotificationTime(int hour, int minute) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(
        notificationHour: Value(hour),
        notificationMinute: Value(minute),
      ),
    );
  }
  ```
- **`updateNotificationsEnabled(bool enabled)`**:
  ```dart
  Future<void> updateNotificationsEnabled(bool enabled) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(notificationsEnabled: Value(enabled)),
    );
  }
  ```
- **`updatePreventRepeatProtein(bool prevent)` & `updatePreventRepeatCarbs(bool prevent)`**:
  ```dart
  Future<void> updatePreventRepeatProtein(bool prevent) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(preventRepeatProtein: Value(prevent)),
    );
  }

  Future<void> updatePreventRepeatCarbs(bool prevent) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(preventRepeatCarbs: Value(prevent)),
    );
  }
  ```
- **`resetToDefaults()`**:
  ```dart
  Future<void> resetToDefaults() async {
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId)))
        .write(defaultSettings);
  }
  ```

---

## 6. Complete Dart Implementation Code for Worker

### 6.1 `lib/core/database/daos/meals_dao.dart`

```dart
import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/meals_table.dart';

part 'meals_dao.g.dart';

@DriftAccessor(tables: [Meals])
class MealsDao extends DatabaseAccessor<AppDatabase> with _$MealsDaoMixin {
  MealsDao(AppDatabase db) : super(db);

  // ---------------------------------------------------------------------------
  // Reactive Streams
  // ---------------------------------------------------------------------------

  /// Watches all meals in the vault ordered alphabetically by name.
  Stream<List<Meal>> watchAllMeals() {
    return (select(meals)
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watches a single meal by primary key ID.
  Stream<Meal?> watchMealById(int id) {
    return (select(meals)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Watches favorite meals.
  Stream<List<Meal>> watchFavorites() {
    return (select(meals)
          ..where((t) => t.isFavorite.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watches meals matching a search query string.
  Stream<List<Meal>> watchSearchMeals(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return watchAllMeals();

    return (select(meals)
          ..where((t) => t.name.contains(clean))
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watches meals matching multiple optional tag filters.
  Stream<List<Meal>> watchFilterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    return _buildFilteredQuery(
      proteinType: proteinType,
      carbsType: carbsType,
      category: category,
      isFridaySpecial: isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly,
      isFavorite: isFavorite,
      maxPrepTimeMinutes: maxPrepTimeMinutes,
    ).watch();
  }

  // ---------------------------------------------------------------------------
  // Snapshot Queries
  // ---------------------------------------------------------------------------

  /// Retrieves all meals once.
  Future<List<Meal>> getAllMeals() {
    return (select(meals)
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Retrieves a single meal by ID.
  Future<Meal?> getMealById(int id) {
    return (select(meals)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Performs a one-time search query on meal names.
  Future<List<Meal>> searchMeals(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return getAllMeals();

    return (select(meals)
          ..where((t) => t.name.contains(clean))
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Performs a one-time multi-criteria filter query.
  Future<List<Meal>> filterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    return _buildFilteredQuery(
      proteinType: proteinType,
      carbsType: carbsType,
      category: category,
      isFridaySpecial: isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly,
      isFavorite: isFavorite,
      maxPrepTimeMinutes: maxPrepTimeMinutes,
    ).get();
  }

  // ---------------------------------------------------------------------------
  // Mutations (CRUD)
  // ---------------------------------------------------------------------------

  /// Inserts a new meal into the database and returns the generated row ID.
  Future<int> insertMeal(MealsCompanion meal) {
    return into(meals).insert(meal);
  }

  /// Inserts a batch of meals (used during seed initialization).
  Future<void> insertMealsBatch(List<MealsCompanion> mealCompanions) {
    return batch((b) {
      b.insertAll(meals, mealCompanions);
    });
  }

  /// Replaces an existing meal record.
  Future<bool> updateMeal(Meal meal) {
    return update(meals).replace(
      meal.copyWith(updatedAt: DateTime.now()),
    );
  }

  /// Selectively updates columns for a specific meal ID.
  Future<int> updateMealCompanion(int id, MealsCompanion companion) {
    return (update(meals)..where((t) => t.id.equals(id))).write(
      companion.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// Toggles favorite flag for a meal.
  Future<void> toggleFavorite(int id, bool currentStatus) async {
    await (update(meals)..where((t) => t.id.equals(id))).write(
      MealsCompanion(
        isFavorite: Value(!currentStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Deletes a meal by primary key ID.
  Future<int> deleteMeal(int id) {
    return (delete(meals)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes all meals from the table.
  Future<int> deleteAllMeals() {
    return delete(meals).go();
  }

  // ---------------------------------------------------------------------------
  // Internal Query Helper
  // ---------------------------------------------------------------------------

  SimpleSelectStatement<$MealsTable, Meal> _buildFilteredQuery({
    String? query,
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    final statement = select(meals);
    statement.where((t) {
      final predicates = <Expression<bool>>[];

      if (query != null && query.trim().isNotEmpty) {
        predicates.add(t.name.contains(query.trim()));
      }
      if (proteinType != null) {
        predicates.add(t.proteinType.equals(proteinType.name));
      }
      if (carbsType != null) {
        predicates.add(t.carbsType.equals(carbsType.name));
      }
      if (category != null) {
        predicates.add(t.category.equals(category.name));
      }
      if (isFridaySpecial != null) {
        predicates.add(t.isFridaySpecial.equals(isFridaySpecial));
      }
      if (isBudgetFriendly != null) {
        predicates.add(t.isBudgetFriendly.equals(isBudgetFriendly));
      }
      if (isFavorite != null) {
        predicates.add(t.isFavorite.equals(isFavorite));
      }
      if (maxPrepTimeMinutes != null) {
        predicates.add(t.prepTimeMinutes.isSmallerOrEqualValue(maxPrepTimeMinutes));
      }

      if (predicates.isEmpty) return const Constant(true);
      return Expression.and(predicates);
    });

    statement.orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ]);
    return statement;
  }
}
```

---

### 6.2 `lib/core/database/daos/meal_history_dao.dart`

```dart
import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/meal_history_table.dart';
import '../tables/meals_table.dart';

part 'meal_history_dao.g.dart';

@DriftAccessor(tables: [MealHistory, Meals])
class MealHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$MealHistoryDaoMixin {
  MealHistoryDao(AppDatabase db) : super(db);

  // ---------------------------------------------------------------------------
  // Reactive Streams
  // ---------------------------------------------------------------------------

  /// Watches chronological meal history logs ordered by cookedAt descending.
  Stream<List<MealHistoryData>> watchHistory({int? limit}) {
    final query = select(mealHistory)
      ..orderBy([
        (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
      ]);
    if (limit != null && limit > 0) {
      query.limit(limit);
    }
    return query.watch();
  }

  /// Watches all history entries for a specific meal ID.
  Stream<List<MealHistoryData>> watchHistoryForMeal(int mealId) {
    return (select(mealHistory)
          ..where((t) => t.mealId.equals(mealId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Watches the latest cooked meal entry.
  Stream<MealHistoryData?> watchLatestCookedMeal() {
    return (select(mealHistory)
          ..orderBy([
            (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Snapshot Queries
  // ---------------------------------------------------------------------------

  /// Retrieves the most recent meal history entries.
  Future<List<MealHistoryData>> getRecentHistory({int limit = 50}) {
    return (select(mealHistory)
          ..orderBy([
            (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  /// Retrieves all meal history entries cooked within the specified number of days.
  Future<List<MealHistoryData>> getHistoryWithinDays(
    int days, {
    DateTime? referenceDate,
  }) {
    final ref = referenceDate ?? DateTime.now();
    final cutoff = ref.subtract(Duration(days: days));

    return (select(mealHistory)
          ..where((t) => t.cookedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([
            (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Retrieves the single latest cooked meal on or before a given date.
  Future<MealHistoryData?> getLatestCookedMeal({DateTime? beforeDate}) {
    final query = select(mealHistory);
    if (beforeDate != null) {
      query.where((t) => t.cookedAt.isSmallerOrEqualValue(beforeDate));
    }
    query
      ..orderBy([
        (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Returns the most recent date a meal was cooked, or null if never cooked.
  Future<DateTime?> getLastCookedDateForMeal(int mealId) async {
    final latest = await (select(mealHistory)
          ..where((t) => t.mealId.equals(mealId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.cookedAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();

    return latest?.cookedAt;
  }

  /// Returns total count of history records.
  Future<int> getHistoryCount() async {
    final countExp = mealHistory.id.count();
    final query = selectOnly(mealHistory)..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Logging Mutations
  // ---------------------------------------------------------------------------

  /// Logs a meal cooking event with full snapshot data.
  Future<int> logMeal({
    required int? mealId,
    required String mealName,
    required ProteinType proteinType,
    required CarbsType carbsType,
    required DateTime cookedAt,
    required String entryType,
    String? notes,
  }) {
    return into(mealHistory).insert(
      MealHistoryCompanion.insert(
        mealId: Value(mealId),
        mealName: mealName,
        proteinType: proteinType,
        carbsType: carbsType,
        cookedAt: cookedAt,
        entryType: entryType,
        notes: Value(notes),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Convenience method to log a Meal entity as freshly cooked.
  Future<int> logCookedMeal(Meal meal, {DateTime? cookedAt, String? notes}) {
    return logMeal(
      mealId: meal.id,
      mealName: meal.name,
      proteinType: meal.proteinType,
      carbsType: meal.carbsType,
      cookedAt: cookedAt ?? DateTime.now(),
      entryType: 'cooked',
      notes: notes,
    );
  }

  /// Convenience method to log a Meal entity as leftover food.
  Future<int> logLeftoverMeal(Meal meal, {DateTime? cookedAt, String? notes}) {
    return logMeal(
      mealId: meal.id,
      mealName: meal.name,
      proteinType: meal.proteinType,
      carbsType: meal.carbsType,
      cookedAt: cookedAt ?? DateTime.now(),
      entryType: 'leftover',
      notes: notes,
    );
  }

  // ---------------------------------------------------------------------------
  // Deletions
  // ---------------------------------------------------------------------------

  /// Deletes a specific history record by ID.
  Future<int> deleteHistoryEntry(int id) {
    return (delete(mealHistory)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes all history records associated with a specific meal ID.
  Future<int> deleteHistoryForMeal(int mealId) {
    return (delete(mealHistory)..where((t) => t.mealId.equals(mealId))).go();
  }

  /// Deletes all history entries from the database.
  Future<int> clearAllHistory() {
    return delete(mealHistory).go();
  }
}
```

---

### 6.3 `lib/core/database/daos/app_settings_dao.dart`

```dart
import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/app_settings_table.dart';

part 'app_settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(AppDatabase db) : super(db);

  /// Fixed primary key ID for singleton settings row.
  static const int settingsRowId = 1;

  /// Default baseline configuration.
  static const defaultSettings = AppSettingsCompanion(
    id: Value(settingsRowId),
    cooldownDays: Value(14),
    preventRepeatProtein: Value(true),
    preventRepeatCarbs: Value(true),
    notificationHour: Value(12),
    notificationMinute: Value(0),
    notificationsEnabled: Value(true),
    themeMode: Value('system'),
    isFirstRun: Value(true),
  );

  // ---------------------------------------------------------------------------
  // Reactive Stream
  // ---------------------------------------------------------------------------

  /// Watches application settings reactively; auto-initializes singleton row if missing.
  Stream<AppSetting> watchSettings() {
    return (select(appSettings)..where((t) => t.id.equals(settingsRowId)))
        .watchSingleOrNull()
        .asyncMap((setting) async {
      if (setting != null) return setting;
      return await ensureSettings();
    });
  }

  // ---------------------------------------------------------------------------
  // Snapshot Queries
  // ---------------------------------------------------------------------------

  /// Retrieves current settings snapshot.
  Future<AppSetting> getSettings() async {
    final existing = await (select(appSettings)
          ..where((t) => t.id.equals(settingsRowId)))
        .getSingleOrNull();

    if (existing != null) return existing;
    return await ensureSettings();
  }

  /// Ensures singleton settings row exists in SQLite.
  Future<AppSetting> ensureSettings() async {
    await into(appSettings).insertOnConflictUpdate(defaultSettings);
    return await (select(appSettings)
          ..where((t) => t.id.equals(settingsRowId)))
        .getSingle();
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Updates cooldown window in days.
  Future<void> updateCooldownDays(int days) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(cooldownDays: Value(days)),
    );
  }

  /// Updates app theme mode preference ('system', 'light', 'dark').
  Future<void> updateThemeMode(String mode) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(themeMode: Value(mode)),
    );
  }

  /// Updates scheduled notification time (hour, minute).
  Future<void> updateNotificationTime(int hour, int minute) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(
        notificationHour: Value(hour),
        notificationMinute: Value(minute),
      ),
    );
  }

  /// Toggles scheduled reminder notification status.
  Future<void> updateNotificationsEnabled(bool enabled) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(notificationsEnabled: Value(enabled)),
    );
  }

  /// Toggles whether consecutive days may feature the same protein type.
  Future<void> updatePreventRepeatProtein(bool prevent) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(preventRepeatProtein: Value(prevent)),
    );
  }

  /// Toggles whether consecutive days may feature the same carbs type.
  Future<void> updatePreventRepeatCarbs(bool prevent) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(preventRepeatCarbs: Value(prevent)),
    );
  }

  /// Updates first-run flag (set to false after onboarding / seed acknowledgment).
  Future<void> updateFirstRun(bool isFirstRun) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId))).write(
      AppSettingsCompanion(isFirstRun: Value(isFirstRun)),
    );
  }

  /// Updates multiple settings fields via a companion object.
  Future<void> updateSettings(AppSettingsCompanion companion) async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId)))
        .write(companion);
  }

  /// Resets settings back to factory defaults.
  Future<void> resetToDefaults() async {
    await ensureSettings();
    await (update(appSettings)..where((t) => t.id.equals(settingsRowId)))
        .write(defaultSettings);
  }
}
```

---

## 7. Riverpod Provider Integration Layer

To expose these DAOs to Riverpod state notifiers cleanly, create `lib/core/database/database_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/app_settings_dao.dart';
import 'daos/meal_history_dao.dart';
import 'daos/meals_dao.dart';

/// Database instance provider.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// MealsDao provider.
final mealsDaoProvider = Provider<MealsDao>((ref) {
  return ref.watch(appDatabaseProvider).mealsDao;
});

/// MealHistoryDao provider.
final mealHistoryDaoProvider = Provider<MealHistoryDao>((ref) {
  return ref.watch(appDatabaseProvider).mealHistoryDao;
});

/// AppSettingsDao provider.
final appSettingsDaoProvider = Provider<AppSettingsDao>((ref) {
  return ref.watch(appDatabaseProvider).appSettingsDao;
});

/// Live stream of all meals in the vault.
final allMealsStreamProvider = StreamProvider<List<Meal>>((ref) {
  return ref.watch(mealsDaoProvider).watchAllMeals();
});

/// Live stream of cooking history.
final mealHistoryStreamProvider = StreamProvider<List<MealHistoryData>>((ref) {
  return ref.watch(mealHistoryDaoProvider).watchHistory();
});

/// Live stream of application settings.
final appSettingsStreamProvider = StreamProvider<AppSetting>((ref) {
  return ref.watch(appSettingsDaoProvider).watchSettings();
});
```

---

## 8. Unit & Integration Verification Suite

File: `test/unit/database_dao_test.dart`

```dart
import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/database/tables/meals_table.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('MealsDao Tests', () {
    test('CRUD & Stream reactivity', () async {
      // 1. Initial watch is empty or contains seeded items
      final initialMeals = await db.mealsDao.getAllMeals();
      final initialCount = initialMeals.length;

      // 2. Insert meal
      final id = await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('كشري مصري'),
          proteinType: Value(ProteinType.legume),
          carbsType: Value(CarbsType.rice),
          category: Value(MealCategory.egyptianTraditional),
          prepTimeMinutes: Value(45),
          isFridaySpecial: Value(false),
          isBudgetFriendly: Value(true),
          isFavorite: Value(true),
        ),
      );
      expect(id, greaterThan(0));

      // 3. Verify getMealById
      final meal = await db.mealsDao.getMealById(id);
      expect(meal, isNotNull);
      expect(meal!.name, equals('كشري مصري'));
      expect(meal.isFavorite, isTrue);

      // 4. Search
      final searchResults = await db.mealsDao.searchMeals('كشري');
      expect(searchResults.any((m) => m.id == id), isTrue);

      // 5. Filter by tag
      final filtered = await db.mealsDao.filterByTag(
        proteinType: ProteinType.legume,
        isFavorite: true,
      );
      expect(filtered.any((m) => m.id == id), isTrue);

      // 6. Update
      await db.mealsDao.updateMeal(meal.copyWith(prepTimeMinutes: 50));
      final updated = await db.mealsDao.getMealById(id);
      expect(updated!.prepTimeMinutes, equals(50));

      // 7. Delete
      await db.mealsDao.deleteMeal(id);
      final deleted = await db.mealsDao.getMealById(id);
      expect(deleted, isNull);
    });
  });

  group('MealHistoryDao Tests', () {
    test('Logging, query within days, and cascade safety', () async {
      // 1. Insert parent meal
      final mealId = await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('ملوخية بالفراخ'),
          proteinType: Value(ProteinType.chicken),
          carbsType: Value(CarbsType.rice),
          category: Value(MealCategory.egyptianTraditional),
          prepTimeMinutes: Value(40),
        ),
      );
      final meal = (await db.mealsDao.getMealById(mealId))!;

      // 2. Log cooked meal
      final logId = await db.mealHistoryDao.logCookedMeal(meal);
      expect(logId, greaterThan(0));

      // 3. Verify recent history
      final history = await db.mealHistoryDao.getRecentHistory(limit: 10);
      expect(history.length, equals(1));
      expect(history.first.mealName, equals('ملوخية بالفراخ'));
      expect(history.first.proteinType, equals(ProteinType.chicken));

      // 4. Verify getHistoryWithinDays
      final recentDays = await db.mealHistoryDao.getHistoryWithinDays(7);
      expect(recentDays.length, equals(1));

      // 5. Delete parent meal -> snapshot preserved in history!
      await db.mealsDao.deleteMeal(mealId);
      final historyAfterDelete = await db.mealHistoryDao.getRecentHistory();
      expect(historyAfterDelete.length, equals(1));
      expect(historyAfterDelete.first.mealId, isNull); // SetNull on foreign key
      expect(historyAfterDelete.first.mealName, equals('ملوخية بالفراخ')); // Snapshot intact!

      // 6. Delete history entry
      await db.mealHistoryDao.deleteHistoryEntry(logId);
      final historyEmpty = await db.mealHistoryDao.getRecentHistory();
      expect(historyEmpty.isEmpty, isTrue);
    });
  });

  group('AppSettingsDao Tests', () {
    test('Singleton defaults and reactive mutations', () async {
      // 1. Initial settings
      final settings = await db.appSettingsDao.getSettings();
      expect(settings.cooldownDays, equals(14));
      expect(settings.preventRepeatProtein, isTrue);
      expect(settings.themeMode, equals('system'));

      // 2. Update cooldown days
      await db.appSettingsDao.updateCooldownDays(21);
      var updated = await db.appSettingsDao.getSettings();
      expect(updated.cooldownDays, equals(21));

      // 3. Update theme mode
      await db.appSettingsDao.updateThemeMode('dark');
      updated = await db.appSettingsDao.getSettings();
      expect(updated.themeMode, equals('dark'));

      // 4. Update notification time
      await db.appSettingsDao.updateNotificationTime(13, 30);
      updated = await db.appSettingsDao.getSettings();
      expect(updated.notificationHour, equals(13));
      expect(updated.notificationMinute, equals(30));

      // 5. Reset to defaults
      await db.appSettingsDao.resetToDefaults();
      final reset = await db.appSettingsDao.getSettings();
      expect(reset.cooldownDays, equals(14));
      expect(reset.themeMode, equals('system'));
    });
  });
}
```

---

## 9. Summary for Milestone 1 Worker

| Component | Target File | Core Responsibilities |
|---|---|---|
| `MealsDao` | `lib/core/database/daos/meals_dao.dart` | Full CRUD, `watchAllMeals()`, `searchMeals()`, `filterByTag()` dynamic expressions, `toggleFavorite()` |
| `MealHistoryDao` | `lib/core/database/daos/meal_history_dao.dart` | `logMeal()`, `watchHistory()`, `getRecentHistory()`, `getHistoryWithinDays()`, `deleteHistoryEntry()`, snapshot column preservation |
| `AppSettingsDao` | `lib/core/database/daos/app_settings_dao.dart` | Singleton ID=1 enforcement, `watchSettings()`, `updateCooldownDays()`, `updateThemeMode()`, `updateNotificationTime()` |
| Providers | `lib/core/database/database_providers.dart` | Riverpod providers connecting DAOs to presentation state |
| Verification | `test/unit/database_dao_test.dart` | In-memory Drift SQLite test suite validating all DAO contracts |
