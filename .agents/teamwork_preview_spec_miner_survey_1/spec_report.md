# Specification Report & Feature Inventory: أكلة النهاردة (Daily Meal) Flutter MVP

**Document Version:** 1.0.0  
**Author:** teamwork_preview_spec_miner_survey_1 (Specification Miner)  
**Date:** 2026-09-06  
**Status:** Approved Specification  
**Authority Source:** `ORIGINAL_REQUEST.md` (2026-09-06T20:57:09Z)  
**Target Environment:** Flutter 3.44.0 / Dart 3.12.0 (Android Target, Material Design 3, Arabic RTL)

---

## 1. Executive Summary & Specification Scope

"أكلة النهاردة" (Daily Meal) is an Offline-First Flutter application targeting Android that addresses the domestic daily dilemma ("هنطبخ إيه النهاردة؟" / "What should we cook today?") by recommending meals from a local database using an intelligent Cooldown Algorithm.

The application operates completely offline without requiring internet access or third-party cloud authentication. It maintains a user-curated repository of recipes and meals ("خزينة الوجبات" / Meal Vault), tracks cooking history, applies intelligent cooldown rules (preventing meal repetition within a configurable period, default 14 days, and preventing consecutive back-to-back repetitions of protein and carbohydrates), offers an interactive "Spin the Wheel" roulette for indecisive moments, logs domestic cooking history, and provides configurable settings with scheduled daily notifications.

### Core Pillars
1. **R1: Meal Vault (خزينة الوجبات)** — Offline local SQLite storage powered by Drift, with full CRUD for meals, a history table (`meal_history`), an app configuration table (`app_settings`), and starter preset meals.
2. **R2: Recommendation Engine & Home Screen (محرك الاقتراحات والشاشة الرئيسية)** — 3-card stack presentation, Cooldown Algorithm (time-window recency filter, back-to-back protein/carbs repeat prevention, Friday special prioritization, multi-stage fallback cascade), Spin the Wheel roulette, and quick actions ("طبختها النهاردة" / "أكل بايت").
3. **R3: History, Settings & Notifications (السجل، الإعدادات، والتنبيهات)** — Chronological cooking log, user-configurable cooldown duration (1..60 days), Dark/Light theme toggle, and scheduled daily local notifications reminding users to check recommendations.
4. **R4: Technical Architecture & UI (المعمارية وواجهة المستخدم)** — Material Design 3 (Material You / dynamic color schemes), `flutter_riverpod` + `riverpod_annotation`, `go_router`, and default Arabic RTL localization.

---

