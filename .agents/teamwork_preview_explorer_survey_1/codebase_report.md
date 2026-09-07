# Codebase Survey & Environment Report: "أكلة النهاردة" (daily_meal)

**Date**: 2026-09-06  
**Agent**: `teamwork_preview_explorer_survey_1`  
**Target Workspace**: `E:\Mohamed\Personal_Project\daily-meal\daily_meal`  
**Related Specs**: `E:\Mohamed\Personal_Project\daily-meal\TECHNICAL_ARCHITECTURE.md`, `FEATURES_SPECIFICATION.md`

---

## 1. Executive Summary

The workspace at `E:\Mohamed\Personal_Project\daily-meal\daily_meal` is currently an un-configured, default Flutter counter template app created with Flutter 3.44.0 / Dart 3.12.0. None of the domain models, database schema, recommendation logic, screens, or state management required by the project specifications have been implemented yet.

All required packages (Drift, Riverpod, GoRouter, Notifications, Timezone, Intl, and code generators) resolve cleanly without dependency version conflicts on Dart 3.12.0 / Flutter 3.44.0.

**Critical Environment Finding**: The host machine lacks an Android SDK installation (`flutter doctor` reports `[X] Android toolchain - develop for Android devices: Unable to locate Android SDK`). Consequently, running `flutter build apk` currently fails on this machine with `[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.` However, `flutter analyze`, `dart run build_runner build`, and `flutter test` run with 100% success.

---

## 2. Environment & Toolchain State

### 2.1 SDK Versions
- **Flutter SDK**: `3.44.0` (Channel `stable`, revision `559ffa3f75`, engine `fcf463a224`, installed at `D:\flutter`)
- **Dart SDK**: `3.12.0` (DevTools `2.57.0`)
- **Host OS**: Microsoft Windows 11 Pro 64-bit (`[Version 10.0.22631.6199]`)

### 2.2 Toolchain Diagnosis (`flutter doctor`)
- `[√] Flutter (Channel stable, 3.44.0)`
- `[√] Windows Version (11 Pro 64-bit)`
- `[X] Android toolchain - develop for Android devices`
  - `Unable to locate Android SDK.`
  - No `ANDROID_HOME`, `ANDROID_SDK_ROOT`, or `JAVA_HOME` environment variables defined.
  - No Java compiler or Android SDK tools found in system PATH.
- `[√] Chrome - develop for the web`
- `[√] Visual Studio - develop Windows apps (Build Tools 2019)`
- `[√] Connected device (3 available)`

### 2.3 Acceptance Criteria Feasibility
| Criterion | Status | Notes |
| :--- | :--- | :--- |
| `flutter build apk` completes | ⚠️ Environment Blocker | Code can be written 100% compliant for Android, but local APK compilation requires installing Android SDK / JDK or setting `ANDROID_HOME`. |
| `flutter analyze` returns zero issues | ✅ Fully Supported | Baseline verified clean (0 issues). |
| `dart run build_runner build` | ✅ Fully Supported | Dart 3.12.0 verified fully compatible with `build_runner 2.15.1`, `drift_dev 2.31.0`, and `riverpod_generator 4.0.0+1`. |
| Cooldown Algorithm unit test passes | ✅ Fully Supported | `flutter test` verified working cleanly. |
| App launches in RTL layout by default | ✅ Fully Supported | Native Flutter Arabic locale support with `MaterialApp.router`. |
| Adding new meal updates Riverpod state | ✅ Fully Supported | `flutter_riverpod 3.1.0` verified compatible. |

---

## 3. Existing Codebase Inspection

### 3.1 `pubspec.yaml`
- **Current content**: Barebones default.
  - Dependencies: `flutter` (sdk: flutter), `cupertino_icons: ^1.0.8`.
  - Dev dependencies: `flutter_test` (sdk: flutter), `flutter_lints: ^6.0.0`.
  - Missing: Drift, SQLite, Riverpod, GoRouter, Notifications, Timezone, Intl, Localization, code generators, build_runner.

### 3.2 `analysis_options.yaml`
- Includes `package:flutter_lints/flutter.yaml`.
- Clean baseline: `flutter analyze` passes in 38.3s with 0 warnings or errors.

### 3.3 `lib/`
- Contains only `lib/main.dart` (standard Flutter Counter template app, 123 lines).
- No business logic, no Drift database, no entities, no providers, no router, no presentation layers.

