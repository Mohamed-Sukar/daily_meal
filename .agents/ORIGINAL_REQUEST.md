# Original User Request

## 2026-09-06T20:57:09Z

Build the MVP of "أكلة النهاردة", an Offline-First Flutter (Android) app that recommends daily meals from a local database using a cooldown algorithm.

Working directory: E:\Mohamed\Personal_Project\daily-meal\daily_meal
Integrity mode: development

## Requirements

### R1. Meal Vault (Local Database)
Implement local storage using Drift (SQLite). Users must be able to add, edit, delete, and view meals. A meal has properties: name, optional photo path, protein type, carbs type, category, prep time, and boolean tags (Friday special, budget friendly, favorite). Include a `meal_history` table to track when meals were cooked, and an `app_settings` table.

### R2. Recommendation Engine & Home Screen
Implement the core UI and logic. The Home screen should display a 3-card stack of meal recommendations. The recommendations must be powered by a Cooldown Algorithm that filters out meals cooked recently (e.g., within 14 days) and prevents back-to-back repeating of protein/carbs. Include a "Spin the Wheel" roulette feature for random selection, and quick actions to mark a meal as "cooked today" or "leftover".

### R3. History, Settings & Notifications
Implement a History screen displaying a chronological log of past meals. Implement a Settings screen to configure cooldown durations, Dark/Light mode, and the time for a single daily local notification reminding the user to check their meal recommendation.

### R4. Technical Architecture & UI
The app must be built with Flutter (Android target), using Riverpod (`flutter_riverpod`, `riverpod_annotation`) for state management, and GoRouter for navigation. The UI must strictly follow Material Design 3 (Material You / Dynamic Colors) and be fully localized for Arabic (RTL).

## Acceptance Criteria

### Compilation & Quality
- [ ] `flutter build apk` completes successfully without errors.
- [ ] `flutter analyze` returns zero issues.

### Core Logic Verification
- [ ] Drift database generates successfully (`dart run build_runner build`).
- [ ] The Cooldown Algorithm unit test passes (verifying that recently cooked meals and repeating proteins are successfully filtered out).

### UI/UX
- [ ] The app launches in an RTL layout by default.
- [ ] Adding a new meal correctly updates the Riverpod state and reflects immediately on the UI.