## 2. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | R1: Meal Vault | Meal Entity Schema | Drift table definition with `id`, `name`, `photoPath`, `proteinType`, `carbsType`, `category`, `prepTime`, `isFridaySpecial`, `isBudgetFriendly`, `isFavorite`, `createdAt`, `updatedAt`. | Meal entity attributes | Generated Drift Data Class (`Meal`) and Companion (`MealsCompanion`) | SQLite constraint exception on missing non-null fields | ORIGINAL_REQUEST.md §R1 |
| 2 | R1: Meal Vault | Add New Meal | Insert a new custom recipe into the local database with form validation and reactive UI update. | Form data: name, protein, carbs, category, prep time, boolean tags, optional image | Generated meal ID, persisted SQLite row, updated Riverpod state | Form validator flags empty name, non-positive prep time | ORIGINAL_REQUEST.md §R1, §Acceptance Criteria |
| 3 | R1: Meal Vault | Edit Existing Meal | Update any field of an existing meal in the vault while keeping historical logs intact. | Meal ID + modified field values | Updated SQLite row, refreshed Riverpod stream | RecordNotFound exception if ID does not exist | ORIGINAL_REQUEST.md §R1 |
| 4 | R1: Meal Vault | Delete Meal | Remove a meal from the vault with safe foreign key handling (`SetNull` in history). | Meal ID | Deleted SQLite row, removed from active UI lists | Safely nullifies `meal_id` in history without data loss | ORIGINAL_REQUEST.md §R1 |
| 5 | R1: Meal Vault | View / Browse Meals | Filterable and searchable catalog of all saved meals with search bar, category chips, and tag filters. | Search query, category filter, tag filters | Reactive stream of meal items (`Stream<List<Meal>>`) | Returns empty state UI widget if no records match | ORIGINAL_REQUEST.md §R1 |
| 6 | R1: Meal Vault | Preload Egyptian Seed Meals | Populate database on initial launch with classic Egyptian domestic recipes so app is never empty on first run. | None (triggers automatically if vault is empty on first boot) | 12-16 seeded Egyptian dishes across categories | Idempotent; skips if meals table already contains records | Architectural Requirement for R1 / Edge Cases |
| 7 | R1: Meal Vault | Meal History Schema | Drift table tracking cooking logs: `id`, `mealId`, `mealName`, `cookedAt`, `entryType`, `proteinType`, `carbsType`, `notes`. | Meal ID, timestamp, entryType ('cooked' / 'leftover') | Persisted row in `meal_history` table | Preserves meal snapshots even if original meal is deleted | ORIGINAL_REQUEST.md §R1 |
| 8 | R1: Meal Vault | App Settings Schema | Drift table storing configuration: `id`, `cooldownDays`, `themeMode`, `notificationEnabled`, `notificationHour`, `notificationMinute`, `preventRepeatProtein`, `preventRepeatCarbs`. | Settings update object | Persisted settings entity | Defaults automatically to (14 days, system theme, 11:00 AM) | ORIGINAL_REQUEST.md §R1, §R3 |
| 9 | R2: Recommendation | Cooldown Recency Filter | Exclude meals cooked within the configured cooldown window (`cookedAt >= now - cooldownDuration`). | Cooldown days (default 14), meal history entries | Filtered candidate pool of non-cooldown meals | If all meals are excluded, triggers graceful relaxation fallback | ORIGINAL_REQUEST.md §R2 |
| 10 | R2: Recommendation | Protein Repeat Prevention | Exclude meals sharing the same protein type as the most recently cooked meal. | Last logged meal's protein type | Filtered candidate pool | If pool becomes empty, relaxes protein constraint | ORIGINAL_REQUEST.md §R2 |
| 11 | R2: Recommendation | Carbs Repeat Prevention | Exclude meals sharing the same carbs type as the most recently cooked meal. | Last logged meal's carbs type | Filtered candidate pool | If pool becomes empty, relaxes carbs constraint | ORIGINAL_REQUEST.md §R2 |
| 12 | R2: Recommendation | Friday Special Prioritization | Boost meals marked `isFridaySpecial = true` to the top of the stack when current day is Friday. | Current DateTime (`weekday == DateTime.friday`) | Re-ranked recommendation stack | If no Friday specials exist, falls back smoothly to regular pool | ORIGINAL_REQUEST.md §R1, §R2 |
| 13 | R2: Recommendation | 3-Card Stack UI | Interactive stacked card presentation displaying top 3 recommendations with swipeable/inspectable cards. | Top 3 recommended meal objects | Visual 3-card stack with badges, prep time, photos | Dynamically scales to 1 or 2 cards if fewer exist; empty state if 0 | ORIGINAL_REQUEST.md §R2 |
| 14 | R2: Recommendation | Quick Action: Cooked Today | One-tap button marking a card's meal as cooked today, recording to history and advancing recommendation. | Meal ID, current timestamp, entryType='cooked' | New history entry, card dismissed, cooldown applied | Snackbar with undo action if tapped accidentally | ORIGINAL_REQUEST.md §R2 |
| 15 | R2: Recommendation | Quick Action: Leftover | Mark current meal or day as leftover consumption ("بواقي أكل") without triggering a new cooking cooldown. | Meal ID (optional), current timestamp, entryType='leftover' | New history entry with leftover badge | Retains cooking cooldown for other meals, updates last eaten protein | ORIGINAL_REQUEST.md §R2 |
| 16 | R2: Recommendation | Spin the Wheel Roulette | Interactive gamified fortune wheel populated with eligible candidates for randomized meal selection. | List of eligible candidate meals (min 2) | Winning meal dialog with direct "Cooked Today" action | Disabled or guidance sheet if fewer than 2 eligible meals | ORIGINAL_REQUEST.md §R2 |
| 17 | R2: Recommendation | Recommendation Shuffle / Reroll | Button allowing user to reshuffle candidates or view alternate suggestions. | User tap | Re-ordered / next candidate card in stack | Visual indication when candidate pool is exhausted | ORIGINAL_REQUEST.md §R2 |
| 18 | R3: History | Chronological Past Meals Log | Scrollable timeline of past meals grouped by date (Today, Yesterday, Last 7 Days, Older). | Stream of `meal_history` records | Grouped list items with date, meal name, type badge | Empty state illustration if history is empty | ORIGINAL_REQUEST.md §R3 |
| 19 | R3: History | Delete History Entry | Capability to remove an erroneously logged meal entry from history. | History entry ID | Entry deleted, cooldown recalculated immediately | Confirmation dialog before deletion | Standard UX Requirement for R3 |
| 20 | R3: Settings | Cooldown Duration Setting | Slider or number stepper to adjust cooldown window from 1 to 60 days (default: 14). | Integer days (1..60) | Persisted setting, triggers immediate engine recalculation | Clamped between min (1) and max (60) | ORIGINAL_REQUEST.md §R3 |
| 21 | R3: Settings | Theme Mode Selector | Switch between System Default, Light Mode, and Dark Mode using Material 3 color schemes. | ThemeMode enum: system, light, dark | Immediate app theme transition | Persisted in SQLite settings table | ORIGINAL_REQUEST.md §R3, §R4 |
| 22 | R3: Settings | Daily Notification Time Picker | Material time picker allowing user to set hour and minute for the daily lunch reminder. | TimeOfDay (hour, minute) | Persisted setting, notification rescheduled | Validated against 24h clock | ORIGINAL_REQUEST.md §R3 |
| 23 | R3: Settings | Notification Master Toggle | Switch to enable or disable daily push reminders. | Boolean flag | Enables or cancels scheduled notifications in Android system | Persisted in SQLite settings | ORIGINAL_REQUEST.md §R3 |
| 24 | R3: Notifications | Scheduled Local Daily Notification | Native Android scheduled notification triggering at configured time using `flutter_local_notifications`. | Scheduled TimeOfDay, notification payload | System tray notification with custom Arabic title & body | Handles Android 13+ runtime permission denial gracefully | ORIGINAL_REQUEST.md §R3 |
| 25 | R3: Notifications | Notification Tap Deep Link | Tapping the notification launches the app directly into the Home recommendations view. | Notification response payload | GoRouter navigates to `/` (Home) | Fallback to home screen if route invalid | Standard Mobile UX for R3/R4 |
| 26 | R4: Architecture | Riverpod State Management | Reactive, declarative state using `@riverpod` code generation for database, engine, and settings. | State providers and notifiers | Auto-disposing, testable UI state streams | Error and loading states handled via `AsyncValue` | ORIGINAL_REQUEST.md §R4 |
| 27 | R4: Architecture | GoRouter Navigation | Declarative routing supporting bottom navigation bar with persistent tab states and deep linking. | Route locations (`/`, `/vault`, `/history`, `/settings`) | Animated screen transitions | 404 / Error screen on unknown path | ORIGINAL_REQUEST.md §R4 |
| 28 | R4: UI/UX | Material Design 3 Theming | Full Material You specification with dynamic colors, tonal elevation, M3 Card, M3 NavigationBar. | ColorScheme seed (warm culinary terracotta/orange palette) | M3 styled widgets across light and dark themes | Graceful fallback if dynamic color unavailable | ORIGINAL_REQUEST.md §R4 |
| 29 | R4: UI/UX | Default Arabic RTL Localization | App-wide Right-to-Left layout direction with authentic Egyptian Arabic terminology. | `Locale('ar')`, `TextDirection.rtl` | Flipped UI layouts, Arabic typography, localized dates | Uses `GlobalMaterialLocalizations` | ORIGINAL_REQUEST.md §R4, §Acceptance Criteria |