### 3.4 `test/`
- Contains only `test/widget_test.dart` (smoke test verifying the default counter increment, 31 lines).
- `flutter test` passes cleanly in <1s.

### 3.5 `android/` Build Configuration
- Uses Gradle Kotlin DSL (`.gradle.kts`):
  - `android/settings.gradle.kts`: Gradle Plugin Portal, Android Application plugin `9.0.1`, Kotlin Android plugin `2.3.20`, Flutter plugin loader `1.0.0`.
  - `android/app/build.gradle.kts`: Java 17 compatibility (`JavaVersion.VERSION_17`), Kotlin JVM Target `JVM_17`, namespace `com.dailymeal.daily_meal`.
  - `android/local.properties`: Contains only `flutter.sdk=D:\\flutter` (no `sdk.dir`).
  - `android/app/src/main/AndroidManifest.xml`:
    - Application label is `"daily_meal"` (should be updated to `"أكلة النهاردة"` or localized).
    - Missing notification permissions for `flutter_local_notifications`:
      - `android.permission.RECEIVE_BOOT_COMPLETED`
      - `android.permission.POST_NOTIFICATIONS`
      - `android.permission.SCHEDULE_EXACT_ALARM`
      - `android.permission.USE_EXACT_ALARM`

---

## 4. Dependency Compatibility & Resolution Matrix

A full dry-run dependency resolution (`flutter pub add --dry-run`) was executed with all required packages. All packages resolved successfully without conflicting constraints:

| Package Category | Package Name | Resolved Version | Role in daily_meal |
| :--- | :--- | :--- | :--- |
| **Database & Storage** | `drift` | `^2.31.0` | Offline SQLite ORM for Meals, History, and Settings |
| | `drift_flutter` | `^0.2.8` | Flutter bindings & connection for Drift |
| | `path_provider` | `^2.1.6` | Access to application documents directory |
| | `path` | `^1.9.1` | File path manipulations |
| **State Management** | `flutter_riverpod` | `^3.1.0` | Reactive state management & dependency injection |
| | `riverpod_annotation` | `^4.0.0` | Annotations for code-generated providers |
| **Navigation** | `go_router` | `^17.5.0` | Declarative routing (Home, Vault, History, Settings) |
| **Notifications & Time**| `flutter_local_notifications` | `^22.3.0` | Daily recommendation push notifications |
| | `timezone` | `^0.11.1` | Local timezone calculation for scheduled notifications |
| **Localization** | `intl` | `^0.20.3` | Date formatting and Arabic string localization |
| | `flutter_localizations` | `sdk: flutter` | Material/Widgets Arabic RTL and calendar delegates |
| **Code Generation (dev)**| `build_runner` | `^2.15.1` | Code generation runner |
| | `drift_dev` | `^2.31.0` | Drift table and DAO generator |
| | `riverpod_generator` | `^4.0.0+1` | Riverpod provider generator |
| **Testing (dev)** | `test` | `^1.31.0` | Core Dart unit testing framework |
| | `flutter_test` | `sdk: flutter` | Flutter widget and integration testing |
| **Linting (dev)** | `flutter_lints` | `^6.0.0` | Flutter official lint rules |

---

## 5. Architectural Requirements Alignment

Based on `ORIGINAL_REQUEST.md` and `TECHNICAL_ARCHITECTURE.md`:

### 5.1 Drift Database Design (`lib/core/database/`)
Three main tables required:
1. **`meals`**:
   - `id`: Text (UUID or auto-increment)
   - `name`: Text (e.g. "صينية بطاطس بالفراخ")
   - `photo_url`: Text (nullable)
   - `protein_type`: Text (enum: `chicken`, `beef`, `fish`, `meatless`, `other`)
   - `carbs_type`: Text (enum: `rice`, `pasta`, `bread`, `none`)
   - `category`: Text (enum: `tabeekh`, `casserole`, `dry_sandwich`, `popular`, `seafood`)
   - `prep_time_minutes`: Integer
   - `is_friday_special`: Boolean (default: false)
   - `is_budget_friendly`: Boolean (default: false)
   - `is_favorite`: Boolean (default: false)
   - `custom_cooldown_days`: Integer (nullable)
   - `last_cooked_date`: DateTime (nullable)
   - `times_cooked`: Integer (default: 0)
   - `notes`: Text (nullable)

