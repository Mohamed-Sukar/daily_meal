# Handoff Report: Architecture & Test Strategy for 'أكلة النهاردة'

**Agent:** `teamwork_preview_explorer_survey_2` (Architecture & Test Planner)  
**Parent Conversation ID:** `3efea0b8-0374-4d39-8f46-d670012fcd8a`  
**Handoff Type:** Hard (Task Complete)  
**Target Milestone:** Phase 0: Survey & Specification Mining -> Architecture Blueprint

---

## 1. Observation

1. **Original User Request (`.agents/ORIGINAL_REQUEST.md`)**:
   - Lines 12-13: "R1. Meal Vault (Local Database): Implement local storage using Drift (SQLite)... properties: name, optional photo path, protein type, carbs type, category, prep time, and boolean tags (Friday special, budget friendly, favorite). Include a `meal_history` table to track when meals were cooked, and an `app_settings` table."
   - Lines 15-16: "R2. Recommendation Engine & Home Screen: ... recommendations must be powered by a Cooldown Algorithm that filters out meals cooked recently (e.g., within 14 days) and prevents back-to-back repeating of protein/carbs. Include a 'Spin the Wheel' roulette feature... and quick actions to mark a meal as 'cooked today' or 'leftover'."
   - Lines 18-19: "R3. History, Settings & Notifications: ... History screen displaying a chronological log of past meals. ... Settings screen to configure cooldown durations, Dark/Light mode, and the time for a single daily local notification..."
   - Lines 21-22: "R4. Technical Architecture & UI: ... Flutter (Android target), using Riverpod (`flutter_riverpod`, `riverpod_annotation`) for state management, and GoRouter for navigation. The UI must strictly follow Material Design 3 (Material You / Dynamic Colors) and be fully localized for Arabic (RTL)."
   - Lines 27-36: "Acceptance Criteria: `flutter build apk` completes successfully... `flutter analyze` returns zero issues... Drift database generates successfully (`dart run build_runner build`)... Cooldown Algorithm unit test passes... app launches in an RTL layout by default... adding a new meal correctly updates Riverpod state and reflects immediately on the UI."

2. **Codebase Status (`pubspec.yaml` & Android Config)**:
   - `pubspec.yaml` contains minimal skeleton: `sdk: ^3.12.0`, `cupertino_icons: ^1.0.8`, `flutter_lints: ^6.0.0`.
   - Tool `flutter --version` returned Flutter 3.44.0, channel stable, Dart 3.12.0.
   - `android/app/build.gradle.kts` uses Android Gradle Plugin with Kotlin JVM 17 and Java 17 compatibility. Namespace: `com.dailymeal.daily_meal`.

3. **Orchestrator Plan (`.agents/teamwork_preview_orchestrator_1/plan.md`)**:
   - Dual-track structure: Track A (E2E Testing Track) and Track B (Implementation Track: Milestones M1-M4), followed by Milestone 5 (E2E Integration & Verification).

---

## 2. Logic Chain

1. **From Observation 1 (R1 & Acceptance Criteria) to Drift SQLite Architecture**:
   - Because the app is offline-first with relational queries between meals, history logs, and singleton settings, Drift SQLite provides compile-time query verification and native reactive streams (`watchAllMeals`, `watchHistory`).
   - Foreign key cascading is mandatory so that deleting a meal cleanly removes associated history entries without orphan records (`onDelete: KeyAction.cascade`).
   - Pre-seeding 20 authentic Egyptian meals during `onCreate` ensures the app is immediately testable and useful on first launch without requiring initial manual data entry.

2. **From Observation 1 (R2 & Acceptance Criteria) to Cooldown & Recommendation Algorithm**:
   - The user explicitly mandates filtering meals cooked within 14 days and preventing back-to-back repetition of protein/carbs.
   - However, in small vaults or long cooldown periods, strict filtering can result in an empty candidate set (< 3 meals).
   - Therefore, a deterministic 5-level progressive relaxation cascade is designed (Level 0: Strict -> Level 1: Relax Carbs -> Level 2: Halve Cooldown -> Level 3: Relax Protein & Min Cooldown -> Level 4: Emergency Same-Day Exclusion -> Level 5: Minimal Inventory Handling).
   - Inter-card diversity ensures that even within the top 3 cards, protein types do not duplicate.

3. **From Observation 1 (R4 & Acceptance Criteria) to Riverpod State Architecture**:
   - Riverpod's `AsyncNotifier` combined with Drift's `Stream` queries guarantees that whenever a mutation occurs (e.g., `addMeal` or `logCookedMeal`), the dependent `TodayRecommendationsNotifier` automatically invalidates and recomputes in the same frame.
   - This directly satisfies the acceptance criterion: "Adding a new meal correctly updates the Riverpod state and reflects immediately on the UI."

4. **From Observation 1 (R4 & Acceptance Criteria) to GoRouter & Arabic RTL**:
   - `StatefulShellRoute.indexedStack` maintains tab scroll state across Home, Meal Vault, History, and Settings.
   - Enforcing `locale: Locale('ar')` with `Directionality(textDirection: TextDirection.rtl)` and Material 3 components ensures correct alignment, right-to-left tab ordering (Home on rightmost), and auto-mirrored navigation arrows.

5. **From Acceptance Criteria to Tier 1-4 Test Strategy**:
   - Tier 1: Headless pure Dart tests verify the mathematical cooldown formulas, boundary dates, and progressive relaxation.
   - Tier 2: Widget tests verify RTL directionality and immediate Riverpod reactivity.
   - Tier 3: In-memory Drift SQLite integration tests verify DAOs and cascade deletes.
   - Tier 4: E2E user flows verify the full journey from meal suggestion to cooking, cooldown, and history timeline logging.

---

## 3. Caveats

1. **Android Notification Permissions on Android 13+ (API 33+)**:
   - While `flutter_local_notifications` handles daily reminders, `POST_NOTIFICATIONS` runtime permission must be requested on Android 13+. If declined by the user, the app must gracefully function offline without crashing.
2. **Local Image Storage**:
   - Meal photos use local file paths (`photo_path`). If users select custom photos, files should be stored in the app's document directory via `path_provider` so they persist across reboots. Default seed meals can use asset placeholders or category icons.
3. **No Code Modification Executed**:
   - Per read-only survey instructions, no source files in `lib/` or `test/` were altered. Implementation track agents (M1 to M4) and Test Track agents will implement the specified blueprints.

---

## 4. Conclusion

A comprehensive, production-grade architectural specification and test plan for "أكلة النهاردة" has been authored and saved to `architecture_report.md`. It provides unambiguous data schemas, DAO signatures, the exact mathematical cooldown and fallback engine, Riverpod reactive provider dependencies, GoRouter RTL navigation, and an executable 4-tier test plan satisfying 100% of the project acceptance criteria.

---

## 5. Verification Method

To independently verify the architectural design:
1. **Inspect Architectural Specification**:
   - Read `E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_survey_2\architecture_report.md`.
2. **Verify Acceptance Criteria Alignment**:
   - Cross-reference sections 2 (Drift), 3 (Cooldown Engine), 4 (Riverpod), 5 (GoRouter & RTL), and 6 (Testing Tiers) against `E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md`.
3. **Downstream Execution Verification**:
   - Milestone 1-4 implementers will execute:
     - `dart run build_runner build --delete-conflicting-outputs`
     - `flutter test` (Tier 1 unit tests & Tier 2 widget tests)
     - `flutter analyze`
     - `flutter build apk --debug`
