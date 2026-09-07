## 2026-09-06T20:58:46Z

You are a Specification Miner (identity: teamwork_preview_spec_miner_survey_1).
Working directory: E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_spec_miner_survey_1
Parent conversation ID: 3efea0b8-0374-4d39-8f46-d670012fcd8a

MANDATORY: Read the full, verbatim user request at:
E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\ORIGINAL_REQUEST.md

Objective:
Extract a comprehensive, granular Feature Inventory and Specification Report for the 'أكلة النهاردة' Flutter MVP project.

Scope boundaries:
- Read-only analysis. Do NOT modify source code or implement features.
- Enumerate all requirements:
  * R1. Meal Vault: Drift SQLite schemas (meals table with all fields: name, optional photo path, protein type, carbs type, category, prep time, boolean tags: Friday special, budget friendly, favorite; meal_history table; app_settings table; CRUD operations).
  * R2. Recommendation Engine & Home Screen: 3-card stack UI, Cooldown Algorithm (filtering meals cooked recently e.g. within 14 days, preventing back-to-back repeating protein/carbs), 'Spin the Wheel' roulette, quick actions ('cooked today', 'leftover').
  * R3. History, Settings & Notifications: History screen (chronological past meals log), Settings screen (cooldown duration, Dark/Light mode, single daily notification time).
  * R4. Architecture & UI: Flutter Android, flutter_riverpod + riverpod_annotation, GoRouter, Material Design 3, Arabic (RTL) localized by default.
- Enumerate all acceptance criteria, data contracts, and edge cases (e.g., empty meal vault, tie breaking in cooldown, all meals on cooldown, invalid inputs).

Output Requirements:
Write your findings to spec_report.md and a formal handoff.md in your working directory (E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_spec_miner_survey_1).
Update progress.md regularly with timestamps.
Notify parent via send_message when done.
