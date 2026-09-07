# Drift DAO Ordering & Dynamic Timestamping Remediation Plan

**Milestone:** Milestone 3 Iteration 3  
**Agent Identity:** `teamwork_preview_explorer_m3_iter3_2`  
**Target Files:**
- `lib/core/database/daos/meal_history_dao.dart`
- `lib/features/home/providers/recommendation_provider.dart`
- `test/unit/database_test.dart`
- `test/unit/riverpod_scoped_undo_adversarial_test.dart`

---

## 1. Executive Summary & Root Cause Analysis

### 1.1 Problem Statement
In Milestone 3 Iteration 2, the adversarial challenger (`teamwork_preview_challenger_m3_iter2_2`) rejected the iteration because calling unscoped `undoLastCookingLog()` deleted the user's **oldest** meal instead of their **newest** meal whenever entries shared identical timestamps. Additionally, the history stream in `watchHistory()` and `HistoryScreen` displayed tied entries in ascending `id` order (forward chronological / upside-down) rather than descending `id` order (reverse chronological).

### 1.2 Root Cause 1: SQLite Ordering Tie-Breaker Defect in Drift DAO
In `lib/core/database/daos/meal_history_dao.dart`:
- `watchHistory()` (line 20)
- `watchHistoryWithMeal()` (line 31)
- `watchLatestCookedMeal()` (line 46)
- `getAllHistory()` (line 53)
- `getRecentHistory({int limit = 60})` (line 59)
- `getHistoryWithinDays()` (line 72)
- `getLatestCookedMeal()` (line 82)

All seven queries specified `..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])` without a secondary sorting criterion.
In SQLite, when an index or table scan executes `ORDER BY cooked_at DESC` and multiple rows have identical `cooked_at` values, SQLite orders ties by rowid ascending (`id ASC`).
Consequently:
- `getRecentHistory(limit: 1)` returns the first inserted row (`id: 1`, oldest).
- `undoLastCookingLog()` (unscoped fallback) queries `getRecentHistory(limit: 1)` and calls `deleteHistoryEntry(recent.first.id)`, deleting the oldest record in the database.
- `watchHistory()` and `watchHistoryWithMeal()` stream tied rows as `[id: 1, id: 2, id: 3]`, which is oldest-first instead of newest-first.

### 1.3 Root Cause 2: Static `currentTimeProvider` Caching in Riverpod
In `lib/features/home/providers/recommendation_provider.dart`:
- Line 20 defines:
  ```dart
  final currentTimeProvider = Provider<DateTime>((ref) {
    return DateTime.now();
  });
  ```
- Lines 97 and 119 in `RecommendationController` logged meals using:
  ```dart
  cookedAt: ref.read(currentTimeProvider),
  ```
Because `currentTimeProvider` is a standard synchronous, non-auto-dispose `Provider<DateTime>`, Riverpod caches its return value permanently upon first evaluation for the container lifetime. Any meal logged within that application session received the exact same microsecond timestamp, guaranteeing that every multi-meal session suffered from the SQLite tie-breaker defect.

---

## 2. Dual-Pillar Architecture Remediation

To create a robust, defense-in-depth implementation, we apply two complementary changes:

1. **Pillar 1 — Deterministic Tie-Breaking in Drift DAO (`OrderingTerm.desc(t.id)`):**
   Add `(t) => OrderingTerm.desc(t.id)` as the secondary order term across all history queries in `MealHistoryDao`. Even if two rows share the exact same microsecond timestamp (batch inserts, clock drift, simulated test times), SQLite will always sort `id DESC`, ensuring LIFO stack semantics for unscoped undo and newest-first display.

2. **Pillar 2 — Dynamic Timestamping in `RecommendationController`:**
   In `logCookedToday` and `logLeftover` (and their aliases `markCookedToday` and `markLeftover`), accept an optional `{DateTime? cookedAt, String? notes}` named parameter and evaluate `cookedAt ?? DateTime.now()` at call time.
   - When called from the UI (`home_screen.dart`), `DateTime.now()` is dynamically invoked, giving real-time logs progressive, accurate timestamps.
   - When called in tests or administrative tools, an explicit `cookedAt` can be supplied.
   - `currentTimeProvider` remains intact for `todayRecommendationsProvider` date math without polluting runtime cooking timestamps.

---

## 3. Exact File Diffs for Implementation Worker

### File 1: `lib/core/database/daos/meal_history_dao.dart`

