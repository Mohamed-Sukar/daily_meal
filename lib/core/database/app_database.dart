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
export 'seed/initial_meals.dart';

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

extension MealX on Meal {
  int get prepTimeMinutes => prepTime;
}

extension MealHistoryDataX on MealHistoryData {
  DateTime get cookedDate => cookedAt;
}

typedef AppSetting = AppSettingsData;

extension AppSettingsDataX on AppSettingsData {
  bool get notificationEnabled => notificationsEnabled;
}
