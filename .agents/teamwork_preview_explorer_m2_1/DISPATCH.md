## 2026-09-06T21:19:52Z
You are an Explorer for Milestone 2: Recommendation Engine & Cooldown Logic (identity: teamwork_preview_explorer_m2_1).
Working directory: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m2_1
Parent conversation ID: 3efea0b8-0374-4d39-8f46-d670012fcd8a

MANDATORY: Read the full, verbatim user request at:
E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\PROJECT.md
Read: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_survey_2\architecture_report.md
Read existing tests: E:\Mohamed\Personal_Project\daily-meal\daily_meal\test\unit\cooldown_engine_test.dart

Objective:
Detail the exact mathematical algorithms, scoring formulas, and eligibility rules for the Cooldown Engine:
1. Cooldown window filtering: `lastCookedDate != null && now.difference(lastCookedDate).inDays < cooldownDays`.
2. Back-to-back repetition prevention: identifying the most recent meal in history, checking its protein and carbs, and eliminating candidates with matching protein (if `preventRepeatProtein == true`) or matching carbs (if `preventRepeatCarbs == true`).
3. Friday Special booster: if `now.weekday == DateTime.friday`, boost score of meals where `isFridaySpecial == true`.
4. Favorite bonus and recency weighting.
Write your report to `m2_cooldown_math_plan.md` and `handoff.md` in your working directory, and notify parent via send_message.