```diff
--- a/lib/core/database/daos/meal_history_dao.dart
+++ b/lib/core/database/daos/meal_history_dao.dart
@@ -17,7 +17,10 @@ class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDaoMixin {
   /// Reactive stream of history entries ordered descending by cookedAt
   Stream<List<MealHistoryData>> watchHistory({int? limit}) {
     final query = select(mealHistory)
-      ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)]);
+      ..orderBy([
+        (t) => OrderingTerm.desc(t.cookedAt),
+        (t) => OrderingTerm.desc(t.id),
+      ]);
     if (limit != null && limit > 0) {
       query.limit(limit);
     }
@@ -28,7 +31,10 @@ class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDaoMixin {
   Stream<List<MealHistoryWithMeal>> watchHistoryWithMeal() {
     final query = select(mealHistory).join([
       leftOuterJoin(meals, meals.id.equalsExp(mealHistory.mealId)),
-    ])..orderBy([OrderingTerm.desc(mealHistory.cookedAt)]);
+    ])..orderBy([
+        OrderingTerm.desc(mealHistory.cookedAt),
+        OrderingTerm.desc(mealHistory.id),
+      ]);
 
     return query.watch().map((rows) {
       return rows.map((row) {
@@ -43,7 +49,10 @@ class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDaoMixin {
   /// Reactive stream for latest cooked meal
   Stream<MealHistoryData?> watchLatestCookedMeal() {
     return (select(mealHistory)
-          ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])
+          ..orderBy([
+            (t) => OrderingTerm.desc(t.cookedAt),
+            (t) => OrderingTerm.desc(t.id),
+          ])
           ..limit(1))
         .watchSingleOrNull();
   }
@@ -51,13 +60,19 @@ class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDaoMixin {
   /// Snapshot of all history entries
   Future<List<MealHistoryData>> getAllHistory() {
-    return (select(mealHistory)..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])).get();
+    return (select(mealHistory)
+          ..orderBy([
+            (t) => OrderingTerm.desc(t.cookedAt),
+            (t) => OrderingTerm.desc(t.id),
+          ]))
+        .get();
   }
 
   /// Fetch recent history entries up to [limit]
   Future<List<MealHistoryData>> getRecentHistory({int limit = 60}) {
     return (select(mealHistory)
-      ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])
+      ..orderBy([
+        (t) => OrderingTerm.desc(t.cookedAt),
+        (t) => OrderingTerm.desc(t.id),
+      ])
       ..limit(limit)).get();
   }
 
@@ -70,7 +85,10 @@ class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDaoMixin {
     final cutoff = ref.subtract(Duration(days: days));
     return (select(mealHistory)
       ..where((t) => t.cookedAt.isBiggerOrEqualValue(cutoff))
-      ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])).get();
+      ..orderBy([
+        (t) => OrderingTerm.desc(t.cookedAt),
+        (t) => OrderingTerm.desc(t.id),
+      ])).get();
   }
 
   /// Fetch the latest single cooked meal entry
@@ -79,7 +97,10 @@ class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDaoMixin {
     if (beforeDate != null) {
       query.where((t) => t.cookedAt.isSmallerOrEqualValue(beforeDate));
     }
     query
-      ..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])
+      ..orderBy([
+        (t) => OrderingTerm.desc(t.cookedAt),
+        (t) => OrderingTerm.desc(t.id),
+      ])
       ..limit(1);
     return query.getSingleOrNull();
   }
```

---

### File 2: `lib/features/home/providers/recommendation_provider.dart`

