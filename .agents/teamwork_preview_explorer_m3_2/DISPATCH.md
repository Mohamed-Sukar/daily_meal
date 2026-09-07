## 2026-09-07T00:17:56Z

You are the Explorer for Milestone 3: Presentation Layer & Riverpod State (identity: teamwork_preview_explorer_m3_2).
Working directory: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m3_2
Parent conversation ID: 3efea0b8-0374-4d39-8f46-d670012fcd8a

MANDATORY: Read the full, verbatim user request at:
E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\PROJECT.md
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\test\widget\rtl_layout_test.dart
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\test\e2e\full_flow_test.dart

Objective:
Design the GoRouter configuration, Navigation Bar, Home Screen 3-card stack, Quick Actions, and Spin the Wheel roulette:
1. `app_router.dart`:
   - GoRouter setup with `StatefulShellRoute.indexedStack`.
   - 4 tabs: Home (`/`), Vault (`/vault`), History (`/history`), Settings (`/settings`).
   - ScaffoldWithNavBar widget with Material 3 NavigationBar, Arabic RTL labels (الرئيسية, خزانة الأكلات, السجل, الإعدادات) and icons.
2. Home Screen (`home_screen.dart`):
   - Header with Arabic greeting and "Spin the Wheel" action button.
   - 3-Card Stack display (`meal_card.dart`): Card 1 (primary), Card 2 (secondary), Card 3 (tertiary).
   - Card content: Name, prep time, protein & carbs tags, category, photo/placeholder, Friday/Budget/Favorite badges.
   - Quick action buttons (`quick_actions.dart`): "طبخت دي النهاردة" and "بواقي أكل".
   - Status/relaxation banner when fallback cascade is active.
3. Spin the Wheel Roulette (`spin_wheel_dialog.dart`):
   - Interactive dialog / modal bottom sheet with animated roulette selecting randomly among eligible meals.
4. Specify widget tree structure, animations, and Riverpod consumer integration.
Write your UI & navigation blueprint to `m3_home_nav_plan.md` and `handoff.md` in your working directory, and notify parent via send_message.
