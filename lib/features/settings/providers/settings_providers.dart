import 'dart:async';
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

/// Mutation controller for application settings.
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
