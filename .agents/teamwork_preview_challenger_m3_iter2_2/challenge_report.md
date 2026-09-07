# Adversarial Challenge Report — Milestone 3 Iteration 2

**Agent Identity:** teamwork_preview_challenger_m3_iter2_2 (Reactivity & Scoped Undo Challenger)  
**Parent Agent:** 3efea0b8-0374-4d39-8f46-d670012fcd8a  
**Target Milestone:** Milestone 3 Iteration 2 (Presentation Layer & State Flow Hardening)  
**Test Harness File:** `test/unit/riverpod_scoped_undo_adversarial_test.dart`  
**Date:** 2026-09-07  

---

## 1. Challenge Summary

**Overall Risk Assessment:** **HIGH**  
**Verdict:** **REJECT** (Scoped undo by ID is robust and approved; however, the backwards-compatible unscoped undo and `watchHistory()` fail due to missing tie-breaker sorting and stale `currentTimeProvider` caching).

While the worker successfully implemented scoped undo targeting (`undoLastCookingLog(historyEntryId)`), resolving the primary SnackBar race hazard, empirical testing revealed an unhandled failure mode in the fallback path (`undoLastCookingLog()` without arguments) and in `MealHistoryDao` query ordering:
1. When multiple meals are logged in the same application session, `ref.read(currentTimeProvider)` returns an identical timestamp for all entries because `currentTimeProvider` is defined as a non-auto-dispose `Provider<DateTime>` that caches `DateTime.now()` upon initial evaluation.
2. In `lib/core/database/daos/meal_history_dao.dart`, `getRecentHistory()`, `watchHistory()`, and `getLatestCookedMeal()` only order by `OrderingTerm.desc(t.cookedAt)` with no secondary tie-breaker (`OrderingTerm.desc(t.id)`).
3. SQLite resolves ties in descending index order by returning rows in ascending primary key order (`id ASC`).
4. Consequently, `getRecentHistory(limit: 1)` returns the **first/oldest** logged meal of the session, causing unscoped `undoLastCookingLog()` to delete the user's oldest meal rather than their most recent meal.
5. Similarly, `watchHistory()` streams history items with identical timestamps in forward chronological order (`[oldest, ..., newest]`), reversing the reverse-chronological expectation of the history UI.

---

## 2. Challenges & Empirical Vulnerabilities

### [HIGH] Challenge 1: Unscoped `undoLastCookingLog()` Deletes Oldest Meal on Timestamp Ties

- **Assumption Challenged:** The worker claimed in `changes.md` line 41 that when `historyEntryId` is omitted, `undoLastCookingLog()` *"safely falls back to deleting the most recent entry for backwards compatibility"*.
- **Attack Scenario:**
  1. A user logs Meal 1 (`id: 1`) via `logCookedToday(meal1)`.
  2. The user then logs Meal 2 (`id: 2`) via `logCookedToday(meal2)` within the same session.
  3. A caller invokes `undoLastCookingLog()` without arguments.
- **Observed Empirical Result:**
  - `allEntries[0].cookedAt == allEntries[1].cookedAt` holds true.
  - `getRecentHistory(limit: 1)` evaluates `SELECT * FROM meal_history ORDER BY cooked_at DESC LIMIT 1`. Because `cookedAt` values are identical, SQLite returns `id: 1` (the oldest entry).
  - `undoLastCookingLog()` executes `deleteHistoryEntry(1)`, deleting the **oldest** entry (`id: 1`) and leaving the newest entry (`id: 2`) in the database.
  - Empirically reproduced and confirmed in `test/unit/riverpod_scoped_undo_adversarial_test.dart` (Test 3.1b).
- **Blast Radius:** Accidental data loss of early history entries whenever unscoped undo is called in multi-meal sessions or bulk logging.
- **Mitigation:**
  In `lib/core/database/daos/meal_history_dao.dart`:
  Update `getRecentHistory` (line 60), `watchHistory` (line 20), and `getLatestCookedMeal` (line 83) to add a secondary ordering term:
  ```dart
  ..orderBy([
    (t) => OrderingTerm.desc(t.cookedAt),
    (t) => OrderingTerm.desc(t.id),
  ])
  ```

---

### [HIGH] Challenge 2: `currentTimeProvider` Statically Freezes Timestamp Throughout Container Lifetime

- **Assumption Challenged:** `currentTimeProvider` provides the current time for cooking log operations.
- **Attack Scenario:**
  In `lib/features/home/providers/recommendation_provider.dart`:
  ```dart
  final currentTimeProvider = Provider<DateTime>((ref) {
    return DateTime.now();
  });
  ```
  And in `RecommendationController`:
  ```dart
  final id = await historyDao.logCookedMeal(
    meal,
    cookedAt: ref.read(currentTimeProvider),
    notes: notes,
  );
  ```
  `Provider<DateTime>` is synchronous and non-auto-dispose. Once read, its value is cached permanently in the `ProviderContainer`.
- **Observed Empirical Result:**
  Every meal logged via `RecommendationController.logCookedToday` or `markLeftover` receives the exact same `cookedAt` timestamp across minutes or hours unless `currentTimeProvider` is explicitly invalidated or refreshed.
- **Blast Radius:**
  1. All meals logged during a single app session share an identical microsecond timestamp, triggering the Challenge 1 tie-breaker defect.
  2. Recommendations and cooldown calculations for same-session cooking logs lack millisecond/second granularity.
- **Mitigation:**
  Either:
  1. Use `ref.refresh(currentTimeProvider)` inside `logCookedToday` / `logLeftover`, or
  2. Pass `cookedAt ?? DateTime.now()` in `RecommendationController`, or
  3. Define `currentTimeProvider` as a clock function `Provider<DateTime Function()>` or auto-refreshing provider.

