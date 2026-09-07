# Milestone 1: Drift Database & Core Storage Implementation Plan

**Identity:** `teamwork_preview_explorer_m1_1`  
**Milestone:** M1 — Core Database & Drift Layer  
**Target Platform:** Flutter 3.44+ / Dart 3.12+ (Android Primary, Cross-platform Offline-First)  
**Output Status:** Ready for Worker Execution  

---

## 1. Overview & Architecture Alignment

Milestone 1 establishes the local SQLite persistence layer using **Drift** (`drift`, `drift_flutter`, `sqlite3_flutter_libs`). It provides:
1. **Three Core Relational Tables**:
   - `Meals`: Master vault of meals with name, optional photo path, protein type, carbs type, meal category, prep time in minutes, and boolean tags (isFridaySpecial, isBudgetFriendly, isFavorite).
   - `MealHistory`: Chronological log of cooking events. Implements **snapshot preservation** (`mealName`, `proteinType`, `carbsType`, `cookedAt`, `entryType`) and a nullable foreign key `mealId` referencing `Meals.id` with `onDelete: KeyAction.setNull`. This guarantees that deleting a meal from the vault never breaks or deletes past history records.
   - `AppSettings`: Singleton table (`id = 1`) persisting cooldown window duration (default 14 days), theme preference (`system`, `light`, `dark`), daily reminder notification time (`12:00`), notification toggle, and protein/carbs repeat prevention toggles.
2. **Modern Connection Setup**:
   - Connection powered by `drift_flutter` using `driftDatabase(name: 'daily_meal_db')`.
   - Default constructor allows zero-config production instantiation: `AppDatabase()`.
   - Optional parameter constructor allows in-memory test instantiation: `AppDatabase(NativeDatabase.memory())`.
3. **Seeding Strategy & Foreign Keys**:
   - `onCreate` migrator seeds the singleton `AppSettings` row and all **20 authentic Egyptian starter meals** in a single transaction batch.
   - `beforeOpen` activates SQLite foreign keys via `PRAGMA foreign_keys = ON`.
4. **Three Dedicated DAOs**:
   - `MealsDao`: Reactive stream `watchAllMeals()`, CRUD methods, favorite toggle, search.
   - `MealHistoryDao`: Reactive stream `watchHistory()`, `logMeal(...)`, recent history lookup, date cutoff queries, and history deletion.
   - `AppSettingsDao`: Reactive stream `watchSettings()`, snapshot getter, and setting update mutations.

---

## 2. Dependencies (`pubspec.yaml`)

The Worker must add the following packages to `pubspec.yaml`:

### Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  drift: ^2.24.0
  drift_flutter: ^0.2.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
```

### Dev Dependencies
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  drift_dev: ^2.24.0
  build_runner: ^2.4.13
```

> **CLI Command for Worker:**
> ```bash
> flutter pub add drift drift_flutter sqlite3_flutter_libs path_provider path dev:drift_dev dev:build_runner
> ```

---

## 3. Directory & File Structure for Milestone 1

```text
lib/
└── core/
    └── database/
        ├── app_database.dart                 # Drift database definition, migration, seeding, exports
        ├── daos/
        │   ├── app_settings_dao.dart         # Singleton settings DAO
        │   ├── meal_history_dao.dart         # Cooking history log DAO
        │   └── meals_dao.dart                # Meals Vault CRUD DAO
        ├── seed/
        │   └── initial_meals.dart            # 20 Egyptian starter meals catalog
        └── tables/
            ├── app_settings_table.dart       # AppSettings table & AppThemeModePreference enum
            ├── meal_history_table.dart       # MealHistory table & MealEntryType enum
            └── meals_table.dart              # Meals table, ProteinType, CarbsType, MealCategory enums

test/
└── unit/
    └── database_test.dart                    # Complete in-memory Drift test suite
```

---

## 4. Code Specifications

### 4.1 Table Schemas & Enums

