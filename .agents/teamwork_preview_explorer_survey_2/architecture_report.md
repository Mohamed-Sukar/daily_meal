# Architectural Specification & Test Strategy: 'أكلة النهاردة' (Daily Meal)

**Document Version:** 1.0.0  
**Author:** Architecture & Test Planner (`teamwork_preview_explorer_survey_2`)  
**Date:** 2026-09-06  
**Status:** Approved Architectural Blueprint  
**Target Environment:** Flutter 3.44+ / Dart 3.12+ (Android Primary, Cross-platform Offline-First)

---

## Executive Summary

"أكلة النهاردة" is an offline-first Flutter application designed to solve the daily Egyptian household question *"هناكل إيه النهاردة؟"* (What are we eating today?). The architecture enforces:
1. **Local SQLite Persistence via Drift**: Robust relational data storage, type-safe DAOs, reactive stream queries, and foreign-key cascading.
2. **Deterministic Recommendation Engine & Cooldown Algorithm**: Eliminates meal fatigue by excluding recently cooked meals (14-day default cooldown), avoiding back-to-back protein and carbs repetition, prioritizing Friday specials, and gracefully degrading via a 5-tier progressive relaxation fallback when candidate pools are constrained.
3. **Riverpod Reactive Architecture**: Unidirectional data flow using `flutter_riverpod` and `riverpod_annotation`, where state updates (e.g., adding a meal, logging a meal cooked) automatically invalidate and recalculate downstream recommendations.
4. **GoRouter Material 3 RTL Navigation**: Stateful nested tab shell with an Egyptian Arabic RTL layout, custom typography, and Material You dynamic coloring.
5. **Tier 1-4 Test Matrix**: Complete verification strategy spanning pure unit tests (algorithm & math), widget/state tests (RTL & Riverpod reactivity), Drift integration tests (in-memory SQLite), and end-to-end user flows.

---

## 1. System Architecture & Directory Structure

The project follows Clean Architecture with Feature-First grouping inside `lib/`:

```
lib/
├── app.dart                                # MaterialApp.router configuration, RTL, Theme, Locales
├── main.dart                               # Entry point, ProviderScope initialization, DB setup
├── core/
│   ├── constants/
│   │   ├── app_constants.dart              # Cooldown defaults, animation durations
│   │   └── seed_meals.dart                 # Initial Egyptian meal seed dataset (20 meals)
│   ├── database/
│   │   ├── app_database.dart               # Drift database class & connection setup
│   │   ├── connection/
│   │   │   ├── connection.dart             # Conditional export for platform connection
│   │   │   ├── native.dart                 # Native SQLite (Android/iOS/Desktop) via sqlite3
│   │   │   └── unsupported.dart
│   │   ├── daos/
│   │   │   ├── meals_dao.dart              # Meals CRUD & queries
│   │   │   ├── meal_history_dao.dart       # History logs & joins
│   │   │   └── app_settings_dao.dart       # Singleton settings
│   │   └── tables/
│   │       ├── meals_table.dart            # Drift 'meals' table definition
│   │       ├── meal_history_table.dart     # Drift 'meal_history' table definition
│   │       └── app_settings_table.dart     # Drift 'app_settings' table definition
│   ├── localization/
│   │   ├── arabic_intl.dart                # Arabic strings & date formatters
│   │   └── l10n.dart
│   ├── notifications/
│   │   └── notification_service.dart       # flutter_local_notifications scheduler
│   ├── router/
│   │   ├── app_router.dart                 # GoRouter configuration & StatefulShellRoute
│   │   └── routes.dart                     # Route name constants
│   └── theme/
│       ├── app_colors.dart                 # Culinary color palette & seed colors
│       ├── app_theme.dart                  # Material 3 light & dark ThemeData
│       └── app_typography.dart             # Arabic font styling (Cairo/Tajawal)
├── features/
│   ├── home/
│   │   ├── data/
│   │   │   └── recommendation_engine.dart  # Pure Cooldown & Scoring Algorithm
│   │   ├── presentation/
│   │   │   ├── controllers/
│   │   │   │   ├── recommendation_controller.dart # Riverpod AsyncNotifier
│   │   │   │   └── wheel_controller.dart          # Spin the wheel state controller
│   │   │   ├── screens/
│   │   │   │   └── home_screen.dart               # 3-card stack & quick action bar
│   │   │   └── widgets/
│   │   │       ├── meal_card_stack.dart           # Swipeable 3-card stack
│   │   │       ├── quick_actions_bar.dart         # 'طبخت دي' / 'بواقي' buttons
│   │   │       └── wheel_roulette_dialog.dart     # Canvas roulette wheel
│   ├── meal_vault/
│   │   ├── presentation/
│   │   │   ├── controllers/
│   │   │   │   └── meal_vault_controller.dart     # Riverpod meals CRUD notifier
│   │   │   ├── screens/
│   │   │   │   ├── meal_vault_screen.dart         # Searchable, filterable meals list
│   │   │   │   ├── add_meal_screen.dart           # Form to add custom meal
│   │   │   │   └── meal_details_screen.dart       # Meal viewer & editor
│   │   │   └── widgets/
│   │   │       ├── meal_list_tile.dart
│   │   │       └── filter_chips_bar.dart
│   ├── history/
│   │   ├── presentation/
│   │   │   ├── controllers/
│   │   │   │   └── history_controller.dart        # Riverpod history log notifier
│   │   │   ├── screens/
│   │   │   │   └── history_screen.dart            # Chronological log & statistics
│   │   │   └── widgets/
│   │   │       └── history_timeline_item.dart
│   └── settings/
│       ├── presentation/
│       │   ├── controllers/
│   │   │   │   └── settings_controller.dart       # Riverpod settings notifier
│       │   └── screens/
│       │       └── settings_screen.dart           # Cooldown sliders, theme, time picker
```