---

## 3. Edge Cases & Boundary Conditions

| # | Feature | Input / Condition | Observed / Required Behavior |
|---|---------|-------------------|------------------------------|
| 1 | Cooldown Engine | Meal Vault is completely empty (0 meals saved) | Engine yields empty candidate list. Home screen displays an inviting empty state card with CTA button: "أضف أكلتك الأولى" (Add your first meal) or "تحميل أكلات مقترحة" (Load starter Egyptian meals). No crash, no null pointer exception. |
| 2 | Cooldown Engine | All saved meals are currently on cooldown (e.g., 5 meals in vault, all cooked within the last 14 days) | Engine enters Stage 4 Fallback: progressively relaxes cooldown window (14d -> 7d -> 3d -> 1d) or returns meals ordered by least recently cooked (`cooked_at ASC`). UI displays an informational badge: "تم استرخاء فترة الاستبعاد لعدم توفر وجبات كافية". |
| 3 | Cooldown Engine | Meal Vault contains fewer than 3 meals (e.g., exactly 1 or 2 meals) | 3-card stack gracefully scales down: displays 1 card or 2 cards. Stack widget handles list length dynamically (`math.min(3, candidates.length)`) without index out-of-bounds errors. |
| 4 | Cooldown Engine | All eligible non-cooldown meals share yesterday's protein (e.g., yesterday was chicken, all 4 non-cooldown meals are chicken) | Engine enters Stage 2 Fallback: relaxes protein repeat prevention constraint rather than returning an empty list, allowing chicken with an explanatory subtitle. |
| 5 | Cooldown Engine | All eligible non-cooldown meals share yesterday's carbs (e.g., yesterday was rice, all remaining meals use rice) | Engine enters Stage 1 Fallback: relaxes carbs repeat prevention constraint while strictly preserving protein and cooldown rules. |
| 6 | Cooldown Engine | Friday Special behavior on regular weekdays (Saturday to Thursday) | Friday special meals are not given artificial priority; they participate normally in the candidate pool unless user filters them, but are not elevated above standard meals. |
| 7 | Cooldown Engine | Friday Special behavior on Friday with 0 Friday specials in vault | Engine detects lack of Friday special meals and smoothly falls back to standard cooldown recommendations without error or empty screen. |
| 8 | Spin the Wheel | User opens roulette when vault has 0 or 1 meal | Roulette wheel requires at least 2 candidates to spin. If fewer than 2 exist, button is disabled or tapping opens a dialog: "تحتاج إلى وجبتين على الأقل لتشغيل عجلة الحظ". |
| 9 | Meal Vault CRUD | User deletes a meal that has past records in `meal_history` | Foreign key constraint on `meal_history.meal_id` is configured with `onDelete: SetNull`. `meal_history` table stores snapshot columns (`meal_name`, `protein_type`, `carbs_type`), preserving historical reporting integrity even if the source meal is deleted. |
| 10 | Meal Vault CRUD | User enters empty string or whitespace for meal name | Form validator rejects input with Arabic error message: "يرجى كتابة اسم الوجبة". Save button is disabled or triggers form validation error. |
| 11 | Meal Vault CRUD | User enters 0 or negative prep time | Form validator clamps or rejects input: prep time must be a positive integer between 5 and 360 minutes. |
| 12 | Meal Vault CRUD | User provides non-existent local file path for photo (or deletes image from gallery) | Image renderer catches image load exception and displays the default fallback vector icon/illustration corresponding to the meal's category/protein. |
| 13 | History & Quick Actions | User marks "Cooked Today" twice on the same day | Second entry is logged with its timestamp. The cooldown engine uses the latest `cooked_at` timestamp. History screen shows both entries grouped under "اليوم". |
| 14 | History & Quick Actions | User marks "Leftover" ("أكل بايت") for today's meal | `meal_history` logs record with `entry_type = 'leftover'`. The cooldown algorithm ignores leftover entries when computing cooking cooldown for other meals, but updates the "last eaten" protein/carbs record to prevent meal fatigue. |
| 15 | History Screen | User accidentally taps "Cooked Today" and wants to undo | History screen provides a delete action for each history entry. Deleting the most recent entry immediately triggers a Riverpod state update and recalculates the recommendation stack. |
| 16 | Settings & Cooldown | User sets cooldown duration to 0 or 1 day | Settings UI clamps minimum value to 1 day. A 1-day cooldown means meals cooked yesterday cannot be recommended today, but meals cooked 2 days ago are immediately eligible. |
| 17 | Notifications | Device is rebooted or turned off at notification time | Notifications are scheduled via Android AlarmManager / WorkManager with reboot receiver (`RECEIVE_BOOT_COMPLETED`) so alarms are restored upon device boot. |
| 18 | Notifications | Android 13+ (API 33) notification permission denied | App gracefully detects `PermissionStatus.denied`, displays an informational banner in Settings, and disables notification toggle without crashing. |
| 19 | RTL / Localization | Dynamic numbers, prep times, and dates rendered in Arabic | Prep time displayed as "٣٠ دقيقة" or "30 دقيقة" with proper pluralization ("دقيقة / دقائق"). Dates formatted with Arabic locale (`ar_EG` or `ar`). Text direction stays strictly RTL. |
| 20 | State Synchronization | Adding/editing a meal in Vault must reflect immediately on Home screen | Riverpod `@riverpod` providers watch Drift streams (`watchAllMeals()`, `watchHistory()`). Modifying a meal triggers instant reactive updates across all active screens without manual refresh. |