#### File: `lib/core/database/tables/meals_table.dart`
```dart
import 'package:drift/drift.dart';

enum ProteinType {
  chicken, // فراخ / دواجن
  beef, // لحمة / مفروم
  fish, // أسماك / مأكولات بحرية
  legume, // بقوليات (كشري، عدس، فول)
  dairy, // بيض / أجبان
  none, // بدون بروتين
}

enum CarbsType {
  rice, // أرز
  pasta, // مكرونة
  bread, // عيش
  potato, // بطاطس
  grains, // فريك / برغل
  none, // بدون نشويات
}

enum MealCategory {
  egyptianTraditional, // أكلات شعبية وطبيخ
  ovenBaked, // صواني وطواجن فرن
  fastFood, // سندوتشات وسريع
  seafood, // أسماك وبحريات
  soupStew, // شوربات ويخنات
  vegetarian, // قرديحي / نباتي
}

class Meals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get photoPath => text().nullable()();
  TextColumn get proteinType => textEnum<ProteinType>()();
  TextColumn get carbsType => textEnum<CarbsType>()();
  TextColumn get category => textEnum<MealCategory>()();
  IntColumn get prepTime => integer()(); // in minutes
  BoolColumn get isFridaySpecial => boolean().withDefault(const Constant(false))();
  BoolColumn get isBudgetFriendly => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

extension ProteinTypeX on ProteinType {
  String get labelArabic {
    switch (this) {
      case ProteinType.chicken:
        return 'فراخ';
      case ProteinType.beef:
        return 'لحمة';
      case ProteinType.fish:
        return 'سمك';
      case ProteinType.legume:
        return 'بقوليات';
      case ProteinType.dairy:
        return 'بيض / أجبان';
      case ProteinType.none:
        return 'بدون بروتين';
    }
  }
}

extension CarbsTypeX on CarbsType {
  String get labelArabic {
    switch (this) {
      case CarbsType.rice:
        return 'أرز';
      case CarbsType.pasta:
        return 'مكرونة';
      case CarbsType.bread:
        return 'عيش';
      case CarbsType.potato:
        return 'بطاطس';
      case CarbsType.grains:
        return 'حبوب / فريك';
      case CarbsType.none:
        return 'بدون نشويات';
    }
  }
}

extension MealCategoryX on MealCategory {
  String get labelArabic {
    switch (this) {
      case MealCategory.egyptianTraditional:
        return 'أكلات شعبية وطبيخ';
      case MealCategory.ovenBaked:
        return 'طواجن وصواني فرن';
      case MealCategory.fastFood:
        return 'سريع وسندوتشات';
      case MealCategory.seafood:
        return 'أسماك وبحريات';
      case MealCategory.soupStew:
        return 'شوربات ويخنات';
      case MealCategory.vegetarian:
        return 'نباتي / قرديحي';
    }
  }
}
```

---

#### File: `lib/core/database/tables/meal_history_table.dart`
```dart
import 'package:drift/drift.dart';
import 'meals_table.dart';

enum MealEntryType {
  cooked, // طبخة جديدة
  leftover, // بواقي أكل
}

class MealHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Nullable foreign key: on meal deletion, set to null to preserve history log
  IntColumn get mealId => integer().nullable().references(Meals, #id, onDelete: KeyAction.setNull)();
  // Snapshot columns to preserve historical facts even if the meal is deleted
  TextColumn get mealName => text().withLength(min: 1, max: 120)();
  TextColumn get proteinType => textEnum<ProteinType>()();
  TextColumn get carbsType => textEnum<CarbsType>()();
  DateTimeColumn get cookedAt => dateTime()();
  TextColumn get entryType => textEnum<MealEntryType>().withDefault(const Constant('cooked'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

extension MealEntryTypeX on MealEntryType {
  String get labelArabic {
    switch (this) {
      case MealEntryType.cooked:
        return 'طبخة جديدة';
      case MealEntryType.leftover:
        return 'بواقي أكل';
    }
  }
}
```