---

## 2. Drift SQLite Schema & DAO Architecture

### 2.1 Enums & Converters

To maintain type safety and readable SQLite storage, domain enums are mapped using Drift's `textEnum`:

```dart
enum ProteinType {
  chicken,  // فراخ / دواجن
  beef,     // لحمة بلدي / مفرومة
  fish,     // سمك / مأكولات بحرية
  legume,   // بقوليات / نباتي (كشري، فول، عدس)
  dairy,    // بيض / أجبان
  none,     // بدون بروتين رئيسي
}

enum CarbsType {
  rice,     // أرز (مصري، بسمتي، صيادية)
  pasta,    // مكرونة (بشاميل، صلصة حمراء، طواجن)
  bread,    // عيش بلدي / شامي / فينو
  potato,   // بطاطس (صينية، بوريه، مقلية)
  grains,   // فريك / برغل / كسكسي
  none,     // قليل النشويات / بدون
}

enum MealCategory {
  egyptianTraditional, // أكلات شعبية وطبيخ مصري أصيل
  ovenBaked,           // صواني وطواجن فرن
  fastFood,            // سندوتشات وسريع (حواوشي، كبدة، بانيه)
  seafood,             // أسماك ومأكولات بحرية
  soupStew,            // شوربات ويخنات شتوية
  vegetarian,          // قرديحي / نباتي
}

enum MealHistoryStatus {
  cookedToday, // تم طبخها اليوم
  leftover,    // أكل بواقي من اليوم السابق
}

enum AppThemeModePreference {
  system,
  light,
  dark,
}
```

### 2.2 Table Definitions

#### `Meals` Table (`tables/meals_table.dart`)
```dart
import 'package:drift/drift.dart';

class Meals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get photoPath => text().nullable()();
  TextColumn get proteinType => textEnum<ProteinType>()();
  TextColumn get carbsType => textEnum<CarbsType>()();
  TextColumn get category => textEnum<MealCategory>()();
  IntColumn get prepTimeMinutes => integer()();
  BoolColumn get isFridaySpecial => boolean().withDefault(const Constant(false))();
  BoolColumn get isBudgetFriendly => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
```

#### `MealHistory` Table (`tables/meal_history_table.dart`)
```dart
import 'package:drift/drift.dart';
import 'meals_table.dart';

class MealHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mealId => integer().references(Meals, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get cookedDate => dateTime()(); // Stored as normalized date YYYY-MM-DD
  TextColumn get status => textEnum<MealHistoryStatus>()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

#### `AppSettings` Table (`tables/app_settings_table.dart`)
```dart
import 'package:drift/drift.dart';

