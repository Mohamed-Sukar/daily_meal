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