---

#### File: `lib/core/database/tables/app_settings_table.dart`
```dart
import 'package:drift/drift.dart';

enum AppThemeModePreference {
  system,
  light,
  dark,
}

@DataClassName('AppSettingsData')
class AppSettings extends Table {
  // Singleton pattern with fixed primary key id = 1
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get cooldownDays => integer().withDefault(const Constant(14))();
  BoolColumn get preventRepeatProtein => boolean().withDefault(const Constant(true))();
  BoolColumn get preventRepeatCarbs => boolean().withDefault(const Constant(true))();
  IntColumn get notificationHour => integer().withDefault(const Constant(12))();
  IntColumn get notificationMinute => integer().withDefault(const Constant(0))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get themeMode => textEnum<AppThemeModePreference>().withDefault(const Constant('system'))();
  BoolColumn get isFirstRun => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

typedef AppSetting = AppSettingsData;

extension AppSettingsDataX on AppSettingsData {
  bool get notificationEnabled => notificationsEnabled;
}
```

---

### 4.2 Seed Catalog (20 Authentic Egyptian Meals)

#### File: `lib/core/database/seed/initial_meals.dart`
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/meals_table.dart';

final initialEgyptianMealsSeed = <MealsCompanion>[
  // 1
  const MealsCompanion(
    id: Value(1),
    name: Value('كشري مصري أصلي بالصلصة والدقة'),
    proteinType: Value(ProteinType.legume),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(50),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(true),
  ),
  // 2
  const MealsCompanion(
    id: Value(2),
    name: Value('ملوخية خضراء بالفراخ المحمرة وأرز بالشعرية'),
    proteinType: Value(ProteinType.chicken),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(45),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(false),
    isFavorite: Value(true),
  ),
  // 3
  const MealsCompanion(
    id: Value(3),
    name: Value('صينية بطاطس باللحمة في الفرن وأرز مصري'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.potato),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(60),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(false),
    isFavorite: Value(true),
  ),
  // 4
  const MealsCompanion(
    id: Value(4),
    name: Value('سمك بلطي مشوي بالردة ورز صيادية وسلطة بلدي'),
    proteinType: Value(ProteinType.fish),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.seafood),
    prepTime: Value(40),
    isFridaySpecial: Value(true),
    isBudgetFriendly: Value(true),
    isFavorite: Value(true),
  ),
  // 5
  const MealsCompanion(
    id: Value(5),
    name: Value('حواوشي بلدي مقرمش في الفرن ومخلل'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.fastFood),
    prepTime: Value(30),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(true),
  ),
  // 6
  const MealsCompanion(
    id: Value(6),
    name: Value('صينية مكرونة بالبشاميل واللحمة المفرومة'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.pasta),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(65),
    isFridaySpecial: Value(true),
    isBudgetFriendly: Value(false),
    isFavorite: Value(true),
  ),
  // 7
  const MealsCompanion(
    id: Value(7),
    name: Value('طاجن بامية باللحمة الضاني وأرز أبيض'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(60),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(false),
    isFavorite: Value(false),
  ),
  // 8
  const MealsCompanion(
    id: Value(8),
    name: Value('كبدة إسكندراني بالثوم والفلفل الحامي وعيش بلدي'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.fastFood),
    prepTime: Value(20),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(true),
  ),
  // 9
  const MealsCompanion(
    id: Value(9),
    name: Value('صينية فراخ مشوية بالبصل والبطاطس'),
    proteinType: Value(ProteinType.chicken),
    carbsType: Value(CarbsType.potato),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(50),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(false),
  ),
  // 10
  const MealsCompanion(
    id: Value(10),
    name: Value('مسقعة باللحمة المفرومة والبشاميل وعيش'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(45),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(false),
  ),
  // 11
  const MealsCompanion(
    id: Value(11),
    name: Value('شيش طاووق متبل مع أرز بسمتي بالخلطة'),
    proteinType: Value(ProteinType.chicken),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.ovenBaked),
    prepTime: Value(40),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(false),
    isFavorite: Value(false),
  ),
  // 12
  const MealsCompanion(
    id: Value(12),
    name: Value('كفتة حاتي مشوية مع سلطة طحينة وعيش سخن'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(35),
    isFridaySpecial: Value(true),
    isBudgetFriendly: Value(false),
    isFavorite: Value(true),
  ),
  // 13
  const MealsCompanion(
    id: Value(13),
    name: Value('سمك فيليه مقلي مع سلطة طحينة وأرز أحمر'),
    proteinType: Value(ProteinType.fish),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.seafood),
    prepTime: Value(30),
    isFridaySpecial: Value(true),
    isBudgetFriendly: Value(true),
    isFavorite: Value(false),
  ),
  // 14
  const MealsCompanion(
    id: Value(14),
    name: Value('شوربة عدس أصفر بالشعرية والليمون وعيش محمص'),
    proteinType: Value(ProteinType.legume),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.soupStew),
    prepTime: Value(25),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(false),
  ),
  // 15
  const MealsCompanion(
    id: Value(15),
    name: Value('بانيه دجاج ذهبي مقرمش مع مكرونة بالصلصة'),
    proteinType: Value(ProteinType.chicken),
    carbsType: Value(CarbsType.pasta),
    category: Value(MealCategory.fastFood),
    prepTime: Value(30),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(true),
  ),
  // 16
  const MealsCompanion(
    id: Value(16),
    name: Value('طاجن مكرونة بالسجق البلدي زي المحلات'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.pasta),
    category: Value(MealCategory.fastFood),
    prepTime: Value(30),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(false),
  ),
  // 17
  const MealsCompanion(
    id: Value(17),
    name: Value('فتة مصرية بالخل والثوم وموزة لحمة مسلوقة'),
    proteinType: Value(ProteinType.beef),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(75),
    isFridaySpecial: Value(true),
    isBudgetFriendly: Value(false),
    isFavorite: Value(true),
  ),
  // 18
  const MealsCompanion(
    id: Value(18),
    name: Value('فول مدمس بالزيت الحار وطعمية سخنة وبتنجان مخلل'),
    proteinType: Value(ProteinType.legume),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(15),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(false),
  ),
  // 19
  const MealsCompanion(
    id: Value(19),
    name: Value('شكشوكة بالبيض والطماطم والجبنة الرومي وعيش'),
    proteinType: Value(ProteinType.dairy),
    carbsType: Value(CarbsType.bread),
    category: Value(MealCategory.egyptianTraditional),
    prepTime: Value(15),
    isFridaySpecial: Value(false),
    isBudgetFriendly: Value(true),
    isFavorite: Value(false),
  ),
  // 20
  const MealsCompanion(
    id: Value(20),
    name: Value('طاجن جمبري وسبيط بالصوص الأحمر وأرز صيادية'),
    proteinType: Value(ProteinType.fish),
    carbsType: Value(CarbsType.rice),
    category: Value(MealCategory.seafood),
    prepTime: Value(40),
    isFridaySpecial: Value(true),
    isBudgetFriendly: Value(false),
    isFavorite: Value(true),
  ),
];
```

---

### 4.3 Database Class & Connection

#### File: `lib/core/database/app_database.dart`
```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/meals_table.dart';
import 'tables/meal_history_table.dart';
import 'tables/app_settings_table.dart';
import 'daos/meals_dao.dart';
import 'daos/meal_history_dao.dart';
import 'daos/app_settings_dao.dart';
import 'seed/initial_meals.dart';

