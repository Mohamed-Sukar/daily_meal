# Milestone 3 Implementation Changes

**Identity:** `teamwork_preview_worker_m3`  
**Milestone:** Milestone 3 (Presentation Layer & Riverpod State)  
**Date:** 2026-09-07  

---

## 1. Summary of Work

Milestone 3 establishes the complete presentation layer, navigation framework, and reactive Riverpod state architecture for "أكلة النهاردة" (Daily Meal) — strictly offline-first, Egyptian Arabic localized (RTL), and powered by Drift SQLite.

All 186 unit, widget, and end-to-end integration tests pass, and `flutter analyze` reports zero issues.

---

## 2. Inventory of Changes by File

### 2.1 Dependencies & Configuration
- **`pubspec.yaml`**:
  - Added `flutter_localizations: sdk: flutter` for native Arabic RTL support.
  - Added `flutter_riverpod: ^2.6.1` for state management.
  - Added `go_router: ^14.8.1` for shell navigation.

### 2.2 Core Layer
- **`lib/core/constants/app_constants.dart`**:
  - Defined app name, routes (`/`, `/vault`, `/history`, `/settings`), default cooldown bounds, and roulette minimum candidates.
- **`lib/core/theme/app_theme.dart`**:
  - Defined Material 3 `lightTheme` and `darkTheme` based on warm Egyptian culinary colors (seed color: `Color(0xFFC04A26)` terracotta brick, saffron amber, nile teal).
  - Styled Cards (16dp rounded corners), NavigationBar, Chips, Dialogs, and Buttons.
- **`lib/core/router/app_router.dart`**:
  - Configured `GoRouter` with `StatefulShellRoute.indexedStack` managing 4 tabs:
    - Tab 0: `/` -> `HomeScreen` (`الرئيسية`, key: `nav_destination_home`)
    - Tab 1: `/vault` -> `MealVaultScreen` (`خزانة الأكلات`, key: `nav_destination_vault`)
    - Tab 2: `/history` -> `HistoryScreen` (`السجل`, key: `nav_destination_history`)
    - Tab 3: `/settings` -> `SettingsScreen` (`الإعدادات`, key: `nav_destination_settings`)
  - Implemented `ScaffoldWithNavBar` with RTL navigation alignment.
- **`lib/core/database/database_providers.dart`**:
  - Exposed singleton `AppDatabase` via `databaseProvider` (with `ref.onDispose(() => db.close())`).
  - Exposed DAOs: `mealsDaoProvider`, `mealHistoryDaoProvider`, `appSettingsDaoProvider`.

### 2.3 Riverpod State Providers & Controllers
- **`lib/features/vault/providers/vault_providers.dart`**:
  - `allMealsProvider`: StreamProvider watching SQLite via `MealsDao.watchAllMeals()`.
  - `favoriteMealsProvider`: StreamProvider watching `MealsDao.watchFavorites()`.
  - `VaultFilterState` & `VaultFilterNotifier`: Multi-criteria search and filter state.
  - `filteredMealsProvider`: Reactive derived provider filtering meals by name, category, protein, carbs, and tags.
  - `VaultController`: Mutation controller with `addMeal`, `addMealCompanion`, `updateMeal`, `deleteMeal`, and `toggleFavorite`.
- **`lib/features/home/providers/recommendation_provider.dart`**:
  - `todayRecommendationsProvider`: Reactive derived provider calculating `CooldownEngine.compute()` from live database streams and current date.
  - `spinWheelCandidatesProvider`: Roulette candidate pool requiring >= 2 candidates.
  - `RecommendationController`: Mutation controller with `logCookedToday`, `markCookedToday`, `logLeftover`, `markLeftover`, and `undoLastCookingLog`.
  - `HomeController`: Random selection engine for Spin the Wheel.
- **`lib/features/history/providers/history_providers.dart`**:
  - `mealHistoryProvider`: StreamProvider watching `MealHistoryDao.watchHistory()`.
  - `mealHistoryWithMealProvider`: StreamProvider joining history logs with meal entities.
  - `latestCookedMealProvider`: StreamProvider watching latest single cooked meal entry.
  - `HistoryController`: Mutation controller for logging meals, deleting entries, and clearing history.
- **`lib/features/settings/providers/settings_providers.dart`**:
  - `appSettingsProvider`: StreamProvider watching singleton settings row.
  - `themeModeProvider`: Provider mapping `AppThemeModePreference` to Flutter's `ThemeMode`.
  - `SettingsController`: Mutation controller with `updateCooldownDays`, `updateThemeMode`, `updateNotificationTime`, `toggleNotifications`, `updateDietaryRules`, and `resetToDefaults`.

