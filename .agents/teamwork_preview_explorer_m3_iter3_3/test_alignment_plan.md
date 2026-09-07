# Test Alignment & Static Analysis Plan — Milestone 3 Iteration 3

**Author:** `teamwork_preview_explorer_m3_iter3_3`  
**Target Milestone:** Milestone 3 Iteration 3 (Test Alignment, Secondary Ordering & 0-Diagnostic Hardening)  
**Parent Agent:** `3efea0b8-0374-4d39-8f46-d670012fcd8a`  
**Date:** 2026-09-07  

---

## 1. Executive Summary

This investigation resolves the two remaining test discrepancies surfaced during Milestone 3 Iteration 2:
1. **Drift Schema Constraint in `test/widget/challenger_viewport_overflow_test.dart` (CHALLENGE 3 / PASS-3)**:  
   Drift's `MealsTable.name` specifies `withLength(min: 1, max: 120)`. Inserting names exceeding 120 characters causes Drift to throw `InvalidDataException`. The test is adjusted to use an exact 120-character string (`maxValidName.length == 120`), exercising the absolute maximum schema boundary for text scaling and layout rendering without violating the database constraint.
2. **Deprecated Riverpod Member in `test/widget/challenger_viewport_overflow_test.dart`**:  
   `ProviderScope(parent: container)` is replaced with `UncontrolledProviderScope(container: container)`, eliminating the `// ignore: deprecated_member_use` suppression and aligning with modern Riverpod idioms.
3. **Secondary Ordering Verification in `test/unit/riverpod_scoped_undo_adversarial_test.dart` (Test 3.1b)**:  
   Test 3.1b previously asserted that unscoped undo deleted `h1` (reproducing the defect where SQLite broke timestamp ties using `id ASC`). With `MealHistoryDao` implementing secondary sorting `(t) => OrderingTerm.desc(t.id)`, Test 3.1b is updated to assert that unscoped undo deletes `h2` (the newest entry) while preserving `h1`.
4. **Transition of Overflow Tests BUG-1..5 to Regression Protection**:  
   Formulates the assertion updates for BUG-1 through BUG-5 once the Worker applies the 5 layout fixes (`Wrap` in `MealVaultCard`, `Expanded` + `Wrap` in `AddEditMealDialog`, `scrollable: true` in `DeleteMealDialog`, and `SingleChildScrollView` in empty states).

---

## 2. File Investigation & Evidence Chain

### 2.1 Schema Analysis (`lib/core/database/tables/meals_table.dart:32`)
- **Direct Observation**:
  ```dart
  TextColumn get name => text().withLength(min: 1, max: 120)();
  ```
- **Constraint**: `min: 1`, `max: 120`. Any string length $> 120$ triggers `InvalidDataException` during `into(meals).insert(...)` or `MealsCompanion.insert(...)`.
- **Challenger String**:
  ```dart
  const extremeArabicLongName =
      'طاجن سمك وقار إسكندراني بلدي بالخل والتوم والليمون المعصفر والصلصة الحارة المسبكة بالفرن مع بطاطس محمرة وأرز صيادية وسلطة بلدي ومخلل لفت وفلفل حامي مشوي على الفحم';
  ```
  `extremeArabicLongName.length` is 154 characters.
- **Alignment Solution**:
  ```dart
  final maxValidName = '${extremeArabicLongName.substring(0, 118)} $i';
  ```
  For $i \in \{1, 2, 3\}$, `substring(0, 118)` (118 characters) + `' '` (1 character) + `'$i'` (1 character) produces a unique string of exactly 120 characters ($118 + 1 + 1 = 120$).
  This guarantees $120 \le 120$ (valid) and maximum visual stress on the UI layout.

### 2.2 Riverpod Scoping in Test Harness (`test/widget/challenger_viewport_overflow_test.dart:65-68`)
- **Direct Observation**:
  ```dart
  child: ProviderScope(
    // ignore: deprecated_member_use
    parent: container,
    overrides: overrides,
    child: MaterialApp(...),
  )
  ```
- **Issue**: `parent` parameter in `ProviderScope` is deprecated in `flutter_riverpod` 2.x.
- **Alignment Solution**:
  Use `UncontrolledProviderScope` when a container is provided:
  ```dart
  child: container != null
      ? UncontrolledProviderScope(
          container: container,
          child: app,
        )
      : ProviderScope(
          overrides: overrides,
          child: app,
        ),
  ```
  Eliminates the `deprecated_member_use` warning entirely.