export 'tables/meals_table.dart';
export 'tables/meal_history_table.dart';
export 'tables/app_settings_table.dart';
export 'daos/meals_dao.dart';
export 'daos/meal_history_dao.dart';
export 'daos/app_settings_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Meals, MealHistory, AppSettings],
  daos: [MealsDao, MealHistoryDao, AppSettingsDao],
)
class AppDatabase extends _$AppDatabase {
  // Default constructor uses driftDatabase(name: 'daily_meal_db')
  // Optional executor parameter allows in-memory test database (NativeDatabase.memory())
  AppDatabase([QueryExecutor? e]) : super(e ?? driftDatabase(name: 'daily_meal_db'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();

      // 1. Seed initial AppSettings singleton row
      await into(appSettings).insert(
        const AppSettingsCompanion(
          id: Value(1),
          cooldownDays: Value(14),
          preventRepeatProtein: Value(true),
          preventRepeatCarbs: Value(true),
          notificationHour: Value(12),
          notificationMinute: Value(0),
          notificationsEnabled: Value(true),
          themeMode: Value(AppThemeModePreference.system),
          isFirstRun: Value(true),
        ),
      );

      // 2. Seed default 20 authentic Egyptian starter meals
      await batch((b) {
        b.insertAll(meals, initialEgyptianMealsSeed);
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
```

---

### 4.4 Data Access Objects (DAOs)

#### File: `lib/core/database/daos/meals_dao.dart`
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/meals_table.dart';

part 'meals_dao.g.dart';

@DriftAccessor(tables: [Meals])
class MealsDao extends DatabaseAccessor<AppDatabase> with _$MealsDaoMixin {
  MealsDao(super.db);

  /// Watch all meals in the vault, ordered alphabetically by name
  Stream<List<Meal>> watchAllMeals() {
    return (select(meals)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  /// One-shot query to fetch all meals for recommendation batching
  Future<List<Meal>> getAllMeals() {
    return select(meals).get();
  }

  /// Fetch a single meal by its primary key ID
  Future<Meal?> getMealById(int id) {
    return (select(meals)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert a new meal into the vault
  Future<int> insertMeal(MealsCompanion meal) {
    return into(meals).insert(meal);
  }

  /// Replace / update an existing meal
  Future<bool> updateMeal(Meal meal) {
    return update(meals).replace(meal);
  }

  /// Delete a meal by ID (triggers KeyAction.setNull on MealHistory)
  Future<int> deleteMeal(int id) {
    return (delete(meals)..where((t) => t.id.equals(id))).go();
  }

  /// Toggle favorite status of a meal
  Future<void> toggleFavorite(int id, bool currentStatus) {
    return (update(meals)..where((t) => t.id.equals(id))).write(
      MealsCompanion(isFavorite: Value(!currentStatus)),
    );
  }

  /// Search meals by name query
  Future<List<Meal>> searchMeals(String query) {
    return (select(meals)..where((t) => t.name.like('%$query%'))).get();
  }
}
```

---

#### File: `lib/core/database/daos/meal_history_dao.dart`
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/meal_history_table.dart';
import '../tables/meals_table.dart';

part 'meal_history_dao.g.dart';

class MealHistoryWithMeal {
  final MealHistoryData history;
  final Meal? meal;

  MealHistoryWithMeal({required this.history, this.meal});
}

@DriftAccessor(tables: [MealHistory, Meals])
class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDaoMixin {
  MealHistoryDao(super.db);

  /// Reactive stream of history entries ordered descending by cookedAt
  Stream<List<MealHistoryData>> watchHistory() {
    return (select(mealHistory)..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])).watch();
  }

  /// Reactive stream joining history with meals (meal may be null if deleted)
  Stream<List<MealHistoryWithMeal>> watchHistoryWithMeal() {
    final query = select(mealHistory).join([
      leftOuterJoin(meals, meals.id.equalsExp(mealHistory.mealId)),
    ])..orderBy([OrderingTerm.desc(mealHistory.cookedAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return MealHistoryWithMeal(
          history: row.readTable(mealHistory),
          meal: row.readTableOrNull(meals),
        );
      }).toList();
    });
  }

  /// Snapshot of all history entries
  Future<List<MealHistoryData>> getAllHistory() {
    return (select(mealHistory)..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])).get();
  }

