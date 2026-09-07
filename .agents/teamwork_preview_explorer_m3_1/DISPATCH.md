## 2026-09-07T00:17:56Z
You are the Explorer for Milestone 3: Presentation Layer & Riverpod State (identity: teamwork_preview_explorer_m3_1).
Working directory: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m3_1
Parent conversation ID: 3efea0b8-0374-4d39-8f46-d670012fcd8a

MANDATORY: Read the full, verbatim user request at:
E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\PROJECT.md
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\lib\core\database\app_database.dart
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\lib\core\database\daos\meals_dao.dart
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\lib\core\database\daos\meal_history_dao.dart
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\lib\core\database\daos\app_settings_dao.dart
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\lib\features\home\domain\cooldown_engine.dart
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\test\widget\riverpod_reactivity_test.dart

Objective:
Design the Riverpod state management hierarchy and provider architecture for the entire app:
1. Core database providers: `databaseProvider`, `mealsDaoProvider`, `mealHistoryDaoProvider`, `appSettingsDaoProvider`.
2. StreamProviders:
   - `allMealsProvider` watching `MealsDao.watchAllMeals()`.
   - `mealHistoryProvider` watching `MealHistoryDao.watchHistory()`.
   - `appSettingsProvider` watching `AppSettingsDao.watchSettings()`.
3. Domain recommendations provider:
   - `recommendationProvider`: derived provider taking all meals, history, settings, and returning `RecommendationResult` from `CooldownEngine.getRecommendations()`. Explain how state reacts immediately and updates Home Screen when meals or history mutate.
4. Mutation Notifiers / Controllers:
   - Methods to add meal, update meal, delete meal, toggle favorite.
   - Methods to log meal as 'cooked' or 'leftover' with automatic history logging.
   - Methods to update settings (cooldown days, theme mode, notification time).
5. Specify exact file locations, provider types, and signatures.
Write your architecture blueprint to `m3_riverpod_plan.md` and `handoff.md` in your working directory, and notify parent via send_message.