### 2.3 Secondary Tie-Breaker Ordering in `MealHistoryDao` (`lib/core/database/daos/meal_history_dao.dart`)
- **Direct Observation**:
  `MealHistoryDao` currently sorts history using only `OrderingTerm.desc(t.cookedAt)`.
  When two meals are logged within the same millisecond or during a session where `currentTimeProvider` caches the timestamp, SQLite defaults to table order (`id ASC`).
  `getRecentHistory(limit: 1)` returns `h1` (oldest).
  `undoLastCookingLog()` deletes `h1`.
- **Worker Solution in `MealHistoryDao`**:
  Add `(t) => OrderingTerm.desc(t.id)` to all query order clauses:
  - `watchHistory({int? limit})`
  - `watchHistoryWithMeal()`
  - `watchLatestCookedMeal()`
  - `getAllHistory()`
  - `getRecentHistory({int limit = 60})`
  - `getHistoryWithinDays(...)`
  - `getLatestCookedMeal(...)`
- **Impact on Test 3.1b**:
  With `id DESC`, SQLite orders `(cookedAt DESC, id DESC)`. Since $h2.id > h1.id$, $h2$ is first.
  `undoLastCookingLog()` removes $h2$.
  Remaining record is $h1$.
  Deleted record is $h2$.

---

## 3. Exact Diffs and Code Snippets for Worker

### 3.1 Diff 1: `test/widget/challenger_viewport_overflow_test.dart`

```diff
--- a/test/widget/challenger_viewport_overflow_test.dart
+++ b/test/widget/challenger_viewport_overflow_test.dart
@@ -53,38 +53,44 @@ Widget buildTestApp({
   required Widget child,
   ProviderContainer? container,
   List<Override> overrides = const [],
   Size surfaceSize = const Size(320, 550),
   TextScaler textScaler = const TextScaler.linear(1.4),
 }) {
+  final app = MaterialApp(
+    title: 'Challenger UI Stress Test',
+    debugShowCheckedModeBanner: false,
+    theme: AppTheme.lightTheme,
+    locale: const Locale('ar'),
+    supportedLocales: const [Locale('ar')],
+    localizationsDelegates: const [
+      GlobalMaterialLocalizations.delegate,
+      GlobalWidgetsLocalizations.delegate,
+      GlobalCupertinoLocalizations.delegate,
+    ],
+    home: Directionality(
+      textDirection: TextDirection.rtl,
+      child: Scaffold(body: child),
+    ),
+  );
+
   return MediaQuery(
     data: MediaQueryData(
       size: surfaceSize,
       textScaler: textScaler,
     ),
-    child: ProviderScope(
-      // ignore: deprecated_member_use
-      parent: container,
-      overrides: overrides,
-      child: MaterialApp(
-        title: 'Challenger UI Stress Test',
-        debugShowCheckedModeBanner: false,
-        theme: AppTheme.lightTheme,
-        locale: const Locale('ar'),
-        supportedLocales: const [Locale('ar')],
-        localizationsDelegates: const [
-          GlobalMaterialLocalizations.delegate,
-          GlobalWidgetsLocalizations.delegate,
-          GlobalCupertinoLocalizations.delegate,
-        ],
-        home: Directionality(
-          textDirection: TextDirection.rtl,
-          child: Scaffold(body: child),
-        ),
-      ),
-    ),
+    child: container != null
+        ? UncontrolledProviderScope(
+            container: container,
+            child: app,
+          )
+        : ProviderScope(
+            overrides: overrides,
+            child: app,
+          ),
   );
 }
@@ -176,13 +182,14 @@ void main() {
       tester.view.physicalSize = const Size(320, 550);
       tester.view.devicePixelRatio = 1.0;
       addTearDown(tester.view.resetPhysicalSize);

-      final validLongName = extremeArabicLongName.substring(0, 115);
       for (int i = 1; i <= 3; i++) {
+        // Construct exact 120-character string (maximum valid length for MealsTable.name schema: min 1, max 120)
+        final exact120CharName = '${extremeArabicLongName.substring(0, 118)} $i';
+        expect(exact120CharName.length, equals(120), reason: 'Must test maximum allowed schema boundary of 120 chars');
         await db.mealsDao.insertMeal(
           MealsCompanion.insert(
-            name: '$validLongName $i',
+            name: exact120CharName,
             proteinType: ProteinType.values[i % ProteinType.values.length],
             carbsType: CarbsType.values[i % CarbsType.values.length],
             category: MealCategory.values[i % MealCategory.values.length],
```

