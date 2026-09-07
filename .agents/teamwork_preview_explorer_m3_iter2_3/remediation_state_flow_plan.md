# Remediation Plan: State Flow & Undo Scope Hardening (Milestone 3)

**Author:** `teamwork_preview_explorer_m3_iter2_3` (State Flow & Undo Scope Remediation Explorer)  
**Parent Conversation ID:** `3efea0b8-0374-4d39-8f46-d670012fcd8a`  
**Target Milestone:** Milestone 3 Iteration 2 (Presentation Layer & Riverpod State)  
**Date:** 2026-09-07  

---

## 1. Executive Summary

During Milestone 3 Review & Adversarial Analysis, Reviewer 1 flagged **Finding 3 ([Major] Unscoped / Race-Prone `undoLastCookingLog` in `RecommendationController`)**:
- Currently, `RecommendationController.undoLastCookingLog()` deletes the single most recent cooking log in the SQLite database via `historyDao.getRecentHistory(limit: 1)`.
- When a user marks a meal as cooked or leftover in `HomeScreen`, a floating `SnackBar` is displayed offering an "Undo" ("تراجع") action.
- Because the undo action was unscoped (did not reference the specific ID of the newly logged history record), accidental double-taps or rapid interactions delete older, unrelated historical cooking records, causing permanent data loss and corrupting the cooldown engine's historical input stream.

This remediation plan provides the exact, production-grade fix strategy:
1. **Refactor `RecommendationController.undoLastCookingLog([int? historyEntryId])`**: Accept an optional `int? historyEntryId`. When provided, execute `deleteHistoryEntry(historyEntryId)`. When omitted, gracefully fall back to the most recent entry for complete backwards compatibility.
2. **Provide `undoHistoryEntry(int historyEntryId)` alias**: Ensure clean, explicit, self-documenting method invocation.
3. **Capture inserted `historyId` in `HomeScreen`**: In `_handleCookedToday` and `_handleLeftover`, capture the `id` returned by `controller.markCookedToday(meal)` / `controller.markLeftover(meal)` and pass it into the SnackBar closure.
4. **Immediate SnackBar Refresh**: Add `ScaffoldMessenger.of(context).hideCurrentSnackBar()` to immediately dismiss any stale SnackBar before showing the new action feedback.
5. **Add Comprehensive Unit Verification (`CHALLENGE-1.5`)**: Add an adversarial stress test validating that scoped undo deletes only the targeted record, leaves subsequent records intact, and protects against accidental double-tapping.

---

## 2. Forensic Code Inspection & Defect Analysis

### 2.1 The Vulnerability in `RecommendationController`
File: `lib/features/home/providers/recommendation_provider.dart:135-149`

```dart
  /// Undoes the latest cooking log entry.
  Future<void> undoLastCookingLog() async {
    state = const AsyncValue.loading();
    try {
      final historyDao = ref.read(mealHistoryDaoProvider);
      final recent = await historyDao.getRecentHistory(limit: 1);
      if (recent.isNotEmpty) {
        await historyDao.deleteHistoryEntry(recent.first.id);
      }
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }
```

#### Failure Mode Scenario:
1. User marks Meal A as cooked at 12:00 PM (`historyId: 101`). A SnackBar appears: `"بالهنا والشفا! تم تسجيل الوجبة في السجل"` with action `"تراجع"`.
2. User marks Meal B as cooked at 12:01 PM (`historyId: 102`).
3. User taps `"تراجع"` on Meal A's SnackBar.
4. `undoLastCookingLog()` queries `getRecentHistory(limit: 1)`, which returns Meal B (`id: 102`), and deletes Meal B!
5. Result: Meal A remains logged in history, while Meal B is erroneously destroyed.
6. **Double-Tap Hazard**: Even with a single meal, if the user rapidly double-taps `"تراجع"`, the first invocation deletes Meal A, and the second invocation queries `getRecentHistory(limit: 1)` and deletes whatever meal was cooked yesterday!

### 2.2 The Call Sites in `HomeScreen`
File: `lib/features/home/presentation/home_screen.dart:293-339`

```dart
  Future<void> _handleCookedToday(
    BuildContext context,
    WidgetRef ref,
    Meal meal,
  ) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    await controller.markCookedToday(meal); // Return value (Future<int>) was ignored!

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بالهنا والشفا! تم تسجيل "${meal.name}" في السجل.'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              controller.undoLastCookingLog(); // Unscoped!
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
```

Notice that `markCookedToday(meal)` and `markLeftover(meal)` already return `Future<int>` containing the SQLite inserted row ID. The ID was simply ignored and discarded.

### 2.3 Inspection of `QuickActions`
File: `lib/features/home/presentation/widgets/quick_actions.dart:1-51`

`QuickActions` is a stateless presentation widget that exposes two callbacks:
- `final VoidCallback onCookedToday;`
- `final VoidCallback onLeftover;`

It is embedded inside `MealCard`, which delegates `onCookedToday` and `onLeftover` to `HomeScreen._handleCookedToday` and `HomeScreen._handleLeftover`. `QuickActions` itself is decoupled from Drift, Riverpod controllers, and ScaffoldMessengers. No structural changes are required in `QuickActions`; its current API contract (`VoidCallback`) remains clean and correct.

---

## 3. Exact Code Edits for the Worker

### Edit 1: `lib/features/home/providers/recommendation_provider.dart`

**Target File:** `lib/features/home/providers/recommendation_provider.dart`  
**Target Range:** Lines 134–149