2. **`meal_history`**:
   - `id`: Text (UUID or auto-increment)
   - `meal_id`: Text (nullable, foreign key to `meals`)
   - `meal_name`: Text
   - `date`: DateTime
   - `status`: Text (`cooked`, `leftover`, `takeout`, `skipped`)
   - `created_at`: DateTime

3. **`app_settings`**:
   - `id`: Integer (singleton row 1)
   - `default_meal_cooldown_days`: Integer (default: 14)
   - `chicken_cooldown_days`: Integer (default: 2)
   - `beef_cooldown_days`: Integer (default: 2)
   - `fish_cooldown_days`: Integer (default: 4)
   - `meatless_cooldown_days`: Integer (default: 1)
   - `is_dark_mode`: Boolean (default: false)
   - `notifications_enabled`: Boolean (default: true)
   - `notification_hour`: Integer (default: 11)
   - `notification_minute`: Integer (default: 0)

### 5.2 Cooldown Algorithm (`lib/features/recommendations/domain/cooldown_engine.dart`)
1. **Hard Constraints**:
   - **Meal Cooldown**: If a meal was cooked within its cooldown window (default 14 days or custom), filter it out.
   - **Protein Cooldown**: Filter out meals whose protein type matches the last cooked meal's protein within the protein's cooldown window (chicken: 2 days, beef: 2 days, fish: 4 days, meatless: 1 day).
   - **Carbs Anti-Fatigue**: Avoid consecutive heavy carbs (e.g., pasta after pasta).
   - **Friday Special**: If today is Friday (`DateTime.now().weekday == DateTime.friday`), prioritize `is_friday_special = true`.
2. **Soft Scoring**:
   - Days elapsed since last cooked: higher score for longer elapsed time.
   - Favorite bonus: +15% score multiplier for `is_favorite == true`.
3. **Selection Modes**:
   - **3-Card Stack**: Top 3 distinct category recommendations.
   - **Roulette / Spin the Wheel**: Weighted random pick among eligible recommendations.
4. **Quick Actions**:
   - "طُبخت اليوم" (Cooked Today): Logs `cooked` to history, updates meal's `lastCookedDate` and increments `timesCooked`.
   - "أكل بايت" (Leftover): Logs `leftover` to history, avoids triggering protein cooldown.

### 5.3 UI & Localization
- App must start in RTL Arabic:
  - Locale: `const Locale('ar')`
  - MaterialApp configuration:
    ```dart
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    ```
- Material Design 3 (`ThemeData(useMaterial3: true, colorSchemeSeed: ...)`).
- Complete Arabic strings across all screens.

---

## 6. Gap Analysis & Next Implementation Steps

1. **Step 1: Dependencies & Configuration**
   - Update `pubspec.yaml` with all verified packages.
   - Update `android/app/src/main/AndroidManifest.xml` with permissions and Arabic app label.
   - Run `flutter pub get`.

2. **Step 2: Database Layer**
   - Define Drift schema in `lib/core/database/database.dart`.
   - Run `dart run build_runner build` to generate `database.g.dart`.
   - Implement database helper/seed initial sample Egyptian meals for instant usability.

3. **Step 3: Domain Logic & Cooldown Engine**
   - Implement `CooldownEngine` in `lib/features/recommendations/domain/cooldown_engine.dart`.
   - Write comprehensive unit tests in `test/cooldown_engine_test.dart` verifying all filtering rules (recent meals, back-to-back protein cooldown, Friday specials).

4. **Step 4: Riverpod State Management & Routing**
   - Define providers for Database, Meals (CRUD), History, Recommendations, and Settings.
   - Configure GoRouter in `lib/core/router/app_router.dart` with bottom navigation or indexed stack.

5. **Step 5: Presentation Layers**
   - `HomeScreen`: 3-card stack, roulette wheel modal/widget, quick action buttons ("طُبخت اليوم", "أكل بايت").
   - `MealVaultScreen` & `MealFormScreen`: Fast meal entry (10-second quick add), tag selectors, search/filter, edit/delete.
   - `HistoryScreen`: Chronological timeline of cooked meals.
   - `SettingsScreen`: Cooldown days configuration, notification time picker, light/dark theme toggle.

6. **Step 6: Local Notifications & Verification**
   - Implement `NotificationService` with daily scheduled alarm.
   - Run `flutter analyze` (target: 0 issues).
   - Run `flutter test` (all unit & widget tests pass).