#### Transitioning BUG-1..5 to Regression Assertions (once Worker applies UI fixes)
In `test/widget/challenger_viewport_overflow_test.dart` lines 268-476:
Rename group:
`group('CHALLENGER REGRESSION: Verified Zero RenderFlex Overflows in Constrained Viewports', () {`
And update assertions in each test:
- In BUG-1 (`MealVaultCard`):
  Replace:
  ```dart
  expect(overflowError, isNotNull, reason: 'Expected overflow in MealVaultCard badge row');
  expect(overflowError, contains('130 pixels'));
  ```
  With:
  ```dart
  expect(overflowError, isNull, reason: 'MealVaultCard badges must wrap gracefully without overflow');
  expect(tester.takeException(), isNull);
  ```
- In BUG-2 (`AddEditMealDialog`):
  Replace:
  ```dart
  expect(overflows.isNotEmpty, isTrue, reason: 'Expected overflow in AddEditMealDialog');
  expect(overflows.any((e) => e.contains('218 pixels') || e.contains('220 pixels')), isTrue);
  ```
  With:
  ```dart
  expect(overflows.isEmpty, isTrue, reason: 'AddEditMealDialog header and action rows must not overflow');
  expect(tester.takeException(), isNull);
  ```
- In BUG-3 (`DeleteMealDialog`):
  Replace:
  ```dart
  expect(overflowError, isNotNull, reason: 'Expected vertical overflow in DeleteMealDialog');
  expect(overflowError, contains('932 pixels'));
  ```
  With:
  ```dart
  expect(overflowError, isNull, reason: 'DeleteMealDialog must scroll cleanly without vertical overflow');
  expect(tester.takeException(), isNull);
  ```
- In BUG-4 (`VaultEmptyState`):
  Replace:
  ```dart
  expect(overflowError, isNotNull, reason: 'Expected vertical overflow in VaultEmptyState');
  expect(overflowError, contains('131 pixels'));
  ```
  With:
  ```dart
  expect(overflowError, isNull, reason: 'VaultEmptyState must fit or scroll without vertical overflow');
  expect(tester.takeException(), isNull);
  ```
- In BUG-5 (`HistoryScreen`):
  Replace:
  ```dart
  expect(overflowError, isNotNull, reason: 'Expected vertical overflow in HistoryScreen');
  expect(overflowError, contains('bottom'));
  ```
  With:
  ```dart
  expect(overflowError, isNull, reason: 'HistoryScreen empty state must fit or scroll without vertical overflow');
  expect(tester.takeException(), isNull);
  ```

---

### 3.2 Diff 2: `test/unit/riverpod_scoped_undo_adversarial_test.dart`

```diff
--- a/test/unit/riverpod_scoped_undo_adversarial_test.dart
+++ b/test/unit/riverpod_scoped_undo_adversarial_test.dart
@@ -288,7 +288,7 @@ void main() {
-      test('3.1b [EMPIRICAL BUG REPRODUCTION] Unscoped undo without time refresh deletes OLDEST entry due to missing id DESC tie-breaker', () async {
+      test('3.1b Unscoped undo without time refresh correctly deletes newest entry (h2) via id DESC secondary ordering', () async {
         final vaultController = container.read(vaultControllerProvider.notifier);
         final recController = container.read(recommendationControllerProvider.notifier);

         final id1 = await vaultController.addMeal(name: 'وجبة 1 (أولى)', proteinType: ProteinType.chicken, carbsType: CarbsType.rice, category: MealCategory.egyptianTraditional, prepTimeMinutes: 20);
         final id2 = await vaultController.addMeal(name: 'وجبة 2 (ثانية)', proteinType: ProteinType.beef, carbsType: CarbsType.pasta, category: MealCategory.ovenBaked, prepTimeMinutes: 20);

         final m1 = (await inMemoryDb.mealsDao.getMealById(id1))!;
         final m2 = (await inMemoryDb.mealsDao.getMealById(id2))!;

         // Log two meals in normal app session without refreshing currentTimeProvider
         final h1 = await recController.logCookedToday(m1);
         await settle(20);
         final h2 = await recController.logCookedToday(m2);

         await settle(60);

         // Verify both entries share the exact same cookedAt timestamp
         final allEntries = await inMemoryDb.mealHistoryDao.getAllHistory();
         expect(allEntries[0].cookedAt, equals(allEntries[1].cookedAt),
             reason: 'Riverpod Provider<DateTime> caches DateTime.now(), creating identical timestamps');

-        // Unscoped undo should delete the LAST logged entry (h2), but instead deletes the FIRST logged entry (h1)!
+        // Unscoped undo must delete the LAST logged entry (h2) even when cookedAt timestamps are identical
         await recController.undoLastCookingLog();
         await settle(60);

         final remainingHistory = await inMemoryDb.mealHistoryDao.getAllHistory();
         expect(remainingHistory.length, equals(1));
+        expect(remainingHistory.first.id, equals(h1),
+            reason: 'With id DESC secondary ordering, oldest entry h1 remains intact and newest entry h2 is deleted');

-        // BUG DEMONSTRATION: remaining entry is h2, meaning h1 (the OLDEST entry) was deleted!
         final deletedId = remainingHistory.first.id == h1 ? h2 : h1;
-        expect(deletedId, equals(h1),
-            reason: 'CRITICAL FLAW: unscoped undo deleted oldest log h1 instead of newest log h2 because SQLite ORDER BY cookedAt DESC resolves ties as id ASC');
+        expect(deletedId, equals(h2),
+            reason: 'Unscoped undo must delete newest entry h2 even with identical timestamps');
       });
```

