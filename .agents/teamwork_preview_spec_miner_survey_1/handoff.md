# Handoff Report: Specification Mining for 'أكلة النهاردة' Flutter MVP

**Agent ID:** `teamwork_preview_spec_miner_survey_1`  
**Role:** Specification Miner  
**Date:** 2026-09-06  
**Handoff Type:** Hard (Task Complete)  
**Parent Agent:** `teamwork_preview_orchestrator_1` (Conversation ID: `3efea0b8-0374-4d39-8f46-d670012fcd8a`)  

---

## 1. Observation

1. **Authoritative Specification Source (`ORIGINAL_REQUEST.md`)**:
   - Location: `E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md` (Lines 1-37).
   - Verbatim requirements:
     - Line 5: `"Build the MVP of "أكلة النهاردة", an Offline-First Flutter (Android) app that recommends daily meals from a local database using a cooldown algorithm."`
     - Line 13 (R1): `"Implement local storage using Drift (SQLite). Users must be able to add, edit, delete, and view meals. A meal has properties: name, optional photo path, protein type, carbs type, category, prep time, and boolean tags (Friday special, budget friendly, favorite). Include a meal_history table to track when meals were cooked, and an app_settings table."`
     - Line 16 (R2): `"Implement the core UI and logic. The Home screen should display a 3-card stack of meal recommendations. The recommendations must be powered by a Cooldown Algorithm that filters out meals cooked recently (e.g., within 14 days) and prevents back-to-back repeating of protein/carbs. Include a "Spin the Wheel" roulette feature for random selection, and quick actions to mark a meal as "cooked today" or "leftover"."`
     - Line 19 (R3): `"Implement a History screen displaying a chronological log of past meals. Implement a Settings screen to configure cooldown durations, Dark/Light mode, and the time for a single daily local notification reminding the user to check their meal recommendation."`
     - Line 22 (R4): `"The app must be built with Flutter (Android target), using Riverpod (flutter_riverpod, riverpod_annotation) for state management, and GoRouter for navigation. The UI must strictly follow Material Design 3 (Material You / Dynamic Colors) and be fully localized for Arabic (RTL)."`
     - Lines 27-36 (Acceptance Criteria):
       - `flutter build apk` completes successfully without errors.
       - `flutter analyze` returns zero issues.
       - Drift database generates successfully (`dart run build_runner build`).
       - Cooldown Algorithm unit test passes (verifying recently cooked meals and repeating proteins are filtered out).
       - App launches in RTL layout by default.
       - Adding a new meal correctly updates Riverpod state and reflects immediately on the UI.

2. **Current Project State**:
   - Flutter SDK: `Flutter 3.44.0` on channel stable, `Dart 3.12.0` (verified via `flutter --version`).
   - Root Directory: `E:\Mohamed\Personal_Project\daily-meal\daily_meal`.
   - Existing codebase contains stock Flutter counter template in `lib/main.dart` and `test/widget_test.dart`.
   - `pubspec.yaml` currently includes only base Flutter SDK dependencies, `cupertino_icons: ^1.0.8`, and `flutter_lints: ^6.0.0`.

3. **Required Packages for Implementation**:
   - Database: `drift`, `drift_flutter` (or `sqlite3_flutter_libs`, `path_provider`, `path`), `drift_dev`, `build_runner`.
   - State Management: `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`.
   - Routing: `go_router`.
   - Notifications: `flutter_local_notifications`.
   - Localization: `flutter_localizations` (from Flutter SDK), `intl`.
   - UI/Picker: `image_picker` (optional photo attachment).

---

## 2. Logic Chain

1. **Step 1: Schema Derivation (R1)**
   - *Observation*: Line 13 of `ORIGINAL_REQUEST.md` dictates meals have: `name`, `optional photo path`, `protein type`, `carbs type`, `category`, `prep time`, and boolean tags (`Friday special`, `budget friendly`, `favorite`).
   - *Inference*: The `Meals` table in Drift requires specific column types: `IntColumn id` (autoIncrement), `TextColumn name` (non-null), `TextColumn photoPath` (nullable), `TextColumn proteinType` (non-null), `TextColumn carbsType` (non-null), `TextColumn category` (non-null), `IntColumn prepTime` (non-null, minutes), `BoolColumn isFridaySpecial` (default false), `BoolColumn isBudgetFriendly` (default false), `BoolColumn isFavorite` (default false).
   - *History tracking*: `meal_history` table requires `mealId` (nullable foreign key with `SetNull` so deleting a meal preserves history), `mealName` snapshot, `proteinType` snapshot, `carbsType` snapshot, `cookedAt` (DateTime), and `entryType` ('cooked' vs 'leftover').
   - *Settings store*: `app_settings` requires a single-row configuration table containing `cooldownDays` (default 14), `themeMode` (default 'system'), `notificationEnabled` (default true), `notificationHour` (default 11), `notificationMinute` (default 0), `preventRepeatProtein` (default true), `preventRepeatCarbs` (default true).