---

## 4. Granular Requirements Specification

### 4.1 R1: Meal Vault (Local Database - Drift SQLite)

#### Data Schemas & Constraints
Drift (SQLite) is the authoritative persistence engine. The schema contains three core tables:

1. **`Meals` Table**:
   - `id`: `IntColumn`, Primary Key, `autoIncrement()`.
   - `name`: `TextColumn`, non-null, length between 1 and 100 characters.
   - `photoPath`: `TextColumn`, nullable. Storing absolute or relative local filesystem URI to picked photo.
   - `proteinType`: `TextColumn`, non-null. Standard values: `chicken` (دجاج), `beef` (لحوم حمراء), `fish` (أسماك ومأكولات بحرية), `legume` (بقوليات ونباتي), `dairy` (بيض وأجبان), `none` (بدون بروتين).
   - `carbsType`: `TextColumn`, non-null. Standard values: `rice` (أرز), `pasta` (مكرونة), `bread` (خبز وعيش), `potato` (بطاطس), `legume` (بقوليات كشري), `none` (بدون نشويات / كيتو).
   - `category`: `TextColumn`, non-null. Standard values: `baladi` (أكلات شعبية وبلدي), `fast` (سريع وسهل), `tagine` (طواجن وصواني), `diet` (دايت وخفيف), `soup` (شوربات وخضار مطبوخ), `grill` (مشاوي).
   - `prepTime`: `IntColumn`, non-null. Duration in minutes (e.g., 20, 30, 45, 60).
   - `isFridaySpecial`: `BoolColumn`, non-null, default `false`. Designates special weekend/family banquet dishes (عزومات الجمعة).
   - `isBudgetFriendly`: `BoolColumn`, non-null, default `false`. Designates economical meals (على أد الإيد).
   - `isFavorite`: `BoolColumn`, non-null, default `false`. Quick filter for favorite dishes.
   - `createdAt`: `DateTimeColumn`, non-null, default `currentDateAndTime`.
   - `updatedAt`: `DateTimeColumn`, nullable.

