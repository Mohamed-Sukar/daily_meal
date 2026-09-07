## 2026-09-06T21:07:15Z

You are the Implementation Worker for Milestone 1: Core Database & Drift Layer (identity: teamwork_preview_worker_m1).
Working directory: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_worker_m1
Parent conversation ID: 3efea0b8-0374-4d39-8f46-d670012fcd8a

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY: Read the full, verbatim user request at:
E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md

Read the Explorer Implementation Blueprints:
- Schema & Tables Blueprint: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m1_1\m1_schema_plan.md
- DAOs & Queries Blueprint: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m1_2\m1_dao_plan.md
- Build, Dependencies & Tests Blueprint: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m1_3\m1_build_plan.md
- Project Scope: E:\Mohamed\Personal_Project\daily-meal\daily_meal\PROJECT.md

File Ownership Boundaries:
You EXCLUSIVELY own:
- `pubspec.yaml`
- `build.yaml`
- `lib/core/database/**`
- `test/unit/database_test.dart`
Do NOT edit any files in `test/support/` or `test/e2e/` (owned by Track A).

Objective:
Implement Milestone 1 fully and verify:
1. Update `pubspec.yaml` to include Drift dependencies (`drift: ^2.24.0`, `drift_flutter: ^0.2.4`, `sqlite3_flutter_libs: ^0.5.24`, `path_provider: ^2.1.5`, `path: ^1.9.1`, `dev:drift_dev: ^2.24.0`, `dev:build_runner: ^2.4.13`).
2. Add `build.yaml` with Drift SQLite configuration (`store_date_time_values_as_text: true`).
3. Create all tables in `lib/core/database/tables/`:
   - `meals_table.dart`: Meals table with name, photoPath, proteinType, carbsType, category, prepTime, isFridaySpecial, isBudgetFriendly, isFavorite.
   - `meal_history_table.dart`: MealHistory table with nullable mealId (foreign key with `KeyAction.setNull`), snapshot fields (mealName, proteinType, carbsType), cookedAt, entryType ('cooked'/'leftover').
   - `app_settings_table.dart`: AppSettings singleton table (id = 1) with cooldownDays (default 14), themeMode, notificationEnabled, notificationHour (12), notificationMinute (0), preventRepeatProtein, preventRepeatCarbs.
4. Create `lib/core/database/seed/initial_meals.dart` containing 20 authentic Egyptian starter dishes.
5. Create `lib/core/database/app_database.dart` with `driftDatabase(name: 'daily_meal_db')`, optional QueryExecutor constructor for tests, `onCreate` seeding of AppSettings and 20 starter meals, and `PRAGMA foreign_keys = ON` in `beforeOpen`.
6. Create DAOs in `lib/core/database/daos/`:
   - `meals_dao.dart`: Full CRUD, `watchAllMeals()`, `searchMeals()`, `filterByTag()`.
   - `meal_history_dao.dart`: `logMeal()`, `watchHistory()`, `getRecentHistory()`, `getHistoryWithinDays()`, `deleteHistoryEntry()`.
   - `app_settings_dao.dart`: `watchSettings()`, mutators for cooldown, theme, and notifications.
7. Run `flutter pub get`.
8. Run `dart run build_runner build --delete-conflicting-outputs`.
9. Implement `test/unit/database_test.dart` with comprehensive tests using `NativeDatabase.memory()` covering all 5 groups from `m1_build_plan.md`.
10. Run `flutter test test/unit/database_test.dart` and verify 100% pass.
11. Run `flutter analyze` and fix any issues so that 0 issues are found.

Output Requirements:
Write your implementation details to `changes.md` and a formal `handoff.md` in your working directory (`E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_worker_m1`).
Include exact command outputs for `flutter pub get`, `dart run build_runner build`, `flutter test test/unit/database_test.dart`, and `flutter analyze`.
Notify parent via `send_message` when done.