2. **Step 2: Algorithm & Presentation Mechanics (R2)**
   - *Observation*: Line 16 requires filtering out meals cooked within 14 days and preventing back-to-back protein/carbs repeating, presenting a 3-card stack, roulette wheel, and quick actions ("cooked today", "leftover").
   - *Inference*: The candidate selection pipeline must strictly evaluate `cooked_at >= now() - cooldown_duration`. To prevent back-to-back repeating, the engine queries the most recent cooking log and eliminates meals matching its protein and carbs.
   - *Fallback Design*: In real-world usage or small vaults (e.g., fewer than 3 meals, or all meals on cooldown), a naive filter returns 0 meals, breaking the 3-card stack. A 5-stage graceful degradation fallback was designed: (A) relax carbs repetition, (B) relax protein repetition, (C) reduce cooldown window (7d -> 3d -> 1d), (D) sort by oldest cooked date, (E) display an empty state CTA when vault has 0 meals.

3. **Step 3: History, Settings & Notifications (R3)**
   - *Observation*: Line 19 specifies chronological past meals log, cooldown configuration, Dark/Light mode, and single daily local notification.
   - *Inference*: History entries must support grouping by relative date ("اليوم", "أمس", "هذا الأسبوع", "أقدم") and provide an undo/delete mechanism. Settings must provide interactive controls (M3 Slider for cooldown, SegmentedButton for theme, Material TimePicker for notification). The notification service must use `flutter_local_notifications` with `zonedSchedule` matching `DateTimeComponents.time`.

4. **Step 4: Architecture & Localization (R4)**
   - *Observation*: Line 22 specifies Riverpod, GoRouter, Material Design 3, and Arabic RTL by default.
   - *Inference*: A Feature-First architecture (`features/home`, `features/vault`, `features/history`, `features/settings`) ensures clean separation of concerns. `MaterialApp.router` must configure `locale: Locale('ar')`, `supportedLocales: [Locale('ar')]`, and `localizationsDelegates` with `GlobalMaterialLocalizations.delegates`. GoRouter manages bottom navigation with `StatefulShellRoute.indexedStack`.

---

## 3. Caveats

1. **No External Backend**: App is 100% offline-first. No cloud syncing or external authentication is required.
2. **Preset Starter Meals**: While not explicitly demanded in `ORIGINAL_REQUEST.md`, an empty vault on initial install produces an empty recommendation stack. Preloading 12-16 classic Egyptian dishes on first database initialization solves this edge case gracefully and ensures out-of-the-box delight.
3. **Android 13+ Notification Permissions**: Requires requesting `POST_NOTIFICATIONS` runtime permission. If the user denies permission, the app must gracefully remain functional without crashing.

---

## 4. Conclusion

The specification mining phase is complete. All functional requirements (R1-R4), non-functional requirements (Material Design 3, Arabic RTL, offline persistence, compilation, zero lint warnings), 29 granular features, 20 boundary/edge cases, exact Drift SQLite data contracts, and the complete Cooldown Algorithm mathematical pipeline have been fully probed, modeled, and recorded in:
`E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_spec_miner_survey_1\spec_report.md`.

The implementation tracks (Track A: Testing & Track B: Implementation) have an unambiguous, comprehensive blueprint to follow.

---

## 5. Verification Method

1. **Inspect Specification Artifacts**:
   - `spec_report.md`: Review the 29 features table, 20 edge cases table, Drift table definitions, and Cooldown Algorithm fallback cascade.
   - `BRIEFING.md` & `progress.md`: Confirm state tracking and task completion.
2. **Validate Requirements Coverage**:
   - Cross-check `spec_report.md` against `ORIGINAL_REQUEST.md` line by line to verify 100% requirement alignment.
3. **Downstream Test Verification Commands**:
   - `dart run build_runner build --delete-conflicting-outputs`
   - `flutter analyze`
   - `flutter test`
   - `flutter build apk`