2. **`MealHistory` Table**:
   - `id`: `IntColumn`, Primary Key, `autoIncrement()`.
   - `mealId`: `IntColumn`, nullable, Foreign Key referencing `Meals(id)` with `onDelete: KeyAction.setNull`. This prevents foreign key constraint violations and retains historical cooking analytics if a meal is deleted from the vault.
   - `mealName`: `TextColumn`, non-null. Snapshot of meal name at the time of cooking.
   - `proteinType`: `TextColumn`, non-null. Snapshot of protein at time of cooking.
   - `carbsType`: `TextColumn`, non-null. Snapshot of carbs at time of cooking.
   - `cookedAt`: `DateTimeColumn`, non-null, default `currentDateAndTime`.
   - `entryType`: `TextColumn`, non-null, default `'cooked'`. Allowed values: `'cooked'` (fresh cooking) or `'leftover'` (eating leftovers).
   - `notes`: `TextColumn`, nullable. Optional user remarks.

3. **`AppSettings` Table**:
   - `id`: `IntColumn`, Primary Key (fixed row ID = 1).
   - `cooldownDays`: `IntColumn`, non-null, default 14.
   - `themeMode`: `TextColumn`, non-null, default `'system'` (`'system'`, `'light'`, `'dark'`).
   - `notificationEnabled`: `BoolColumn`, non-null, default `true`.
   - `notificationHour`: `IntColumn`, non-null, default 11 (11:00 AM).
   - `notificationMinute`: `IntColumn`, non-null, default 0.
   - `preventRepeatProtein`: `BoolColumn`, non-null, default `true`.
   - `preventRepeatCarbs`: `BoolColumn`, non-null, default `true`.

#### Data Access Objects (DAOs) / Queries
- **Meals Queries**:
  - `watchAllMeals()`: `Stream<List<Meal>>` — reactive stream consumed by Riverpod providers.
  - `getAllMeals()`: `Future<List<Meal>>`.
  - `getMealById(int id)`: `Future<Meal?>`.
  - `insertMeal(MealsCompanion meal)`: `Future<int>`.
  - `updateMeal(Meal meal)`: `Future<bool>`.
  - `deleteMeal(int id)`: `Future<int>`.
  - `seedDefaultMeals(List<MealsCompanion> meals)`: `Future<void>`.
- **History Queries**:
  - `watchRecentHistory({int limit = 50})`: `Stream<List<MealHistoryEntry>>`.
  - `getLastCookedMeal()`: `Future<MealHistoryEntry?>`.
  - `getCookedMealsSince(DateTime cutoff)`: `Future<List<MealHistoryEntry>>`.
  - `insertHistoryEntry(MealHistoryCompanion entry)`: `Future<int>`.
  - `deleteHistoryEntry(int id)`: `Future<int>`.
