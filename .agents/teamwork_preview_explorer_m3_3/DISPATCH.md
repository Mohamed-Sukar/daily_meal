## 2026-09-07T00:17:56Z
You are the Explorer for Milestone 3: Presentation Layer & Riverpod State (identity: teamwork_preview_explorer_m3_3).
Working directory: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m3_3
Parent conversation ID: 3efea0b8-0374-4d39-8f46-d670012fcd8a

MANDATORY: Read the full, verbatim user request at:
E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\PROJECT.md
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\lib\core\database\tables\meals_table.dart
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\test\widget\riverpod_reactivity_test.dart
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\test\e2e\full_flow_test.dart

Objective:
Design the Meal Vault UI, Search & Filters, Add/Edit Meal Form, and Deletion flow:
1. Meal Vault Screen (`meal_vault_screen.dart`):
   - Search field for filtering meals by name.
   - Filter chips for Protein (لحوم, دواجن, أسماك, نباتي, بيض/جبن, أخرى), Carbs (أرز, مكرونة, عيش, بطاطس, بدون), and Tags (جمعة, اقتصادي, مفضل).
   - Meal list/cards showing image thumbnail, prep time, tags, favorite toggle button, edit button, delete button.
   - Empty state with clear call-to-action button.
   - FloatingActionButton: "إضافة أكلة".
2. Add / Edit Meal Modal (`add_edit_meal_dialog.dart`):
   - Form fields: Name (text input, required), Category dropdown (طبيخ ومسبك, نواشف, صواني, مشويات, بحريات, شعبي ومحاشي, أخرى), Protein type dropdown, Carbs type dropdown, Prep time (minutes input), Photo path (optional), Checkboxes for Friday Special, Budget Friendly, Favorite.
   - Form validation: Arabic error messages.
   - Save handler: dispatches to Riverpod provider, triggers database insert/update, closes dialog, verifies immediate UI update.
3. Meal Deletion flow:
   - Confirmation dialog explaining that cooked history will be preserved (`KeyAction.setNull`).
4. Specify widget tree structure, form keys, and Riverpod consumer integration.
Write your Vault UI blueprint to `m3_vault_plan.md` and `handoff.md` in your working directory, and notify parent via send_message.