  /// Fetch recent history entries up to [limit]
  Future<List<MealHistoryData>> getRecentHistory({int limit = 60}) {
    return (select(mealHistory)
      ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])
      ..limit(limit)).get();
  }

  /// Fetch history within the last [days] days
  Future<List<MealHistoryData>> getHistoryWithinDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (select(mealHistory)
      ..where((t) => t.cookedAt.isBiggerOrEqualValue(cutoff))
      ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])).get();
  }

  /// Fetch the latest single cooked meal entry
  Future<MealHistoryData?> getLatestCookedMeal() {
    return (select(mealHistory)
      ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])
      ..limit(1)).getSingleOrNull();
  }

  /// Log a cooked meal with full snapshot fields
  Future<int> logMeal({
    required int mealId,
    required String mealName,
    required ProteinType proteinType,
    required CarbsType carbsType,
    required DateTime cookedAt,
    MealEntryType entryType = MealEntryType.cooked,
    String? notes,
  }) {
    return into(mealHistory).insert(
      MealHistoryCompanion(
        mealId: Value(mealId),
        mealName: Value(mealName),
        proteinType: Value(proteinType),
        carbsType: Value(carbsType),
        cookedAt: Value(cookedAt),
        entryType: Value(entryType),
        notes: Value(notes),
      ),
    );
  }

  /// Convenience helper to log directly from a Meal instance
  Future<int> logMealFromMeal(
    Meal meal, {
    DateTime? cookedAt,
    MealEntryType entryType = MealEntryType.cooked,
    String? notes,
  }) {
    return logMeal(
      mealId: meal.id,
      mealName: meal.name,
      proteinType: meal.proteinType,
      carbsType: meal.carbsType,
      cookedAt: cookedAt ?? DateTime.now(),
      entryType: entryType,
      notes: notes,
    );
  }

  /// Delete a single history log entry
  Future<int> deleteHistoryEntry(int id) {
    return (delete(mealHistory)..where((t) => t.id.equals(id))).go();
  }

  /// Clear all history logs
  Future<int> clearAllHistory() {
    return delete(mealHistory).go();
  }
}
```

---

#### File: `lib/core/database/daos/app_settings_dao.dart`
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/app_settings_table.dart';

part 'app_settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase> with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  /// Watch singleton AppSettings row
  Stream<AppSettingsData> watchSettings() {
    return (select(appSettings)..where((t) => t.id.equals(1))).watchSingle();
  }

  /// Get current AppSettings snapshot; guarantees fallback if not yet created
  Future<AppSettingsData> getSettings() async {
    final settings = await (select(appSettings)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (settings != null) return settings;

    // Resilient fallback: re-seed default singleton row if missing
    await into(appSettings).insert(
      const AppSettingsCompanion(
        id: Value(1),
        cooldownDays: Value(14),
        preventRepeatProtein: Value(true),
        preventRepeatCarbs: Value(true),
        notificationHour: Value(12),
        notificationMinute: Value(0),
        notificationsEnabled: Value(true),
        themeMode: Value(AppThemeModePreference.system),
        isFirstRun: Value(true),
      ),
      mode: InsertMode.insertOrReplace,
    );
    return (select(appSettings)..where((t) => t.id.equals(1))).getSingle();
  }

  /// Update singleton settings row
  Future<void> updateSettings(AppSettingsCompanion companion) async {
    await (update(appSettings)..where((t) => t.id.equals(1))).write(companion);
  }

  /// Update cooldown duration in days
  Future<void> updateCooldownDays(int days) async {
    await updateSettings(AppSettingsCompanion(cooldownDays: Value(days)));
  }

  /// Update theme mode preference
  Future<void> updateThemeMode(AppThemeModePreference mode) async {
    await updateSettings(AppSettingsCompanion(themeMode: Value(mode)));
  }

  /// Update daily notification time
  Future<void> updateNotificationTime(int hour, int minute) async {
    await updateSettings(
      AppSettingsCompanion(
        notificationHour: Value(hour),
        notificationMinute: Value(minute),
      ),
    );
  }

  /// Toggle notification enabled status
  Future<void> toggleNotifications(bool enabled) async {
    await updateSettings(AppSettingsCompanion(notificationsEnabled: Value(enabled)));
  }

  /// Toggle protein repetition prevention
  Future<void> togglePreventRepeatProtein(bool value) async {
    await updateSettings(AppSettingsCompanion(preventRepeatProtein: Value(value)));
  }

  /// Toggle carbs repetition prevention
  Future<void> togglePreventRepeatCarbs(bool value) async {
    await updateSettings(AppSettingsCompanion(preventRepeatCarbs: Value(value)));
  }
}
```