### 2.4 Presentation Layer (Home Feature)
- **`lib/features/home/presentation/home_screen.dart`**:
  - Time-personalized Egyptian Arabic greeting header.
  - "لف العجلة" (Spin the Wheel) CTA with dynamic validation.
  - Fallback relaxation banner displayed when `relaxationLevel > 0` with `result.relaxationReason`.
  - 3-Card Stack display with elevation hierarchy.
  - Centered empty state when vault is empty ("خزنة الأكلات فارغة!").
- **`lib/features/home/presentation/widgets/meal_card.dart`**:
  - Card with priority banner (Star recommendation vs alternatives).
  - Title wrapped up to 3 lines (`maxLines: 3, TextOverflow.ellipsis`) to eliminate text overflow risks.
  - Localized Arabic prep time formatting (`formatPrepTime`).
  - Category, protein, and carbs chips.
  - Friday special, budget friendly, and favorite badges.
  - Embedded QuickActions.
- **`lib/features/home/presentation/widgets/quick_actions.dart`**:
  - RTL-aligned quick action buttons: primary "طبخت دي النهاردة" (`dx(cooked) > dx(leftover)`) and secondary "بواقي أكل".
- **`lib/features/home/presentation/widgets/spin_wheel_dialog.dart`**:
  - Animated modal roulette wheel with decelerating friction curve (`Curves.easeOutCubic`).
  - Custom wheel painter rendering circular wedges in warm palette with radiating Arabic meal titles.
  - Top pointer indicator and center hub.
  - Verification ensuring >= 2 candidates before spinning.

### 2.5 Presentation Layer (Vault Feature)
- **`lib/features/vault/presentation/meal_vault_screen.dart`**:
  - Top search bar with `Key('vault_search_field')` and clear action `Key('vault_search_clear_button')`.
  - Active meal count badge.
  - Horizontally scrolling filter chips bar.
  - Reactive list view displaying `MealVaultCard`s.
  - FloatingActionButton with `Key('vault_add_fab')` for "إضافة أكلة".
- **`lib/features/vault/presentation/widgets/vault_filter_bar.dart`**:
  - Filter chips for Protein, Carbs, and special tags.
  - Active filter count and reset button.
- **`lib/features/vault/presentation/widgets/meal_vault_card.dart`**:
  - Container with `Key('meal_card_${meal.id}')`.
  - Thumbnail or Egyptian kitchen category placeholder.
  - Action buttons: favorite toggle (`Key('meal_favorite_button_${meal.id}')`), edit (`Key('meal_edit_button_${meal.id}')`), and delete (`Key('meal_delete_button_${meal.id}')`).
- **`lib/features/vault/presentation/widgets/vault_empty_state.dart`**:
  - Handled 0-meal vault ("خزنة الأكلات فارغة!" with CTA "أضف أكلتك الأولى" key `vault_empty_add_button`).
  - Handled 0-match search/filter ("لا توجد نتائج مطابقة" with CTA "إعادة ضبط الفلاتر والبحث" key `vault_clear_filters_button`).
- **`lib/features/vault/presentation/add_edit_meal_dialog.dart`**:
  - Add & Edit modal with form validation (min 2 chars, max 120 chars, positive prep time).
  - Category, protein, and carbs dropdowns.
  - Friday special, budget friendly, and favorite switch tiles.
  - Verified test keys for automated testing.
- **`lib/features/vault/presentation/widgets/delete_meal_dialog.dart`**:
  - Safe deletion confirmation dialog explicitly reassuring the user that cooking history is preserved via foreign key `ON DELETE SET NULL`.
  - Keys: `meal_delete_cancel_button`, `meal_delete_confirm_button`.

### 2.6 Presentation Layer (History & Settings Features)
- **`lib/features/history/presentation/history_screen.dart`**:
  - Chronological timeline of cooked and leftover meals.
  - Individual entry deletion and mass clear history action.
- **`lib/features/settings/presentation/settings_screen.dart`**:
  - Cooldown duration slider (1-60 days) with Arabic dual and plural grammar formatting (`formatCooldown`).
  - Material 3 theme switcher (System / Light / Dark).
  - Dietary repeat prevention toggles for protein and carbs.
  - Daily notification reminder toggle and time picker.
  - Reset to default settings action.

### 2.7 Application Entry Point & Testing
- **`lib/main.dart`**:
  - Configured `ProviderScope`, `MaterialApp.router`, `Locale('ar')`, RTL `Directionality`, and `GlobalMaterialLocalizations` delegates.
- **`test/widget_test.dart`**:
  - Updated smoke test to pump `DailyMealApp` with `ProviderScope` and in-memory test database.
- **`test/unit/riverpod_container_reactivity_test.dart`**:
  - Added unit test suite for testing `allMealsProvider`, `recommendationProvider`, and `filteredMealsProvider` reactivity directly on `ProviderContainer`.