- **Settings Queries**:
  - `watchSettings()`: `Stream<AppSetting>`.
  - `getSettings()`: `Future<AppSetting>`.
  - `updateSettings(AppSettingsCompanion settings)`: `Future<bool>`.

---

### 4.2 R2: Recommendation Engine & Home Screen

#### Cooldown Algorithm Mathematical Logic
Let $M$ denote the set of all available meals in the vault, $|M| = N$.  
Let $H$ denote the history entries sorted descending by `cookedAt`.  
Let $T$ denote the current time (`DateTime.now()`).  
Let $C_{days}$ denote the user-defined cooldown duration (default: 14 days).  
Let $Cutoff = T - (C_{days} \times 24 \text{ hours})$.

1. **Step 1: Recency Exclusion Pool ($S_{recent}$)**:
   Extract all meal IDs marked as `entryType == 'cooked'` where $cookedAt \ge Cutoff$:
   $$S_{recent} = \{ h.mealId \mid h \in H \text{ where } h.cookedAt \ge Cutoff \text{ and } h.mealId \ne \text{null} \}$$
   Available non-cooldown candidates:
   $$M_1 = \{ m \in M \mid m.id \notin S_{recent} \}$$

2. **Step 2: Macronutrient Repeat Prevention**:
   Find the most recent entry $h_0 \in H$. If $h_0$ exists:
   - Last Protein $P_{prev} = h_0.proteinType$
   - Last Carbs $K_{prev} = h_0.carbsType$
   
   If `preventRepeatProtein` is enabled:
   $$M_2 = \{ m \in M_1 \mid m.proteinType \ne P_{prev} \}$$
   If `preventRepeatCarbs` is enabled:
   $$M_3 = \{ m \in M_2 \mid m.carbsType \ne K_{prev} \}$$
   Otherwise:
   $$M_3 = M_2$$

3. **Step 3: Friday Special Weighting**:
   If today is Friday (`T.weekday == DateTime.friday`):
   - Separate $M_3$ into Friday specials ($F = \{ m \in M_3 \mid m.isFridaySpecial == \text{true} \}$) and regular ($R = M_3 \setminus F$).
   - Shuffle $F$ and $R$ independently.
   - Recommended stack candidates = $[ \dots F, \dots R ]$.
   Else:
   - Recommended stack candidates = $M_3$ shuffled.

4. **Step 4: Graceful Degradation Hierarchy (Fallback Cascade)**:
   If candidates count $|M_3| < 3$:
   - **Fallback Stage 1 (Relax Carbs)**: Re-admit meals from $M_1$ where $m.proteinType \ne P_{prev}$ even if $m.carbsType == K_{prev}$.
   - **Fallback Stage 2 (Relax Protein)**: Re-admit meals from $M_1$ regardless of protein or carbs repetition.
   - **Fallback Stage 3 (Reduce Cooldown Window)**: Progressively evaluate cooldown at $C_{days} / 2$ (e.g. 7 days), then 3 days, then 1 day.
   - **Fallback Stage 4 (Exhaustion)**: If candidates $< 3$, sort all meals in $M$ by least recently cooked ($cookedAt$ ascending) to fill remaining slots.
   - **Fallback Stage 5 (Empty Vault)**: If $|M| == 0$, return empty list `[]` and emit UI empty state.

#### 3-Card Stack UI Specifications
- Stack displays up to 3 cards layered with slight vertical offset and scale difference:
  - Top Card: Scale 1.0, Elevation 4, interactive buttons.
  - Middle Card: Scale 0.94, Elevation 2, slightly behind top card.
  - Bottom Card: Scale 0.88, Elevation 1, lowest in the stack.
- Card Elements:
  - High-quality image or vibrant food category graphic icon.
  - Meal Title (Large, Bold Arabic font).
  - Badges: Protein badge (e.g., "دجاج"), Carbs badge (e.g., "أرز"), Prep time (e.g., "٣٠ دقيقة").
  - Special Tags: "جمعة مباركة" (Friday), "على أد الإيد" (Budget), "المفضلة" (Favorite).
  - Action Row:
    - Primary Action (Filled Button): "طبختها النهاردة" (Cooked Today) with checkmark icon.
    - Secondary Action (Outlined Button): "أكل بايت / بواقي" (Leftovers) with repeat/container icon.
    - Tertiary Action (IconButton): "تبديل" (Reroll / Next Suggestion).