```diff
--- a/lib/features/home/providers/recommendation_provider.dart
+++ b/lib/features/home/providers/recommendation_provider.dart
@@ -88,13 +88,14 @@ class RecommendationController extends AsyncNotifier<void> {
   @override
   FutureOr<void> build() {}
 
-  /// Logs a meal as 'cooked today'.
-  Future<int> logCookedToday(Meal meal, {String? notes}) async {
+  /// Logs a meal as 'cooked today'. Dynamically obtains DateTime.now() if cookedAt is null.
+  Future<int> logCookedToday(Meal meal, {DateTime? cookedAt, String? notes}) async {
     state = const AsyncValue.loading();
     try {
       final historyDao = ref.read(mealHistoryDaoProvider);
       final id = await historyDao.logCookedMeal(
         meal,
-        cookedAt: ref.read(currentTimeProvider),
+        cookedAt: cookedAt ?? DateTime.now(),
         notes: notes,
       );
       state = const AsyncValue.data(null);
@@ -107,17 +108,17 @@ class RecommendationController extends AsyncNotifier<void> {
   }
 
   /// Alias for logCookedToday
-  Future<int> markCookedToday(Meal meal, {String? notes}) =>
-      logCookedToday(meal, notes: notes);
+  Future<int> markCookedToday(Meal meal, {DateTime? cookedAt, String? notes}) =>
+      logCookedToday(meal, cookedAt: cookedAt, notes: notes);
 
-  /// Logs a meal as 'leftover'.
-  Future<int> logLeftover(Meal meal, {String? notes}) async {
+  /// Logs a meal as 'leftover'. Dynamically obtains DateTime.now() if cookedAt is null.
+  Future<int> logLeftover(Meal meal, {DateTime? cookedAt, String? notes}) async {
     state = const AsyncValue.loading();
     try {
       final historyDao = ref.read(mealHistoryDaoProvider);
       final id = await historyDao.logLeftoverMeal(
         meal,
-        cookedAt: ref.read(currentTimeProvider),
+        cookedAt: cookedAt ?? DateTime.now(),
         notes: notes,
       );
       state = const AsyncValue.data(null);
@@ -130,8 +131,8 @@ class RecommendationController extends AsyncNotifier<void> {
   }
 
   /// Alias for logLeftover
-  Future<int> markLeftover(Meal meal, {String? notes}) =>
-      logLeftover(meal, notes: notes);
+  Future<int> markLeftover(Meal meal, {DateTime? cookedAt, String? notes}) =>
+      logLeftover(meal, cookedAt: cookedAt, notes: notes);
```

---

### File 3: `test/unit/riverpod_scoped_undo_adversarial_test.dart`

Update Test 3.1b from bug demonstration to resolution verification, and append Test 3.1c:

```diff
--- a/test/unit/riverpod_scoped_undo_adversarial_test.dart
+++ b/test/unit/riverpod_scoped_undo_adversarial_test.dart
@@ -288,34 +288,57 @@ void main() {
-      test('3.1b [EMPIRICAL BUG REPRODUCTION] Unscoped undo without time refresh deletes OLDEST entry due to missing id DESC tie-breaker', () async {
+      test('3.1b [RESOLVED] Unscoped undo deletes newest entry (h2) even when timestamps are identical via id DESC tie-breaker', () async {
         final vaultController = container.read(vaultControllerProvider.notifier);
         final recController = container.read(recommendationControllerProvider.notifier);
 
         final id1 = await vaultController.addMeal(name: 'وجبة 1 (أولى)', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
         final id2 = await vaultController.addMeal(name: 'وجبة 2 (ثانية)', proteinType: ProteinType.beef, carbsType: CarbsType.pasta, category: MealCategory.ovenBaked, prepTimeMinutes: 20);
 
         final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
         final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;
 
-        // Log two meals in normal app session without refreshing currentTimeProvider
-        final h1 = await recController.logCookedToday(m1);
-        await settle(20);
-        final h2 = await recController.logCookedToday(m2);
+        // Log two meals with identical timestamps to challenge the tie-breaker
+        final fixedTime = DateTime(2026, 9, 7, 12, 0, 0);
+        final h1 = await recController.logCookedToday(m1, cookedAt: fixedTime);
+        final h2 = await recController.logCookedToday(m2, cookedAt: fixedTime);
 
         await settle(60);
 
         // Verify both entries share the exact same cookedAt timestamp
         final allEntries = await inMemoryDb.mealHistoryDao.getAllHistory();
         expect(allEntries[0].cookedAt, equals(allEntries[1].cookedAt),
-            reason: 'Riverpod Provider<DateTime> caches DateTime.now(), creating identical timestamps');
+            reason: 'Both entries explicitly share the identical timestamp');
 
-        // Unscoped undo should delete the LAST logged entry (h2), but instead deletes the FIRST logged entry (h1)!
+        // Unscoped undo must delete the LAST logged entry (h2) via id DESC tie-breaker
         await recController.undoLastCookingLog();
         await settle(60);
 
         final remainingHistory = await inMemoryDb.mealHistoryDao.getAllHistory();
         expect(remainingHistory.length, equals(1));
+        expect(remainingHistory.first.id, equals(h1), reason: 'Oldest entry h1 must remain intact');
 
-        // BUG DEMONSTRATION: remaining entry is h2, meaning h1 (the OLDEST entry) was deleted!
         final deletedId = remainingHistory.first.id == h1 ? h2 : h1;
-        expect(deletedId, equals(h1),
-            reason: 'CRITICAL FLAW: unscoped undo deleted oldest log h1 instead of newest log h2 because SQLite ORDER BY cookedAt DESC resolves ties as id ASC');
+        expect(deletedId, equals(h2),
+            reason: 'Unscoped undo must delete newest entry h2 even when timestamps are identical');
+      });
+
+      test('3.1c Rapid sequential logs without explicit cookedAt obtain distinct dynamically progressive timestamps', () async {
+        final vaultController = container.read(vaultControllerProvider.notifier);
+        final recController = container.read(recommendationControllerProvider.notifier);
+
+        final id1 = await vaultController.addMeal(name: 'وجبة أ', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
+        final id2 = await vaultController.addMeal(name: 'وجبة ب', proteinType: ProteinType.beef, carbsType: CarbsType.pasta, category: MealCategory.ovenBaked, prepTimeMinutes: 20);
+
+        final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
+        final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;
+
+        final h1 = await recController.logCookedToday(m1);
+        await settle(15);
+        final h2 = await recController.logCookedToday(m2);
+
+        final allEntries = await inMemoryDb.mealHistoryDao.getAllHistory();
+        final entry1 = allEntries.firstWhere((e) => e.id == h1);
+        final entry2 = allEntries.firstWhere((e) => e.id == h2);
+
+        expect(entry2.cookedAt.isAfter(entry1.cookedAt) || entry2.cookedAt.isAtSameMomentAs(entry1.cookedAt), isTrue);
+        expect(entry2.id, greaterThan(entry1.id));
       });
```