#### Before:
```dart
  /// Undoes the latest cooking log entry.
  Future<void> undoLastCookingLog() async {
    state = const AsyncValue.loading();
    try {
      final historyDao = ref.read(mealHistoryDaoProvider);
      final recent = await historyDao.getRecentHistory(limit: 1);
      if (recent.isNotEmpty) {
        await historyDao.deleteHistoryEntry(recent.first.id);
      }
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }
```

#### After:
```dart
  /// Undoes a cooking log entry.
  /// If [historyEntryId] is provided, deletes that exact history entry (scoped undo).
  /// If [historyEntryId] is omitted or null, falls back to deleting the most recent entry.
  Future<void> undoLastCookingLog([int? historyEntryId]) async {
    state = const AsyncValue.loading();
    try {
      final historyDao = ref.read(mealHistoryDaoProvider);
      if (historyEntryId != null) {
        await historyDao.deleteHistoryEntry(historyEntryId);
      } else {
        final recent = await historyDao.getRecentHistory(limit: 1);
        if (recent.isNotEmpty) {
          await historyDao.deleteHistoryEntry(recent.first.id);
        }
      }
      state = const AsyncValue.data(null);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      rethrow;
    }
  }

  /// Explicitly deletes a specific history log entry by ID (scoped undo alias).
  Future<void> undoHistoryEntry(int historyEntryId) =>
      undoLastCookingLog(historyEntryId);
```

---

### Edit 2: `lib/features/home/presentation/home_screen.dart`

**Target File:** `lib/features/home/presentation/home_screen.dart`  
**Target Range:** Lines 293–339

#### Before:
```dart
  Future<void> _handleCookedToday(
    BuildContext context,
    WidgetRef ref,
    Meal meal,
  ) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    await controller.markCookedToday(meal);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بالهنا والشفا! تم تسجيل "${meal.name}" في السجل.'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              controller.undoLastCookingLog();
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLeftover(
    BuildContext context,
    WidgetRef ref,
    Meal meal,
  ) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    await controller.markLeftover(meal);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل بواقي أكل "${meal.name}".'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              controller.undoLastCookingLog();
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
```

#### After:
```dart
  Future<void> _handleCookedToday(
    BuildContext context,
    WidgetRef ref,
    Meal meal,
  ) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    final historyEntryId = await controller.markCookedToday(meal);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بالهنا والشفا! تم تسجيل "${meal.name}" في السجل.'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              controller.undoLastCookingLog(historyEntryId);
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLeftover(
    BuildContext context,
    WidgetRef ref,
    Meal meal,
  ) async {
    final controller = ref.read(recommendationControllerProvider.notifier);
    final historyEntryId = await controller.markLeftover(meal);

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل بواقي أكل "${meal.name}".'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              controller.undoLastCookingLog(historyEntryId);
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
```

---

### Edit 3: New Adversarial Test in `test/unit/riverpod_adversarial_m3_stress_test.dart`

**Target File:** `test/unit/riverpod_adversarial_m3_stress_test.dart`  
**Location:** Insert after line 242 (end of `CHALLENGE-1.4`)

```dart
    test('CHALLENGE-1.5: Scoped undoLastCookingLog(historyEntryId) deletes exact entry and protects against double-tap', () async {
      final recController = container.read(recommendationControllerProvider.notifier);
      final meals = await inMemoryDb.mealsDao.getAllMeals();
      expect(meals.length, greaterThanOrEqualTo(2));

      // 1. Log meal 0 then meal 1
      final id1 = await recController.logCookedToday(meals[0]);
      final id2 = await recController.logCookedToday(meals[1]);

      await settleStreams(100);

      var history = container.read(mealHistoryProvider).value!;
      expect(history.length, equals(2));
      expect(history.map((h) => h.id), containsAll([id1, id2]));

      // 2. Perform scoped undo on the FIRST meal (id1), not the most recent one (id2)
      await recController.undoLastCookingLog(id1);
      await settleStreams(100);

      history = container.read(mealHistoryProvider).value!;
      expect(history.length, equals(1));
      expect(history.first.id, equals(id2), reason: 'id2 must remain intact when id1 is undone');
      expect(history.any((h) => h.id == id1), isFalse, reason: 'id1 must be removed');

      // 3. Simulate accidental double-tap on id1's SnackBar undo button
      await recController.undoLastCookingLog(id1);
      await settleStreams(100);

      history = container.read(mealHistoryProvider).value!;
      expect(history.length, equals(1));
      expect(history.first.id, equals(id2), reason: 'Accidental double-tap on id1 must not delete id2');

      // 4. Unscoped undo removes remaining record (backward compatibility check)
      await recController.undoLastCookingLog();
      await settleStreams(100);

      history = container.read(mealHistoryProvider).value!;
      expect(history.isEmpty, isTrue, reason: 'Unscoped undo removes remaining record');
    });
```

---

## 4. Verification Protocol

The Worker must verify this remediation by running:
1. **Adversarial Test Suite Execution:**
   ```bash
   flutter test test/unit/riverpod_adversarial_m3_stress_test.dart
   ```
   *Expected Result:* All 19 tests pass (including `CHALLENGE-1.5`) with exit code 0.

2. **Full Unit & Widget Suite Execution:**
   ```bash
   flutter test
   ```
   *Expected Result:* 100% test pass across all unit and widget tests.

3. **Static Analysis:**
   ```bash
   flutter analyze
   ```
   *Expected Result:* Zero warnings/errors related to `recommendation_provider.dart` and `home_screen.dart`.