#### Spin the Wheel Roulette Specifications
- Dedicated floating button on Home screen or top app bar action: "عجلة الحظ".
- Tapping opens an animated wheel dialog / bottom sheet.
- Wheel segments are populated dynamically from the current recommendation candidate pool (6 to 8 slices).
- Smooth deceleration physics with custom sound / haptic feedback if supported.
- Selected slice highlights with celebratory Arabic animation: "مبروك! وجبة النهاردة هي: [اسم الوجبة]".
- Immediate CTA: "اعتمد وطبختها النهاردة".

---

### 4.3 R3: History, Settings & Notifications

#### History Screen (سجل الأكلات)
- Grouped chronological list:
  - **اليوم (Today)**
  - **أمس (Yesterday)**
  - **خلال هذا الأسبوع (This Week)**
  - **أكلات سابقة (Earlier)**
- Each entry tile displays:
  - Date & Time formatted in Arabic (`yyyy/MM/dd` or localized relative format).
  - Meal Name snapshot.
  - Tag chip: "طبخ جديد" (Fresh Cook) vs "أكل بايت" (Leftover).
  - Protein & Carbs chips.
  - Delete icon with confirmation bottom sheet to undo accidental logs.

#### Settings Screen (الإعدادات)
- **فترة الاستبعاد (Cooldown Window)**:
  - Interactive Slider from 1 to 60 days (current value highlighted with indicator: "١٤ يوم").
  - Clear descriptive caption in Arabic: "استبعاد الوجبة من الاقتراحات لعدد الأيام المحدد بعد طبخها".
- **قواعد التنوع الغذائي (Dietary Diversity Rules)**:
  - Switch: "منع تكرار نوع البروتين يومين متتاليين".
  - Switch: "منع تكرار نوع النشويات يومين متتاليين".
- **المظهر (Appearance)**:
  - Segmented Button / Radio Group: تلقائي حسب النظام (System), مظهر فاتح (Light), مظهر داكن (Dark).
- **التنبيه اليومي (Daily Notification)**:
  - Switch: "تفعيل تذكير وجبة الغداء اليومي".
  - Time Picker tile: Displays chosen time (default "11:00 ص"). Tapping opens standard Material 3 TimePicker.
- **إدارة البيانات (Data Management)**:
  - "تحميل الأكلات المقترحة (Egyptian Preset Seeds)": re-seeds starter meals if vault has missing classics.
  - "إحصائيات الخزينة": shows total meals saved, total meals cooked.

#### Daily Local Notifications
- Integrated via `flutter_local_notifications`.
- Channel ID: `daily_meal_reminder`.
- Channel Name: `تذكير وجبة الغداء`.
- Description: `تنبيه يومي لمساعدتك في اختيار وجبة الغداء`.
- Notification Title: `أكلة النهاردة بتناديك! 🍲`
- Notification Body: `محتار تطبخ إيه النهاردة؟ افتح التطبيق وشوف اقتراحات النهاردة الذكية!`
- Notification Schedule: Uses `zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.time` to fire every day at user's designated hour & minute.
- Tap Action: Deep links directly to `/` (Home recommendations).
- Android 13+ Handling: Checks and requests `POST_NOTIFICATIONS` runtime permission gracefully.

---

### 4.4 R4: Architecture & UI Specifications