---

### [MEDIUM] Challenge 3: Inverted History Stream Order for Tied Timestamps in `watchHistory()`

- **Assumption Challenged:** `mealHistoryProvider` streams history in strictly reverse-chronological order.
- **Attack Scenario:**
  When multiple meals are added in the same session (sharing identical `cookedAt` via `currentTimeProvider`), `watchHistory()` executes:
  `select(mealHistory)..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])`
- **Observed Empirical Result:**
  SQLite returns tied rows in table scan / rowid order (`1, 2, 3`). The resulting list in `mealHistoryProvider` is `[Meal 1, Meal 2, Meal 3]`, which is **oldest-first** instead of newest-first.
- **Blast Radius:** The history screen displays same-session entries in reverse order (upside down).
- **Mitigation:** Add `(t) => OrderingTerm.desc(t.id)` to `watchHistory()`.

---

## 3. Stress Test Results & Empirical Evidence

### 3.1 Mandated Test Suites
| Test Suite | Command | Result | Details |
|---|---|---|---|
| Riverpod Adversarial Stress | `flutter test test/unit/riverpod_adversarial_m3_stress_test.dart` | **PASS (18/18)** | 50 rapid sequential additions, 30 deletions, 20 favorite toggles, small vault boundaries, reader/writer storm. |
| Riverpod Container Reactivity | `flutter test test/unit/riverpod_container_reactivity_test.dart` | **PASS (3/3)** | `allMealsProvider` emission, `recommendationProvider` cooldown invalidation, `filteredMealsProvider` filters. |

### 3.2 Empirical Challenger Test Suite (`test/unit/riverpod_scoped_undo_adversarial_test.dart`)
| Test ID | Description | Expected Behavior | Actual Behavior | Result |
|---|---|---|---|---|
| **1.1** | Scoped undo of middle record (A, B, C -> undo B) | Deletes ONLY B; A and C remain intact in DB and stream | B deleted; A and C present in DB and `mealHistoryProvider` | **PASS** |
| **1.2** | Scoped undo of oldest entry | Deletes oldest; newer entry remains | Oldest deleted; newer intact | **PASS** |
| **1.3** | Cooldown reactivity restoration | Scoped undo restores excluded meal to `todayRecommendationsProvider` | Meal reappears in recommendations immediately upon undo | **PASS** |
| **2.1** | Sequential double-tap on undo ID | Does not throw, does not delete unrelated records | Idempotent, 0 errors, remaining records intact | **PASS** |
| **2.2** | Concurrent double-tap on undo ID (`Future.wait`) | Settles cleanly without race crash | Both futures complete cleanly, 1 record removed | **PASS** |
| **2.3** | Undo non-existent ID (`9999999`) | Completes cleanly without side effects | 0 errors, no rows deleted | **PASS** |
| **3.1a** | Unscoped undo with distinct timestamps | Deletes newest entry | Newest entry deleted, oldest remains | **PASS** |
| **3.1b** | **[EMPIRICAL BUG REPRODUCTION]** Unscoped undo without time refresh | Deletes newest entry | **Deletes OLDEST entry (h1 deleted, h2 remained)** | **FAIL / BUG CONFIRMED** |
| **3.2** | Unscoped undo with explicit `null` arg | Acts as unscoped undo | Deletes entry | **PASS** |
| **3.3** | Unscoped undo on empty history | Completes cleanly without throwing | 0 errors | **PASS** |
| **3.4** | `undoHistoryEntry` alias | Deletes exact targeted ID | Targeted ID deleted | **PASS** |
| **4.1** | Rapid 10-meal log + random 4-entry scoped undo | Removes ONLY the 4 selected IDs; 6 remain intact with exact snapshot data | Exactly 6 remain; 4 removed; snapshot fields 100% match | **PASS** |
| **4.2** | Concurrent random scoped undo (`Future.wait`) | Clean deletion without DB locks | 3 entries deleted concurrently, 5 remain | **PASS** |
| **5.1** | Scoped undo of leftover vs cooked entry | Deletes ONLY leftover; cooked remains | Leftover deleted; cooked intact | **PASS** |

### 3.3 Static Analysis
- `flutter analyze test/unit/riverpod_scoped_undo_adversarial_test.dart`: **No issues found!** (0 errors, 0 warnings, 0 infos).

---

## 4. Unchallenged Areas

- Device local notifications (`flutter_local_notifications`): Scheduled for Milestone 4; out of scope for M3.
- SQLite schema migration v1 to v2: No migrations introduced in M3.

---

## 5. Verdict & Recommendation

**Verdict:** **REJECT**

**Reasoning:**
While the scoped undo implementation (`undoLastCookingLog(historyEntryId)`) and the UI integration in `home_screen.dart` are robust, the implementation fails the explicit acceptance criterion:
> *"Calling unscoped `undoLastCookingLog()` still works for backwards compatibility."*

Under default application runtime conditions, calling unscoped `undoLastCookingLog()` deletes the oldest record in history instead of the newest record due to the absence of `OrderingTerm.desc(t.id)` in `MealHistoryDao` and the static evaluation of `currentTimeProvider`.

**Required Remediation:**
1. In `lib/core/database/daos/meal_history_dao.dart`:
   Add `(t) => OrderingTerm.desc(t.id)` to `watchHistory()`, `getRecentHistory()`, and `getLatestCookedMeal()`.
2. In `lib/features/home/providers/recommendation_provider.dart`:
   Ensure `currentTimeProvider` is refreshed upon logging or allow `logCookedToday` to default to `DateTime.now()`.