class AppSettings extends Table {
  // Enforce singleton pattern with fixed primary key id = 1
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
```

### 2.3 DAO Specifications

#### 1. `MealsDao`
- `Stream<List<Meal>> watchAllMeals()`: Live reactive stream for the Meal Vault.
- `Future<List<Meal>> getAllMeals()`: One-shot snapshot for recommendation batching.
- `Future<Meal?> getMealById(int id)`: Fetch single meal for details or wheel selection.
- `Future<int> insertMeal(MealsCompanion meal)`: Create new meal; triggers stream emissions.
- `Future<bool> updateMeal(Meal meal)`: Edit existing meal.
- `Future<int> deleteMeal(int id)`: Delete meal; cascade deletes associated `MealHistory` entries.
- `Future<void> toggleFavorite(int id, bool currentStatus)`: Toggles favorite flag.

#### 2. `MealHistoryDao`
- `Stream<List<MealHistoryWithMeal>> watchHistory()`: Live stream joining `MealHistory` with `Meals`.
- `Future<List<MealHistoryWithMeal>> getRecentHistory({int limit = 60})`: Historical timeline query.
- `Future<List<MealHistoryWithMeal>> getHistoryWithinDays(int days)`: Retrieves all entries where `cookedDate >= now - days`.
- `Future<MealHistoryWithMeal?> getLatestCookedMeal()`: Fetches the most recent cooked meal to check yesterday's protein/carbs.
- `Future<int> logCookedMeal({required int mealId, required DateTime date, required MealHistoryStatus status, String? notes})`: Logs meal and triggers reactive recommendation refresh.
- `Future<int> deleteHistoryEntry(int id)`: Rollback a mistakenly logged meal.

#### 3. `AppSettingsDao`
- `Stream<AppSettingsData> watchSettings()`: Reactive stream of settings for dynamic UI adjustments.
- `Future<AppSettingsData> getSettings()`: Snapshot of configuration.
- `Future<void> updateSettings(AppSettingsCompanion settings)`: Updates cooldown or notification parameters.

### 2.4 Migrations & Initial Seed Data Strategy

```dart
@DriftDatabase(
  tables: [Meals, MealHistory, AppSettings],
  daos: [MealsDao, MealHistoryDao, AppSettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

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
        ),
      );
      // 2. Seed default 20 Egyptian meals
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

#### Default Egyptian Meals Seed Catalog (20 Core Dishes)
| # | Meal Name (Arabic) | Protein | Carbs | Category | Prep (min) | Friday | Budget | Favorite |
|---|--------------------|---------|-------|----------|------------|--------|--------|----------|
| 1 | كشري مصري أصلي بالصلصة والدقة | `legume` | `rice` | `egyptianTraditional` | 50 | ❌ | ✅ | ✅ |
| 2 | ملوخية خضراء بالفراخ المحمرة وأرز بالشعرية | `chicken` | `rice` | `egyptianTraditional` | 45 | ❌ | ❌ | ✅ |
| 3 | صينية بطاطس باللحمة في الفرن وأرز مصري | `beef` | `potato` | `ovenBaked` | 60 | ❌ | ❌ | ✅ |
| 4 | سمك بلطي مشوي بالردة ورز صيادية وسلطة بلدي | `fish` | `rice` | `seafood` | 40 | ✅ | ✅ | ✅ |
| 5 | حواوشي بلدي مقرمش في الفرن ومخلل | `beef` | `bread` | `fastFood` | 30 | ❌ | ✅ | ✅ |
| 6 | صينية مكرونة بالبشاميل واللحمة المفرومة | `beef` | `pasta` | `ovenBaked` | 65 | ✅ | ❌ | ✅ |
| 7 | طاجن بامية باللحمة الضاني وأرز أبيض | `beef` | `rice` | `ovenBaked` | 60 | ❌ | ❌ | ❌ |
| 8 | كبدة إسكندراني بالثوم والفلفل الحامي وعيش بلدي | `beef` | `bread` | `fastFood` | 20 | ❌ | ✅ | ✅ |
| 9 | صينية فراخ مشوية بالبصل والبطاطس | `chicken` | `potato` | `ovenBaked` | 50 | ❌ | ✅ | ❌ |
| 10 | مسقعة باللحمة المفرومة والبشاميل وعيش | `beef` | `bread` | `egyptianTraditional` | 45 | ❌ | ✅ | ❌ |
| 11 | شيش طاووق متبل مع أرز بسمتي بالخلطة | `chicken` | `rice` | `ovenBaked` | 40 | ❌ | ❌ | ❌ |
| 12 | كفتة حاتي مشوية مع سلطة طحينة وعيش سخن | `beef` | `bread` | `egyptianTraditional` | 35 | ✅ | ❌ | ✅ |
| 13 | سمك فيليه مقلي مع سلطة طحينة وأرز أحمر | `fish` | `rice` | `seafood` | 30 | ✅ | ✅ | ❌ |
| 14 | شوربة عدس أصفر بالشعرية والليمون وعيش محمص | `legume` | `bread` | `soupStew` | 25 | ❌ | ✅ | ❌ |
| 15 | بانيه دجاج ذهبي مقرمش مع مكرونة بالصلصة | `chicken` | `pasta` | `fastFood` | 30 | ❌ | ✅ | ✅ |
| 16 | طاجن مكرونة بالسجق البلدي زي المحلات | `beef` | `pasta` | `fastFood` | 30 | ❌ | ✅ | ❌ |
| 17 | فتة مصرية بالخل والثوم وموزة لحمة مسلوقة | `beef` | `rice` | `egyptianTraditional` | 75 | ✅ | ❌ | ✅ |
| 18 | فول مدمس بالزيت الحار وطعمية سخنة وبتنجان مخلل | `legume` | `bread` | `egyptianTraditional` | 15 | ❌ | ✅ | ❌ |
| 19 | شكشوكة بالبيض والطماطم والجبنة الرومي وعيش | `dairy` | `bread` | `egyptianTraditional` | 15 | ❌ | ✅ | ❌ |
| 20 | طاجن جمبري وسبيط بالصوص الأحمر وأرز صيادية | `fish` | `rice` | `seafood` | 40 | ✅ | ❌ | ✅ |

---

## 3. Recommendation Engine & Cooldown Algorithm Specification

### 3.1 Mathematical Formulation

Let $\mathcal{M} = \{m_1, m_2, \dots, m_N\}$ be the universe of available meals.  
Let $\mathcal{H} = [h_1, h_2, \dots, h_K]$ be the chronological meal history logged by the user, ordered descending by `cookedDate`.  
Let $T_{\text{today}}$ be the current normalized local date (00:00:00 UTC).

#### Input Parameters:
1. Candidate Meals: $\mathcal{M}$
2. Meal History: $\mathcal{H}$
3. Settings:
   - Cooldown window: $C_{\text{days}} \in [1, 60]$ (default: 14)
   - Back-to-back protein filter flag: $F_{\text{protein}} \in \{\text{true}, \text{false}\}$ (default: true)
   - Back-to-back carbs filter flag: $F_{\text{carbs}} \in \{\text{true}, \text{false}\}$ (default: true)
   - Friday flag: $\text{isFriday} = (T_{\text{today}}.\text{weekday} == \text{DateTime.friday})$

#### Context Detection (Yesterday's / Last Cooked Meal):
Find the most recent entry $h_{\text{last}} \in \mathcal{H}$ where:
$$\Delta d = \text{daysBetween}(h_{\text{last}}.\text{cookedDate}, T_{\text{today}}) \le 1$$
If found:
- $\text{lastProtein} = h_{\text{last}}.\text{meal}.\text{proteinType}$
- $\text{lastCarbs} = h_{\text{last}}.\text{meal}.\text{carbsType}$
Else:
- $\text{lastProtein} = \text{null}$, $\text{lastCarbs} = \text{null}$

### 3.2 Filtering Rules

For any meal $m \in \mathcal{M}$:
1. **Cooldown Exclusion**:
   Let $\text{lastCooked}(m) = \max(\{h.\text{cookedDate} \mid h \in \mathcal{H}, h.\text{mealId} == m.\text{id}\} \cup \{\varnothing\})$.
   If $\text{lastCooked}(m) \neq \varnothing$:
   $$\Delta_{\text{days}}(m) = \text{daysBetween}(\text{lastCooked}(m), T_{\text{today}})$$
   The meal is on cooldown if $\Delta_{\text{days}}(m) < C_{\text{days}}$.
2. **Protein Repeat Exclusion**:
   If $F_{\text{protein}} \land (\text{lastProtein} \neq \text{null}) \land (\text{lastProtein} \neq \text{ProteinType.none})$:
   Exclude $m$ if $m.\text{proteinType} == \text{lastProtein}$.
3. **Carbs Repeat Exclusion**:
   If $F_{\text{carbs}} \land (\text{lastCarbs} \neq \text{null}) \land (\text{lastCarbs} \neq \text{CarbsType.none})$:
   Exclude $m$ if $m.\text{carbsType} == \text{lastCarbs}$.

### 3.3 Scoring & Ranking Formula

For every surviving candidate $m$, calculate $\text{Score}(m)$:

$$\text{Score}(m) = S_{\text{recency}}(m) + S_{\text{friday}}(m) + S_{\text{favorite}}(m) + S_{\text{budget}}(m) + Jitter(m)$$

Where:
- **Recency Component ($S_{\text{recency}}$)**:
  - If never cooked: $S_{\text{recency}}(m) = +25.0$ (rewards discovering untried meals).
  - If cooked: $S_{\text{recency}}(m) = \min\left(20.0, \; \frac{\Delta_{\text{days}}(m) - C_{\text{days}}}{2.0}\right)$.
- **Friday Special Component ($S_{\text{friday}}$)**:
  - If $\text{isFriday} == \text{true}$:
    - $m.\text{isFridaySpecial} == \text{true} \implies +15.0$
    - $m.\text{isFridaySpecial} == \text{false} \implies 0.0$
  - If $\text{isFriday} == \text{false}$:
    - $m.\text{isFridaySpecial} == \text{true} \implies -5.0$ (reserves festive dishes for weekends)
- **Favorite Component ($S_{\text{favorite}}$)**:
  - $m.\text{isFavorite} == \text{true} \implies +5.0$
- **Budget Component ($S_{\text{budget}}$)**:
  - $m.\text{isBudgetFriendly} == \text{true} \implies +2.0$
- **Deterministic Daily Jitter ($Jitter$)**:
  - $Jitter(m) = \left((T_{\text{today}}.\text{day} \times 17 + m.\text{id} \times 31) \pmod{100}\right) / 25.0$ (produces deterministic pseudo-random float $[0.0, 4.0]$ that stabilizes throughout the day).

### 3.4 3-Card Stack Selection & Inter-Card Diversity

To prevent generating 3 similar dishes (e.g. 3 chicken dishes) on the Home Screen:
1. Sort eligible candidates descending by $\text{Score}(m)$.
2. Select Card 1: Candidate with highest score: $R_1$.
3. Select Card 2: Highest scoring remaining candidate such that:
   $$\text{proteinType}(R_2) \neq \text{proteinType}(R_1)$$
   If no such candidate exists, pick next highest score.
4. Select Card 3: Highest scoring remaining candidate such that:
   $$\text{proteinType}(R_3) \notin \{\text{proteinType}(R_1), \text{proteinType}(R_2)\}$$
   If not possible, ensure $\text{carbsType}(R_3) \notin \{\text{carbsType}(R_1), \text{carbsType}(R_2)\}$.

### 3.5 Progressive Relaxation (Graceful Fallback Algorithm)

If the candidate pool yields fewer than 3 recommendations, the engine executes a deterministic 5-level relaxation cascade:

```
┌─────────────────────────────────────────────────────────────┐
│ Level 0: Strict                                             │
│ - Cooldown = C_days                                         │
│ - No repeat Protein AND No repeat Carbs                     │
└──────────────────────────┬──────────────────────────────────┘
                           │ If candidates < 3
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 1: Relax Carbs                                        │
│ - Cooldown = C_days                                         │
│ - No repeat Protein (Allow repeated Carbs)                  │
└──────────────────────────┬──────────────────────────────────┘
                           │ If candidates < 3
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 2: Halve Cooldown                                     │
│ - Cooldown = max(3, floor(C_days / 2))                      │
│ - No repeat Protein                                         │
└──────────────────────────┬──────────────────────────────────┘
                           │ If candidates < 3
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 3: Relax Protein & Minimal Cooldown                   │
│ - Cooldown = max(2, floor(C_days / 4))                      │
│ - Allow repeat Protein & Carbs                              │
└──────────────────────────┬──────────────────────────────────┘
                           │ If candidates < 3
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 4: Emergency Non-Same-Day                             │
│ - Only exclude meals cooked today (Delta_days == 0)         │
└──────────────────────────┬──────────────────────────────────┘
                           │ If candidates < 3
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Level 5: Minimal Inventory Handling                         │
│ - Return all distinct meals in DB                           │
│ - If DB has 0 meals: Emit EmptyVaultException to prompt     │
│   initial seed or manual entry                              │
└─────────────────────────────────────────────────────────────┘
```

The output structure contains metadata detailing the relaxation level:
```dart
class RecommendationResult {
  final List<Meal> recommendations; // Exactly 3 items (or fewer if DB has < 3 meals)
  final int relaxationLevel;        // 0 to 5
  final String relaxationReason;    // Arabic explanatory note (e.g. "تم تقليص فترة الاستبعاد لتوفير اقتراحات كافية")
  final DateTime computedDate;
}
```

---

## 4. Riverpod State Management Hierarchy

### 4.1 Dependency Graph

```
                   ┌───────────────────────┐
                   │   appDatabaseProvider │
                   └───────────┬───────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         ▼                     ▼                     ▼
┌─────────────────┐   ┌──────────────────┐   ┌───────────────────┐
│  mealsDaoProvider│   │mealHistoryDaoProv│   │appSettingsDaoProv │
└────────┬────────┘   └────────┬─────────┘   └─────────┬─────────┘
         │                     │                       │
         ▼                     ▼                       ▼
┌─────────────────┐   ┌──────────────────┐   ┌───────────────────┐
│mealVaultNotifier│   │mealHistoryNotif. │   │appSettingsNotifier│
└────────┬────────┘   └────────┬─────────┘   └─────────┬─────────┘
         │                     │                       │
         └──────────────┐      │      ┌────────────────┘
                        ▼      ▼      ▼
                 ┌─────────────────────────────┐
                 │todayRecommendationsNotifier │
                 └──────────────┬──────────────┘
                                │
                                ▼
                   ┌──────────────────────────┐
                   │ spinTheWheelNotifier     │
                   └──────────────────────────┘
```

### 4.2 Notifier Interfaces & Implementation Details

#### 1. `MealVaultNotifier`
```dart
@riverpod
class MealVaultNotifier extends _$MealVaultNotifier {
  @override
  Stream<List<Meal>> build() {
    final dao = ref.watch(mealsDaoProvider);
    return dao.watchAllMeals();
  }

  Future<void> addMeal(MealsCompanion meal) async {
    await ref.read(mealsDaoProvider).insertMeal(meal);
    // Riverpod automatically emits new state via the Drift stream!
  }

  Future<void> updateMeal(Meal meal) async {
    await ref.read(mealsDaoProvider).updateMeal(meal);
  }

  Future<void> deleteMeal(int id) async {
    await ref.read(mealsDaoProvider).deleteMeal(id);
  }

  Future<void> toggleFavorite(int id, bool currentStatus) async {
    await ref.read(mealsDaoProvider).toggleFavorite(id, !currentStatus);
  }
}
```

#### 2. `MealHistoryNotifier`
```dart
@riverpod
class MealHistoryNotifier extends _$MealHistoryNotifier {
  @override
  Stream<List<MealHistoryWithMeal>> build() {
    final dao = ref.watch(mealHistoryDaoProvider);
    return dao.watchHistory();
  }

  Future<void> logCookedToday(int mealId, {String? notes}) async {
    await ref.read(mealHistoryDaoProvider).logCookedMeal(
      mealId: mealId,
      date: DateTime.now(),
      status: MealHistoryStatus.cookedToday,
      notes: notes,
    );
  }

  Future<void> logLeftover(int mealId, {String? notes}) async {
    await ref.read(mealHistoryDaoProvider).logCookedMeal(
      mealId: mealId,
      date: DateTime.now(),
      status: MealHistoryStatus.leftover,
      notes: notes,
    );
  }

  Future<void> deleteLog(int id) async {
    await ref.read(mealHistoryDaoProvider).deleteHistoryEntry(id);
  }
}
```

#### 3. `AppSettingsNotifier`
```dart
@riverpod
class AppSettingsNotifier extends _$AppSettingsNotifier {
  @override
  Stream<AppSettingsData> build() {
    return ref.watch(appSettingsDaoProvider).watchSettings();
  }

  Future<void> setCooldownDays(int days) async {
    await ref.read(appSettingsDaoProvider).updateSettings(
      AppSettingsCompanion(cooldownDays: Value(days)),
    );
  }

  Future<void> togglePreventRepeatProtein(bool value) async {
    await ref.read(appSettingsDaoProvider).updateSettings(
      AppSettingsCompanion(preventRepeatProtein: Value(value)),
    );
  }

  Future<void> togglePreventRepeatCarbs(bool value) async {
    await ref.read(appSettingsDaoProvider).updateSettings(
      AppSettingsCompanion(preventRepeatCarbs: Value(value)),
    );
  }

  Future<void> setThemeMode(AppThemeModePreference mode) async {
    await ref.read(appSettingsDaoProvider).updateSettings(
      AppSettingsCompanion(themeMode: Value(mode)),
    );
  }

  Future<void> setNotificationTime(int hour, int minute) async {
    await ref.read(appSettingsDaoProvider).updateSettings(
      AppSettingsCompanion(
        notificationHour: Value(hour),
        notificationMinute: Value(minute),
      ),
    );
  }
}
```

#### 4. `TodayRecommendationsNotifier`
```dart
@riverpod
class TodayRecommendationsNotifier extends _$TodayRecommendationsNotifier {
  @override
  AsyncValue<RecommendationResult> build() {
    // 1. Listen to dependencies
    final mealsAsync = ref.watch(mealVaultNotifierProvider);
    final historyAsync = ref.watch(mealHistoryNotifierProvider);
    final settingsAsync = ref.watch(appSettingsNotifierProvider);

    if (mealsAsync.isLoading || historyAsync.isLoading || settingsAsync.isLoading) {
      return const AsyncValue.loading();
    }

    if (mealsAsync.hasError) return AsyncValue.error(mealsAsync.error!, mealsAsync.stackTrace!);
    if (historyAsync.hasError) return AsyncValue.error(historyAsync.error!, historyAsync.stackTrace!);
    if (settingsAsync.hasError) return AsyncValue.error(settingsAsync.error!, settingsAsync.stackTrace!);

    final meals = mealsAsync.value ?? [];
    final history = historyAsync.value ?? [];
    final settings = settingsAsync.value!;

    // 2. Compute recommendations using pure RecommendationEngine
    final engine = ref.read(recommendationEngineProvider);
    final result = engine.compute(
      meals: meals,
      history: history,
      settings: settings,
      today: DateTime.now(),
    );

    return AsyncValue.data(result);
  }

  void refresh() {
    ref.invalidateSelf();
  }
}
```

### 4.3 Immediate UI Reflection Verification Guarantee
When a user adds a meal via `AddMealScreen`:
1. `ref.read(mealVaultNotifierProvider.notifier).addMeal(newMeal)` executes.
2. Drift inserts the row into SQLite.
3. Drift's native query stream emits the new `List<Meal>`.
4. `mealVaultNotifierProvider` emits updated state.
5. `todayRecommendationsNotifierProvider` automatically recalculates with the new meal in the pool.
6. Both the Meal Vault list and Home recommendations update in the same UI frame with 0 manual event coordination.

---

## 5. GoRouter Routing Scheme & Arabic RTL Layout

### 5.1 Route Tree & StatefulShellRoute

Using `StatefulShellRoute.indexedStack` to preserve scroll positions across bottom navigation tabs:

```dart
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _vaultNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _historyNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _settingsNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Home (الرئيسية)
        StatefulShellBranch(
          navigatorKey: _homeNavigatorKey,
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'wheel',
                  name: 'wheel',
                  parentNavigatorKey: _rootNavigatorKey, // Fullscreen overlay
                  builder: (context, state) => const WheelRouletteDialog(),
                ),
              ],
            ),
          ],
        ),

        // Tab 2: Meal Vault (خزنة الأكلات)
        StatefulShellBranch(
          navigatorKey: _vaultNavigatorKey,
          routes: [
            GoRoute(
              path: '/vault',
              name: 'vault',
              builder: (context, state) => const MealVaultScreen(),
              routes: [
                GoRoute(
                  path: 'add',
                  name: 'addMeal',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const AddEditMealScreen(),
                ),
                GoRoute(
                  path: ':id',
                  name: 'mealDetails',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = int.parse(state.pathParameters['id']!);
                    return MealDetailsScreen(mealId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      name: 'editMeal',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final id = int.parse(state.pathParameters['id']!);
                        return AddEditMealScreen(mealId: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Tab 3: History (سجل الطبخ)
        StatefulShellBranch(
          navigatorKey: _historyNavigatorKey,
          routes: [
            GoRoute(
              path: '/history',
              name: 'history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),

        // Tab 4: Settings (الإعدادات)
        StatefulShellBranch(
          navigatorKey: _settingsNavigatorKey,
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
```

### 5.2 Material 3 Navigation Bar & RTL Layout Specification

In Arabic RTL, the start edge is on the right, and the end edge is on the left.
1. `NavigationBar` tabs order in code:
   - Index 0: الرئيسية (Home) -> Placed at the rightmost position in RTL.
   - Index 1: خزنة الأكلات (Meal Vault).
   - Index 2: السجل (History).
   - Index 3: الإعدادات (Settings) -> Placed at the leftmost position in RTL.
2. Icons & Forward/Back Navigation:
   - Always use `Icons.adaptive.arrow_back` or standard Flutter `BackButton()`. Flutter automatically mirrors navigation arrows in RTL mode without custom hacks.
3. Form Inputs & Alignments:
   - TextFields set `textAlign: TextAlign.start`.
   - Prefix icons are placed on the right, suffix icons on the left.
4. Material 3 Theme Configuration:
   ```dart
   final lightTheme = ThemeData(
     useMaterial3: true,
     colorScheme: ColorScheme.fromSeed(
       seedColor: const Color(0xFFE65100), // Culinary Deep Orange / Saffron
       brightness: Brightness.light,
     ),
     fontFamily: 'Cairo',
     appBarTheme: const AppBarTheme(
       centerTitle: false, // In RTL, title aligns right
     ),
   );
   ```

---

## 6. Comprehensive Testing Strategy (Tiers 1 to 4)

### 6.1 Testing Matrix Summary

| Tier | Name | Target Components | Execution Mode | Coverage Target |
|------|------|-------------------|----------------|-----------------|
| **Tier 1** | Pure Unit Tests | Cooldown Algorithm, Scoring, Progressive Fallback, Converters | `dart test` (headless) | 100% logic branches |
| **Tier 2** | Widget & State Tests | RTL directionality, Riverpod reactive updates, Card Stack UI | `flutter test` | 90% widget interactions |
| **Tier 3** | Integration / DAO Tests | In-memory Drift SQLite, Cascade Deletes, Reactive Streams | `flutter test` | 100% DAO queries |
| **Tier 4** | E2E User Flows | Complete user journeys (Cook meal -> Cooldown -> History) | `integration_test` / Golden tests | 100% critical user paths |

---

### 6.2 Tier 1: Unit Tests (Cooldown Algorithm & Scoring)

File: `test/unit/cooldown_algorithm_test.dart`

```dart
void main() {
  late RecommendationEngine engine;
  late List<Meal> mockMeals;
  final today = DateTime(2026, 9, 6); // Sunday

  setUp(() {
    engine = RecommendationEngine();
    mockMeals = [
      Meal(id: 1, name: 'فراخ ورز', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 45, isFridaySpecial: false, isBudgetFriendly: false, isFavorite: true, createdAt: today, updatedAt: today),
      Meal(id: 2, name: 'كفتة مشوية وعيش', proteinType: ProteinType.beef, carbsType: CarbsType.bread, category: MealCategory.egyptianTraditional, prepTimeMinutes: 30, isFridaySpecial: false, isBudgetFriendly: true, isFavorite: false, createdAt: today, updatedAt: today),
      Meal(id: 3, name: 'سمك ورز صيادية', proteinType: ProteinType.fish, carbsType: CarbsType.rice, category: MealCategory.seafood, prepTimeMinutes: 40, isFridaySpecial: true, isBudgetFriendly: true, isFavorite: false, createdAt: today, updatedAt: today),
      Meal(id: 4, name: 'كشري مصري', proteinType: ProteinType.legume, carbsType: CarbsType.pasta, category: MealCategory.egyptianTraditional, prepTimeMinutes: 50, isFridaySpecial: false, isBudgetFriendly: true, isFavorite: true, createdAt: today, updatedAt: today),
      Meal(id: 5, name: 'بانيه ومكرونة', proteinType: ProteinType.chicken, carbsType: CarbsType.pasta, category: MealCategory.fastFood, prepTimeMinutes: 30, isFridaySpecial: false, isBudgetFriendly: true, isFavorite: false, createdAt: today, updatedAt: today),
    ];
  });

  test('Filters out meals cooked within cooldown window (e.g. 14 days)', () {
    final history = [
      MealHistoryWithMeal(
        history: MealHistoryData(id: 1, mealId: 1, cookedDate: today.subtract(const Duration(days: 3)), status: MealHistoryStatus.cookedToday, createdAt: today),
        meal: mockMeals[0],
      ),
    ];

    final settings = AppSettingsData(id: 1, cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false, notificationHour: 12, notificationMinute: 0, notificationsEnabled: true, themeMode: AppThemeModePreference.system, isFirstRun: false);

    final result = engine.compute(meals: mockMeals, history: history, settings: settings, today: today);

    expect(result.recommendations.any((m) => m.id == 1), isFalse);
    expect(result.recommendations.length, equals(3));
  });

  test('Prevents back-to-back repeating protein when cooked yesterday', () {
    final history = [
      MealHistoryWithMeal(
        history: MealHistoryData(id: 1, mealId: 1, cookedDate: today.subtract(const Duration(days: 1)), status: MealHistoryStatus.cookedToday, createdAt: today),
        meal: mockMeals[0], // Chicken
      ),
    ];

    final settings = AppSettingsData(id: 1, cooldownDays: 14, preventRepeatProtein: true, preventRepeatCarbs: false, notificationHour: 12, notificationMinute: 0, notificationsEnabled: true, themeMode: AppThemeModePreference.system, isFirstRun: false);

    final result = engine.compute(meals: mockMeals, history: history, settings: settings, today: today);

    // Both meal 1 and meal 5 (chicken) must be excluded
    expect(result.recommendations.any((m) => m.proteinType == ProteinType.chicken), isFalse);
  });

  test('Friday specials receive bonus score on Fridays', () {
    final fridayDate = DateTime(2026, 9, 11); // Friday
    final settings = AppSettingsData(id: 1, cooldownDays: 14, preventRepeatProtein: false, preventRepeatCarbs: false, notificationHour: 12, notificationMinute: 0, notificationsEnabled: true, themeMode: AppThemeModePreference.system, isFirstRun: false);

    final result = engine.compute(meals: mockMeals, history: [], settings: settings, today: fridayDate);

    expect(result.recommendations.first.id, equals(3)); // Fish (Friday Special) ranked #1
  });

  test('Progressive relaxation degrades gracefully when candidates < 3', () {
    // Cook 4 out of 5 meals yesterday/recently
    final history = [
      MealHistoryWithMeal(history: MealHistoryData(id: 1, mealId: 1, cookedDate: today.subtract(const Duration(days: 1)), status: MealHistoryStatus.cookedToday, createdAt: today), meal: mockMeals[0]),
      MealHistoryWithMeal(history: MealHistoryData(id: 2, mealId: 2, cookedDate: today.subtract(const Duration(days: 2)), status: MealHistoryStatus.cookedToday, createdAt: today), meal: mockMeals[1]),
      MealHistoryWithMeal(history: MealHistoryData(id: 3, mealId: 3, cookedDate: today.subtract(const Duration(days: 3)), status: MealHistoryStatus.cookedToday, createdAt: today), meal: mockMeals[2]),
      MealHistoryWithMeal(history: MealHistoryData(id: 4, mealId: 4, cookedDate: today.subtract(const Duration(days: 4)), status: MealHistoryStatus.cookedToday, createdAt: today), meal: mockMeals[3]),
    ];

    final settings = AppSettingsData(id: 1, cooldownDays: 14, preventRepeatProtein: true, preventRepeatCarbs: true, notificationHour: 12, notificationMinute: 0, notificationsEnabled: true, themeMode: AppThemeModePreference.system, isFirstRun: false);

    final result = engine.compute(meals: mockMeals, history: history, settings: settings, today: today);

    expect(result.recommendations.length, equals(3));
    expect(result.relaxationLevel, greaterThan(0)); // Confirms relaxation triggered
  });
}
```

---

### 6.3 Tier 2: Widget & State Tests (RTL & Riverpod Reactivity)

File: `test/widget/rtl_and_state_test.dart`

```dart
void main() {
  testWidgets('App starts with RTL directionality and Arabic localization', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DailyMealApp(),
      ),
    );
    await tester.pumpAndSettle();

    final Directionality directionality = tester.widget(find.byType(Directionality).first);
    expect(directionality.textDirection, equals(TextDirection.rtl));
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('خزنة الأكلات'), findsOneWidget);
  });

  testWidgets('Adding a new meal immediately reflects on UI via Riverpod state', (tester) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());
    addTearDown(inMemoryDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const DailyMealApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to Vault Tab
    await tester.tap(find.text('خزنة الأكلات'));
    await tester.pumpAndSettle();

    // Verify initial state
    expect(find.text('طاجن عكاوي'), findsNothing);

    // Add meal via controller
    final container = ProviderScope.containerOf(tester.element(find.byType(DailyMealApp)));
    await container.read(mealVaultNotifierProvider.notifier).addMeal(
      MealsCompanion.insert(
        name: 'طاجن عكاوي',
        proteinType: ProteinType.beef,
        carbsType: CarbsType.bread,
        category: MealCategory.ovenBaked,
        prepTimeMinutes: 90,
      ),
    );

    // Pump frame
    await tester.pumpAndSettle();

    // Immediate UI reflection verified
    expect(find.text('طاجن عكاوي'), findsOneWidget);
  });
}
```

---

### 6.4 Tier 3: Integration & DAO Tests (Drift SQLite)

File: `test/integration/drift_dao_test.dart`

```dart
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('MealsDao: CRUD operations and cascade delete on history', () async {
    // 1. Insert meal
    final mealId = await db.mealsDao.insertMeal(
      MealsCompanion.insert(
        name: 'شاورما فراخ',
        proteinType: ProteinType.chicken,
        carbsType: CarbsType.bread,
        category: MealCategory.fastFood,
        prepTimeMinutes: 25,
      ),
    );

    // 2. Log in history
    await db.mealHistoryDao.logCookedMeal(
      mealId: mealId,
      date: DateTime.now(),
      status: MealHistoryStatus.cookedToday,
    );

    var history = await db.mealHistoryDao.getRecentHistory();
    expect(history.length, equals(1));
    expect(history.first.meal.name, equals('شاورما فراخ'));

    // 3. Delete meal -> verify cascade delete
    await db.mealsDao.deleteMeal(mealId);

    history = await db.mealHistoryDao.getRecentHistory();
    expect(history.isEmpty, isTrue); // Cascaded!
  });

  test('AppSettingsDao: Singleton defaults and reactive updates', () async {
    final settings = await db.appSettingsDao.getSettings();
    expect(settings.cooldownDays, equals(14));
    expect(settings.preventRepeatProtein, isTrue);

    await db.appSettingsDao.updateSettings(
      const AppSettingsCompanion(cooldownDays: Value(21)),
    );

    final updated = await db.appSettingsDao.getSettings();
    expect(updated.cooldownDays, equals(21));
  });
}
```

---

### 6.5 Tier 4: E2E User Flow Tests

File: `integration_test/recommendation_and_cooking_flow_test.dart`

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E Flow: Recommend -> Cook Today -> Cooldown Enforced -> History Logged', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DailyMealApp()));
    await tester.pumpAndSettle();