#### Codebase Layout (Feature-First Architecture)
```
lib/
├── main.dart                               # Entry point, ProviderScope, initialization
├── app.dart                                # MaterialApp.router, theme configuration, locale setup
├── core/
│   ├── database/
│   │   ├── app_database.dart               # Drift database definition, migration, singleton
│   │   ├── tables/
│   │   │   ├── meals_table.dart            # Drift Meals table
│   │   │   ├── meal_history_table.dart     # Drift MealHistory table
│   │   │   └── app_settings_table.dart     # Drift AppSettings table
│   │   ├── daos/
│   │   │   ├── meals_dao.dart
│   │   │   ├── meal_history_dao.dart
│   │   │   └── app_settings_dao.dart
│   │   └── seeds/
│   │       └── initial_meals_seed.dart     # Classic Egyptian recipes seed list
│   ├── notifications/
│   │   └── notification_service.dart       # flutter_local_notifications scheduling service
│   ├── router/
│   │   └── app_router.dart                 # GoRouter route definitions & shell navigation
│   ├── theme/
│   │   ├── app_theme.dart                  # Material Design 3 ThemeData (Light & Dark)
│   │   └── color_palette.dart              # Food-inspired terracotta / warm saffron color tokens
│   └── utils/
│       ├── date_utils.dart                 # Arabic date formatting helpers
│       └── text_direction_helper.dart      # RTL validation helpers
└── features/
    ├── home/
    │   ├── domain/
    │   │   └── recommendation_engine.dart  # Cooldown Algorithm & Fallback Cascade
    │   ├── presentation/
    │   │   ├── home_screen.dart            # Main container screen
    │   │   ├── widgets/
    │   │   │   ├── meal_card_stack.dart    # 3-card stack widget
    │   │   │   ├── meal_card.dart          # Individual recommendation card
    │   │   │   ├── roulette_dialog.dart    # Spin the Wheel roulette
    │   │   │   └── empty_vault_card.dart   # Empty state widget
    │   └── providers/
    │       └── recommendation_provider.dart# Riverpod StateNotifier / Notifier for recommendations
    ├── vault/
    │   ├── presentation/
    │   │   ├── vault_screen.dart           # Catalog grid/list with search & filter chips
    │   │   ├── meal_form_screen.dart       # Add / Edit meal form
    │   │   └── widgets/
    │   │       ├── meal_list_item.dart
    │   │       └── category_filter_bar.dart
    │   └── providers/
    │       └── vault_provider.dart         # Riverpod provider for meal CRUD
    ├── history/
    │   ├── presentation/
    │   │   ├── history_screen.dart         # Grouped timeline of past meals
    │   │   └── widgets/
    │   │       └── history_item_tile.dart
    │   └── providers/
    │       └── history_provider.dart       # Riverpod provider for history logs
    └── settings/
        ├── presentation/
        │   └── settings_screen.dart        # Cooldown slider, theme switcher, notification picker
        └── providers/
            └── settings_provider.dart      # Riverpod provider for app settings
```

#### State Management (Riverpod)
- All database operations and business logic are wrapped in `@riverpod` annotated providers:
  - `databaseProvider`: Provides the singleton `AppDatabase`.
  - `mealsStreamProvider`: Auto-disposing stream provider watching `watchAllMeals()`.
  - `historyStreamProvider`: Auto-disposing stream provider watching `watchRecentHistory()`.
  - `settingsNotifierProvider`: Notifier managing reactive settings mutations.
  - `recommendationNotifierProvider`: Computes and serves current 3-card recommendation stack based on meals, history, and settings streams.
  - `themeModeNotifierProvider`: Feeds theme mode directly into `MaterialApp.router`.

#### Navigation (GoRouter)
- Uses `StatefulShellRoute.indexedStack` for bottom navigation bar preservation:
  - Branch 0: `/` (Home / الاقتراحات)
  - Branch 1: `/vault` (Vault / الخزينة) with sub-routes `/vault/add` and `/vault/edit/:id`
  - Branch 2: `/history` (History / السجل)
  - Branch 3: `/settings` (Settings / الإعدادات)

#### Material Design 3 & Arabic RTL
- Material 3 enabled via `useMaterial3: true`.
- Color Scheme: Warm Terracotta Seed `Color(0xFFE65100)` generating tonal palettes for both Light and Dark themes.
- Global Locale: `Locale('ar')`, supportedLocales: `[Locale('ar')]`.
- Directionality: Natural `TextDirection.rtl` enforced across all layouts, dialogs, bottom sheets, and form fields.

---

## 5. Acceptance Criteria Traceability Matrix

| Requirement | Acceptance Criteria | Exact Verification Target |
|-------------|---------------------|---------------------------|
| Compilation | `flutter build apk` completes with exit code 0 | Android APK artifact produced in `build/app/outputs/flutter-apk/app-release.apk` |
| Static Quality | `flutter analyze` returns zero issues | Zero errors, zero warnings, zero linter warnings |
| Database CodeGen | Drift database code generation runs cleanly | `dart run build_runner build --delete-conflicting-outputs` succeeds |
| Cooldown Unit Tests | Unit tests verify: (1) meals cooked < 14d are filtered out, (2) repeating protein is filtered out, (3) repeating carbs is filtered out, (4) Friday special prioritization works, (5) multi-stage fallback works | `flutter test test/recommendation_engine_test.dart` passes 100% |
| Vault CRUD Tests | Unit tests verify: adding, editing, deleting meals, and verifying Riverpod state reactivity | `flutter test test/vault_crud_test.dart` passes 100% |
| RTL & UI Validation | App launches in Right-to-Left by default; Arabic strings wrap correctly | Widget tests verifying `Directionality.of(context) == TextDirection.rtl` and key Arabic text widgets |

---