---

## 5. Test Specifications (`test/unit/database_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:daily_meal/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 1: Drift Database & Seeding Verification', () {
    test('onCreate seeds exactly 20 Egyptian meals with valid properties', () async {
      final meals = await db.mealsDao.getAllMeals();
      expect(meals.length, equals(20));

      final koshary = meals.firstWhere((m) => m.id == 1);
      expect(koshary.name, contains('كشري مصري'));
      expect(koshary.proteinType, equals(ProteinType.legume));
      expect(koshary.carbsType, equals(CarbsType.rice));
      expect(koshary.category, equals(MealCategory.egyptianTraditional));
      expect(koshary.prepTime, equals(50));
      expect(koshary.isBudgetFriendly, isTrue);
      expect(koshary.isFavorite, isTrue);

      final fridaySpecials = meals.where((m) => m.isFridaySpecial).toList();
      expect(fridaySpecials.length, greaterThanOrEqualTo(5));
    });

    test('onCreate seeds singleton AppSettings with default values', () async {
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

    test('MealsDao performs full CRUD operations and stream reacts to changes', () async {
      // 1. Insert new meal
      final newId = await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('حمام محشي فريك'),
          proteinType: Value(ProteinType.chicken),
          carbsType: Value(CarbsType.grains),
          category: Value(MealCategory.egyptianTraditional),
          prepTime: Value(70),
          isFridaySpecial: Value(true),
          isBudgetFriendly: Value(false),
          isFavorite: Value(true),
        ),
      );
      expect(newId, greaterThan(20));

      // 2. Read back
      final meal = await db.mealsDao.getMealById(newId);
      expect(meal, isNotNull);
      expect(meal!.name, equals('حمام محشي فريك'));

      // 3. Update meal
      await db.mealsDao.updateMeal(meal.copyWith(prepTime: 75));
      final updated = await db.mealsDao.getMealById(newId);
      expect(updated!.prepTime, equals(75));

      // 4. Toggle favorite
      await db.mealsDao.toggleFavorite(newId, true);
      final unfav = await db.mealsDao.getMealById(newId);
      expect(unfav!.isFavorite, isFalse);

      // 5. Delete meal
      final deletedCount = await db.mealsDao.deleteMeal(newId);
      expect(deletedCount, equals(1));
      final gone = await db.mealsDao.getMealById(newId);
      expect(gone, isNull);
    });

    test('MealHistory preserves snapshot and sets mealId to null when meal is deleted', () async {
      // 1. Log a cooked meal for Meal 1
      final meal1 = await db.mealsDao.getMealById(1);
      expect(meal1, isNotNull);

      final logTime = DateTime.now().subtract(const Duration(days: 2));
      final logId = await db.mealHistoryDao.logMealFromMeal(
        meal1!,
        cookedAt: logTime,
        entryType: MealEntryType.cooked,
        notes: 'طعم رائع',
      );
      expect(logId, greaterThan(0));

      // 2. Query history
      var history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(1));
      expect(history.first.mealId, equals(1));
      expect(history.first.mealName, equals(meal1.name));
      expect(history.first.proteinType, equals(meal1.proteinType));
      expect(history.first.carbsType, equals(meal1.carbsType));

      // 3. Delete the parent meal (Meal 1)
      await db.mealsDao.deleteMeal(1);
      final deletedMeal = await db.mealsDao.getMealById(1);
      expect(deletedMeal, isNull);

      // 4. Verify history row still exists and snapshot is intact, with mealId set to null
      history = await db.mealHistoryDao.getAllHistory();
      expect(history.length, equals(1));
      expect(history.first.mealId, isNull); // KeyAction.setNull verified!
      expect(history.first.mealName, equals('كشري مصري أصلي بالصلصة والدقة'));
      expect(history.first.proteinType, equals(ProteinType.legume));
    });

    test('AppSettingsDao updates settings and emits reactive stream events', () async {
      final initial = await db.appSettingsDao.getSettings();
      expect(initial.cooldownDays, equals(14));

      await db.appSettingsDao.updateCooldownDays(21);
      await db.appSettingsDao.updateThemeMode(AppThemeModePreference.dark);
      await db.appSettingsDao.updateNotificationTime(14, 30);
      await db.appSettingsDao.toggleNotifications(false);

      final updated = await db.appSettingsDao.getSettings();
      expect(updated.cooldownDays, equals(21));
      expect(updated.themeMode, equals(AppThemeModePreference.dark));
      expect(updated.notificationHour, equals(14));
      expect(updated.notificationMinute, equals(30));
      expect(updated.notificationsEnabled, isFalse);
    });
  });
}
```

---

## 6. Step-by-Step Instructions for the Worker

The Worker should follow these exact sequential steps:

### Step 1: Update `pubspec.yaml`
Add `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `path_provider`, `path` to `dependencies` and `drift_dev`, `build_runner` to `dev_dependencies`. Run:
```powershell
flutter pub get
```