---

### File 4: `test/unit/database_test.dart`

Add a dedicated DAO-level tie-breaker verification test inside `Group 3: MealHistory Table & MealHistoryDao Operations`:

```dart
    test('entries with identical cookedAt are strictly ordered by id DESC across all history queries (tie-breaker)', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      final fixedTimestamp = DateTime(2026, 9, 7, 12, 0, 0);

      // Log 3 meals with identical timestamps
      final id1 = await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: fixedTimestamp, notes: 'Entry 1');
      final id2 = await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: fixedTimestamp, notes: 'Entry 2');
      final id3 = await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: fixedTimestamp, notes: 'Entry 3');

      // 1. Verify getRecentHistory returns newest first (id DESC)
      final recent = await db.mealHistoryDao.getRecentHistory(limit: 3);
      expect(recent.length, equals(3));
      expect(recent[0].id, equals(id3));
      expect(recent[1].id, equals(id2));
      expect(recent[2].id, equals(id1));

      // 2. Verify getLatestCookedMeal returns newest entry (id3)
      final latest = await db.mealHistoryDao.getLatestCookedMeal();
      expect(latest, isNotNull);
      expect(latest!.id, equals(id3));

      // 3. Verify getAllHistory returns newest first (id DESC)
      final all = await db.mealHistoryDao.getAllHistory();
      expect(all.length, equals(3));
      expect(all.map((e) => e.id).toList(), equals([id3, id2, id1]));

      // 4. Verify watchHistory emits newest first
      final streamList = await db.mealHistoryDao.watchHistory().first;
      expect(streamList.length, equals(3));
      expect(streamList.map((e) => e.id).toList(), equals([id3, id2, id1]));
    });
```

---

## 4. Verification Protocol for Worker

After applying the diffs, the worker can independently verify the fix using:

```powershell
# 1. Static Analyzer Cleanliness (must return 0 issues)
flutter analyze lib/ test/unit/

# 2. Scoped & Unscoped Undo Adversarial Suite (all 15 tests must PASS)
flutter test test/unit/riverpod_scoped_undo_adversarial_test.dart

# 3. Database Unit Test Suite (including new tie-breaker test)
flutter test test/unit/database_test.dart

# 4. Stress & Concurrency Test Suite
flutter test test/unit/riverpod_adversarial_m3_stress_test.dart

# 5. Container Reactivity Suite
flutter test test/unit/riverpod_container_reactivity_test.dart

# 6. Widget Reactivity Suite
flutter test test/widget/riverpod_reactivity_test.dart
```

---

## 5. Invariant & Safety Checklist

- [x] **Zero Drift Schema Generation Required**: Only query definitions in DAO are updated. No table columns or schema versions are modified (`build_runner` not required).
- [x] **Zero API Breaking Changes**: `logCookedToday`, `markCookedToday`, `logLeftover`, and `markLeftover` preserve all existing parameter positions and default behaviors.
- [x] **LIFO Unscoped Stack Semantics**: Calling unscoped `undoLastCookingLog()` is guaranteed to delete the most recently inserted row (`id DESC`) even when timestamps collide.
- [x] **Reverse-Chronological UI Guarantee**: `HistoryScreen` and `watchHistory()` streams will never display tied records upside down.