    // 1. Home screen shows 3 recommendation cards
    expect(find.byType(MealRecommendationCard), findsNWidgets(3));

    final firstCardName = (tester.widget(find.byType(MealRecommendationCard).first) as MealRecommendationCard).meal.name;

    // 2. Tap "طبخت دي النهاردة" on top card
    await tester.tap(find.text('طبخت دي النهاردة').first);
    await tester.pumpAndSettle();

    // 3. Verify card updates and cooked meal is no longer in recommendations
    expect(find.text(firstCardName), findsNothing);

    // 4. Switch to History tab
    await tester.tap(find.text('السجل'));
    await tester.pumpAndSettle();

    // 5. Verify the meal appears at the top of the history timeline
    expect(find.text(firstCardName), findsOneWidget);
    expect(find.text('طبخة جديدة'), findsOneWidget);
  });
}
```

---

## 7. Operational & Build Verification Plan

### 7.1 Code Generation Command
```bash
dart run build_runner build --delete-conflicting-outputs
```
Target Generated Artifacts:
- `lib/core/database/app_database.g.dart`
- Riverpod generator annotations (if using `.g.dart` notifiers)

### 7.2 Static Analysis & Quality Gate
```bash
flutter analyze
```
Requirement: `0 issues found`.

### 7.3 Android APK Build Verification
```bash
flutter build apk --debug
```
Requirement: Build succeeds without Gradle conflicts or desugaring errors.

---

## 8. Summary of Architectural Decisions & Risk Mitigations

| Architectural Area | Decision Made | Rationale & Mitigation |
|--------------------|---------------|------------------------|
| **Database Engine** | Drift SQLite (`NativeDatabase`) | Native performance, reactive query streams, compile-time SQL validation, zero cloud dependency. |
| **State Management** | Riverpod 2.6+ with code gen / AsyncNotifier | Guarantees testability, removes global state leakage, auto-invalidates downstream recommendations when database changes. |
| **Cooldown Fallback** | 5-Tier Progressive Relaxation | Prevents empty Home screen when vault has few meals or strict filters conflict. |
| **RTL Support** | Native `Directionality.rtl` + Material 3 | Full Egyptian Arabic experience; automatic icon mirroring; prevents horizontal scroll clipping. |
| **Seed Strategy** | 20 Egyptian meals on `onCreate` | App is instantly useful upon first install without requiring tedious manual meal entry. |