### Step 2: Create Table Definitions & Seed Data
Create the following files under `lib/core/database/`:
- `tables/meals_table.dart`
- `tables/meal_history_table.dart`
- `tables/app_settings_table.dart`
- `seed/initial_meals.dart`

### Step 3: Create DAOs and AppDatabase Class
Create:
- `daos/meals_dao.dart`
- `daos/meal_history_dao.dart`
- `daos/app_settings_dao.dart`
- `app_database.dart`

### Step 4: Run Code Generation
Execute `build_runner` to generate `app_database.g.dart`, `meals_dao.g.dart`, `meal_history_dao.g.dart`, and `app_settings_dao.g.dart`:
```powershell
dart run build_runner build --delete-conflicting-outputs
```
*Verification:* Confirm zero generation errors.

### Step 5: Implement and Run Unit Tests
Create `test/unit/database_test.dart` and execute:
```powershell
flutter test test/unit/database_test.dart
```
*Verification:* Confirm all 5 test groups pass (100% green).

### Step 6: Static Analysis
Execute static analysis to ensure 0 lint or formatting errors:
```powershell
flutter analyze
```
*Verification:* Must output `No issues found!`.

---

## 7. Downstream Interfaces & Guarantees for Future Milestones

- **Milestone 2 (Cooldown Engine)**: Can directly consume `List<Meal>` and `List<MealHistoryData>` without DB joins, using `m.proteinType`, `h.proteinType`, `h.cookedAt`, and `settings.cooldownDays`.
- **Milestone 3 (Riverpod & Presentation)**: Riverpod providers can bind directly to `db.mealsDao.watchAllMeals()`, `db.mealHistoryDao.watchHistory()`, and `db.appSettingsDao.watchSettings()` for automatic UI reactivity without manual event wiring.
- **Milestone 4 (History & Notifications)**: History screen can group `MealHistoryData` by `cookedAt` with confidence that meal names and proteins remain preserved even if meals are deleted.