---

### 3.3 Supporting Implementation Diff: `lib/core/database/daos/meal_history_dao.dart`

To ensure Test 3.1b passes when the Worker runs the test suite:

```diff
--- a/lib/core/database/daos/meal_history_dao.dart
+++ b/lib/core/database/daos/meal_history_dao.dart
@@ -17,10 +17,13 @@ class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDa
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
     return query.watch();
   }
 
@@ -28,10 +31,13 @@ class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDa
   /// Reactive stream joining history with meals (meal may be null if deleted)
   Stream<List<MealHistoryWithMeal>> watchHistoryWithMeal() {
     final query = select(mealHistory).join([
       leftOuterJoin(meals, meals.id.equalsExp(mealHistory.mealId)),
-    ])..orderBy([OrderingTerm.desc(mealHistory.cookedAt)]);
+    ])..orderBy([
+      OrderingTerm.desc(mealHistory.cookedAt),
+      OrderingTerm.desc(mealHistory.id),
+    ]);
 
     return query.watch().map((rows) {
       return rows.map((row) {
@@ -43,10 +49,13 @@ class MealHistoryDao extends DatabaseAccessor<AppDatabase> with _$MealHistoryDa
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
 
   /// Snapshot of all history entries
   Future<List<MealHistoryData>> getAllHistory() {
-    return (select(mealHistory)..orderBy([(t) => OrderingTerm.desc(t.cookedAt)])).get();
+    return (select(mealHistory)
+      ..orderBy([
+        (t) => OrderingTerm.desc(t.cookedAt),
+        (t) => OrderingTerm.desc(t.id),
+      ])).get();
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
 
   /// Fetch history within the last [days] days
   Future<List<MealHistoryData>> getHistoryWithinDays(
     int days, {
     DateTime? referenceDate,
   }) {
     final ref = referenceDate ?? DateTime.now();
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
   Future<MealHistoryData?> getLatestCookedMeal({DateTime? beforeDate}) {
     final query = select(mealHistory);
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

## 4. Static Analysis Verification Checklist

To guarantee 0 diagnostics from `flutter analyze`:

| Check | Target | Expected Diagnostic Result |
|---|---|---|
| Unused Imports | `challenger_viewport_overflow_test.dart` | 0 unused imports |
| Deprecated API usage | `challenger_viewport_overflow_test.dart` | 0 deprecations (replaced `ProviderScope(parent:)` with `UncontrolledProviderScope`) |
| String length validation | `MealsCompanion.insert` | Length $== 120$ (passes `min: 1, max: 120` check) |
| Unused variables | `riverpod_scoped_undo_adversarial_test.dart` | 0 unused variables |
| Async/await conventions | Test 3.1b | Clean `await settle(...)` and `Future` completion |
| Workspace static analysis | Entire repository | `flutter analyze` exits with 0 issues |

---

## 5. Verification Commands for Worker

1. **Verify single test suite execution**:
   ```powershell
   flutter test test/widget/challenger_viewport_overflow_test.dart
   flutter test test/unit/riverpod_scoped_undo_adversarial_test.dart
   ```
2. **Verify static analysis**:
   ```powershell
   flutter analyze
   ```
3. **Verify full workspace test suite**:
   ```powershell
   flutter test
   ```
