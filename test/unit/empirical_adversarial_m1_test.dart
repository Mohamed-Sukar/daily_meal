import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_meal/core/database/app_database.dart';
import '../support/contracts.dart' as contracts;
import '../support/reference_engine.dart' as ref_engine;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Adversarial Suite 1: SQLite Foreign Key Enforcement & PRAGMA Verification', () {
    test('PRAGMA foreign_keys is strictly enabled on SQLite connection', () async {
      final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
      final fkEnabled = result.data['foreign_keys'] as int;
      expect(fkEnabled, equals(1), reason: 'PRAGMA foreign_keys must be ON (1)');
    });

    test('Inserting MealHistory referencing non-existent mealId is rejected by SQLite', () async {
      // Meal ID 99999 does not exist in meals table
      expect(
        () async {
          await db.into(db.mealHistory).insert(
            MealHistoryCompanion.insert(
              mealId: const Value(99999),
              mealName: 'وجبة وهمية غير موجودة',
              proteinType: ProteinType.beef,
              carbsType: CarbsType.rice,
              cookedAt: DateTime.now(),
            ),
          );
        },
        throwsA(isA<SqliteException>().having(
          (e) => e.message,
          'message',
          contains('FOREIGN KEY'),
        )),
        reason: 'SQLite must enforce foreign key constraint and reject non-existent parent',
      );
    });

    test('Updating MealHistory mealId to non-existent mealId is rejected by SQLite', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      final historyId = await db.mealHistoryDao.logMealFromMeal(meal);

      expect(
        () async {
          await (db.update(db.mealHistory)..where((t) => t.id.equals(historyId))).write(
            const MealHistoryCompanion(
              mealId: Value(88888),
            ),
          );
        },
        throwsA(isA<SqliteException>().having(
          (e) => e.message,
          'message',
          contains('FOREIGN KEY'),
        )),
        reason: 'SQLite must reject updating foreign key to invalid reference',
      );
    });
  });

  group('Adversarial Suite 2: Cascade KeyAction.setNull & Snapshot Preservation', () {
    test('Deleting meal sets mealId to NULL across multiple history entries without data loss', () async {
      final meal = (await db.mealsDao.getMealById(3))!; // كباب حلة
      final baseDate = DateTime(2026, 9, 1);

      // Log 10 separate historical entries for this meal
      final entryIds = <int>[];
      for (int i = 0; i < 10; i++) {
        final id = await db.mealHistoryDao.logMeal(
          mealId: meal.id,
          mealName: meal.name,
          proteinType: meal.proteinType,
          carbsType: meal.carbsType,
          cookedAt: baseDate.add(Duration(days: i)),
          entryType: i % 2 == 0 ? MealEntryType.cooked : MealEntryType.leftover,
          notes: 'ملاحظة طبخة رقم $i',
        );
        entryIds.add(id);
      }

      // Verify all 10 entries reference meal.id
      var historyRows = await (db.select(db.mealHistory)..where((t) => t.id.isIn(entryIds))).get();
      expect(historyRows.length, equals(10));
      for (final row in historyRows) {
        expect(row.mealId, equals(meal.id));
      }

      // Delete the meal from vault
      final deletedCount = await db.mealsDao.deleteMeal(meal.id);
      expect(deletedCount, equals(1));
      expect(await db.mealsDao.getMealById(meal.id), isNull);

      // Verify all 10 history rows STILL EXIST with mealId == NULL and intact snapshot
      historyRows = await (db.select(db.mealHistory)..where((t) => t.id.isIn(entryIds))).get();
      expect(historyRows.length, equals(10));

      for (int i = 0; i < 10; i++) {
        final row = historyRows.firstWhere((r) => r.id == entryIds[i]);
        expect(row.mealId, isNull, reason: 'mealId must cascade to NULL via KeyAction.setNull');
        expect(row.mealName, equals(meal.name), reason: 'mealName snapshot must remain intact');
        expect(row.proteinType, equals(meal.proteinType), reason: 'proteinType snapshot must remain intact');
        expect(row.carbsType, equals(meal.carbsType), reason: 'carbsType snapshot must remain intact');
        expect(row.cookedAt, equals(baseDate.add(Duration(days: i))));
        expect(row.entryType, equals(i % 2 == 0 ? MealEntryType.cooked : MealEntryType.leftover));
        expect(row.notes, equals('ملاحظة طبخة رقم $i'));
      }
    });

    test('Vault meal mutation does NOT overwrite historical snapshot; subsequent deletion preserves snapshot', () async {
      // 1. Create original meal
      final originalId = await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('طاجن بامية باللحمة الضاني'),
          proteinType: Value(ProteinType.beef),
          carbsType: Value(CarbsType.rice),
          category: Value(MealCategory.ovenBaked),
          prepTime: Value(60),
        ),
      );

      final originalMeal = (await db.mealsDao.getMealById(originalId))!;

      // 2. Log in history
      final historyId = await db.mealHistoryDao.logMealFromMeal(
        originalMeal,
        cookedAt: DateTime(2026, 9, 3),
        notes: 'طعم أصيل وممتاز',
      );

      // 3. Mutate the meal completely in vault (e.g. user renames and changes recipe)
      await db.mealsDao.updateMeal(
        originalMeal.copyWith(
          name: 'سمك قاروص مشوي بالردة',
          proteinType: ProteinType.fish,
          carbsType: CarbsType.bread,
          category: MealCategory.seafood,
          prepTime: 35,
        ),
      );

      // 4. Verify historical entry is IMMUTABLE and retains original snapshot
      var histEntry = (await (db.select(db.mealHistory)..where((t) => t.id.equals(historyId))).getSingle());
      expect(histEntry.mealId, equals(originalId));
      expect(histEntry.mealName, equals('طاجن بامية باللحمة الضاني'));
      expect(histEntry.proteinType, equals(ProteinType.beef));
      expect(histEntry.carbsType, equals(CarbsType.rice));

      // 5. Delete the meal
      await db.mealsDao.deleteMeal(originalId);
      expect(await db.mealsDao.getMealById(originalId), isNull);

      // 6. Verify historical entry STILL preserves original snapshot with null mealId
      histEntry = (await (db.select(db.mealHistory)..where((t) => t.id.equals(historyId))).getSingle());
      expect(histEntry.mealId, isNull);
      expect(histEntry.mealName, equals('طاجن بامية باللحمة الضاني'));
      expect(histEntry.proteinType, equals(ProteinType.beef));
      expect(histEntry.carbsType, equals(CarbsType.rice));
      expect(histEntry.notes, equals('طعم أصيل وممتاز'));
    });

    test('watchHistoryWithMeal stream emits gracefully without throwing when meal is deleted', () async {
      final meal = (await db.mealsDao.getMealById(1))!;
      await db.mealHistoryDao.logMealFromMeal(meal, cookedAt: DateTime(2026, 9, 5));

      final stream = db.mealHistoryDao.watchHistoryWithMeal();

      // Expect two emissions: first with meal populated, second after meal deletion with meal == null
      final historyStates = <List<MealHistoryWithMeal>>[];
      final sub = stream.listen((data) {
        historyStates.add(data);
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(historyStates.isNotEmpty, isTrue);
      expect(historyStates.last.first.meal, isNotNull);
      expect(historyStates.last.first.meal!.name, equals(meal.name));

      // Delete meal
      await db.mealsDao.deleteMeal(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(historyStates.length, greaterThanOrEqualTo(2));
      final latest = historyStates.last.first;
      expect(latest.history.mealId, isNull);
      expect(latest.meal, isNull, reason: 'Joined meal must be null when meal is deleted');
      expect(latest.history.mealName, contains('كشري'));

      await sub.cancel();
    });
  });

  group('Adversarial Suite 3: High-Stress Deletion & Cascade Scalability', () {
    test('Stress test: 200 meals, 1,000 history logs, mass interleaved deletions', () async {
      final random = Random(42);
      final createdMealIds = <int>[];

      // 1. Batch insert 200 custom meals
      await db.batch((b) {
        final companions = <MealsCompanion>[];
        for (int i = 1; i <= 200; i++) {
          companions.add(
            MealsCompanion.insert(
              name: 'وجبة اختبارية ضخمة #$i',
              proteinType: ProteinType.values[i % ProteinType.values.length],
              carbsType: CarbsType.values[i % CarbsType.values.length],
              category: MealCategory.values[i % MealCategory.values.length],
              prepTime: 15 + (i % 60),
            ),
          );
        }
        b.insertAll(db.meals, companions);
      });

      final allNewMeals = await (db.select(db.meals)..where((t) => t.id.isBiggerThanValue(20))).get();
      expect(allNewMeals.length, equals(200));
      for (final m in allNewMeals) {
        createdMealIds.add(m.id);
      }

      // 2. Batch insert 1,000 history entries distributed across the 200 meals
      await db.batch((b) {
        final historyCompanions = <MealHistoryCompanion>[];
        for (int i = 0; i < 1000; i++) {
          final assignedMealId = createdMealIds[i % createdMealIds.length];
          final meal = allNewMeals[i % allNewMeals.length];
          historyCompanions.add(
            MealHistoryCompanion.insert(
              mealId: Value(assignedMealId),
              mealName: meal.name,
              proteinType: meal.proteinType,
              carbsType: meal.carbsType,
              cookedAt: DateTime(2026, 1, 1).add(Duration(hours: i * 6)),
              entryType: Value(i % 3 == 0 ? MealEntryType.leftover : MealEntryType.cooked),
              notes: Value('سجل ضغط رقم $i'),
            ),
          );
        }
        b.insertAll(db.mealHistory, historyCompanions);
      });

      final initialHistoryCount = (await db.mealHistoryDao.getAllHistory()).length;
      expect(initialHistoryCount, equals(1000));

      // 3. Randomly delete 100 meals (50%)
      createdMealIds.shuffle(random);
      final mealsToDelete = createdMealIds.take(100).toList();
      final mealsToKeep = createdMealIds.skip(100).toSet();

      // Interleave individual deletes, transaction deletes, and batch queries
      for (int i = 0; i < mealsToDelete.length; i++) {
        if (i % 10 == 0) {
          // Transactional delete
          await db.transaction(() async {
            await db.mealsDao.deleteMeal(mealsToDelete[i]);
          });
        } else {
          await db.mealsDao.deleteMeal(mealsToDelete[i]);
        }
      }

      // 4. Verify surviving meals count: 20 (seeds) + 100 = 120
      final survivingMeals = await db.mealsDao.getAllMeals();
      expect(survivingMeals.length, equals(120));

      // 5. Verify ALL 1,000 history entries still exist
      final allHistoryAfterDeletions = await db.mealHistoryDao.getAllHistory();
      expect(allHistoryAfterDeletions.length, equals(1000));

      int nullMealIdCount = 0;
      int survivingMealIdCount = 0;

      for (final h in allHistoryAfterDeletions) {
        if (h.mealId == null) {
          nullMealIdCount++;
        } else {
          survivingMealIdCount++;
          expect(mealsToKeep.contains(h.mealId), isTrue,
              reason: 'Any remaining mealId must belong to a surviving meal');
        }
        // Check snapshot integrity
        expect(h.mealName.isNotEmpty, isTrue);
        expect(h.notes, startsWith('سجل ضغط رقم'));
      }

      expect(nullMealIdCount, equals(500), reason: 'Exactly 500 history rows should now have null mealId');
      expect(survivingMealIdCount, equals(500), reason: 'Exactly 500 history rows retain their mealId');

      // 6. Test all history DAO access methods to ensure none throw with null mealId rows
      final recent = await db.mealHistoryDao.getRecentHistory(limit: 1000);
      expect(recent.length, equals(1000));

      final withinDays = await db.mealHistoryDao.getHistoryWithinDays(365 * 2);
      expect(withinDays.isNotEmpty, isTrue);

      final latest = await db.mealHistoryDao.getLatestCookedMeal();
      expect(latest, isNotNull);

      // 7. Clear all remaining meals via deleteAllMeals
      await db.mealsDao.deleteAllMeals();
      expect((await db.mealsDao.getAllMeals()).length, equals(0));

      // 8. Verify all 1,000 history logs still survive with 100% null mealId
      final finalHistory = await db.mealHistoryDao.getAllHistory();
      expect(finalHistory.length, equals(1000));
      for (final h in finalHistory) {
        expect(h.mealId, isNull);
      }
    });
  });

  group('Adversarial Suite 4: AppSettings Singleton Constraints & Repetitive/Concurrent Mutations', () {
    test('Repetitive mutations preserve single row count (id = 1)', () async {
      for (int i = 1; i <= 100; i++) {
        await db.appSettingsDao.updateCooldownDays(i % 30 + 1);
        await db.appSettingsDao.toggleNotifications(i.isEven);
        await db.appSettingsDao.updateThemeMode(
          i % 2 == 0 ? AppThemeModePreference.dark : AppThemeModePreference.light,
        );
      }

      final allRows = await db.select(db.appSettings).get();
      expect(allRows.length, equals(1), reason: 'Table must contain strictly 1 singleton row');
      expect(allRows.first.id, equals(1));
    });

    test('100 concurrent async mutations execute safely without row duplication or corruption', () async {
      final futures = <Future>[];

      for (int i = 0; i < 100; i++) {
        final index = i;
        futures.add(
          Future(() async {
            switch (index % 6) {
              case 0:
                await db.appSettingsDao.updateCooldownDays((index % 60) + 1);
                break;
              case 1:
                await db.appSettingsDao.toggleNotifications(index % 2 == 0);
                break;
              case 2:
                await db.appSettingsDao.updateThemeMode(
                  index % 2 == 0 ? AppThemeModePreference.dark : AppThemeModePreference.light,
                );
                break;
              case 3:
                await db.appSettingsDao.updateNotificationTime(index % 24, index % 60);
                break;
              case 4:
                await db.appSettingsDao.updateDietaryRules(
                  preventProtein: index % 2 == 0,
                  preventCarbs: index % 3 == 0,
                );
                break;
              case 5:
                await db.appSettingsDao.ensureSettings();
                break;
            }
          }),
        );
      }

      await Future.wait(futures);

      final allRows = await db.select(db.appSettings).get();
      expect(allRows.length, equals(1), reason: 'Concurrent mutations must never duplicate singleton row');
      expect(allRows.first.id, equals(1));

      final settings = await db.appSettingsDao.getSettings();
      expect(settings.id, equals(1));
      expect(settings.cooldownDays, inInclusiveRange(1, 60));
    });

    test('Recovery & Chaos: Row deletion followed by 50 concurrent ensureSettings/getSettings calls', () async {
      // Intentionally delete the singleton row
      final deleted = await db.delete(db.appSettings).go();
      expect(deleted, equals(1));
      expect((await db.select(db.appSettings).get()).length, equals(0));

      // Fire 50 concurrent read/ensure/write operations simultaneously
      final futures = List.generate(50, (i) {
        return Future(() async {
          if (i % 3 == 0) {
            return await db.appSettingsDao.ensureSettings();
          } else if (i % 3 == 1) {
            return await db.appSettingsDao.getSettings();
          } else {
            await db.appSettingsDao.updateCooldownDays(25);
            return await db.appSettingsDao.getSettings();
          }
        });
      });

      final results = await Future.wait(futures);
      expect(results.length, equals(50));
      for (final s in results) {
        expect(s.id, equals(1));
      }

      // Check final row count in database
      final allRows = await db.select(db.appSettings).get();
      expect(allRows.length, equals(1), reason: 'InsertMode.insertOrIgnore must prevent duplicate rows on race');
      expect(allRows.first.id, equals(1));
    });

    test('Database schema behavior on attempting direct insert with id != 1', () async {
      // Attempting to insert a row with id: 1 should fail primary key constraint
      expect(
        () async {
          await db.into(db.appSettings).insert(
            const AppSettingsCompanion(
              id: Value(1),
              cooldownDays: Value(10),
            ),
          );
        },
        throwsA(isA<SqliteException>().having(
          (e) => e.message,
          'message',
          contains('UNIQUE constraint failed'),
        )),
        reason: 'Duplicate id = 1 must be rejected by PRIMARY KEY constraint',
      );

      // What if an adversary attempts to insert id = 2?
      // Notice: In the current schema, AppSettings has PRIMARY KEY (id), but no CHECK (id = 1).
      // Let us empirically verify what SQLite does:
      final insertedId2 = await db.into(db.appSettings).insert(
        const AppSettingsCompanion(
          id: Value(2),
          cooldownDays: Value(30),
        ),
      );
      expect(insertedId2, equals(2));

      // Verify that even if an rogue row id = 2 exists in SQLite,
      // AppSettingsDao strictly queries where(id == 1), preserving application isolation:
      final daoSettings = await db.appSettingsDao.getSettings();
      expect(daoSettings.id, equals(1), reason: 'AppSettingsDao must exclusively target row 1');
      expect(daoSettings.cooldownDays, isNot(equals(30)));

      // Clean up rogue row for test hygiene
      await (db.delete(db.appSettings)..where((t) => t.id.equals(2))).go();
      expect((await db.select(db.appSettings).get()).length, equals(1));
    });
  });

  group('Adversarial Suite 5: Recommendation Engine Behavior with Orphaned History (mealId == null)', () {
    test('Orphaned history correctly informs yesterday protein/carbs repeat prevention', () {
      const engine = ref_engine.RecommendationEngine();
      final now = DateTime(2026, 9, 6);

      // Suppose meal #2 (Chicken, Rice) was cooked yesterday, but the meal was DELETED from the vault!
      // Its history entry has mealId: null, but proteinType: chicken, carbsType: rice.
      final history = [
        contracts.MealHistoryData(
          id: 101,
          mealId: null, // ORPHANED / DELETED MEAL!
          mealName: 'فراخ مشوية بالأرز (محذوفة من البنك)',
          proteinType: contracts.ProteinType.chicken,
          carbsType: contracts.CarbsType.rice,
          cookedDate: DateTime(2026, 9, 5), // Yesterday
          status: contracts.MealHistoryStatus.cookedToday,
          notes: 'وجبة تم حذفها لاحقا',
          createdAt: DateTime(2026, 9, 5, 14, 0),
        ),
      ];

      // Vault contains various meals, including chicken and beef
      final vault = [
        contracts.Meal(
          id: 10,
          name: 'شاورما دجاج',
          proteinType: contracts.ProteinType.chicken, // Repeating chicken!
          carbsType: contracts.CarbsType.bread,
          category: contracts.MealCategory.fastFood,
          prepTimeMinutes: 25,
          createdAt: DateTime(2026, 1, 1),
        ),
        contracts.Meal(
          id: 11,
          name: 'طاجن لحمة بالبصل',
          proteinType: contracts.ProteinType.beef, // Different protein
          carbsType: contracts.CarbsType.bread,
          category: contracts.MealCategory.ovenBaked,
          prepTimeMinutes: 45,
          createdAt: DateTime(2026, 1, 1),
        ),
        contracts.Meal(
          id: 12,
          name: 'صينية سمك ماكريل',
          proteinType: contracts.ProteinType.fish, // Different protein
          carbsType: contracts.CarbsType.bread,
          category: contracts.MealCategory.seafood,
          prepTimeMinutes: 40,
          createdAt: DateTime(2026, 1, 1),
        ),
        contracts.Meal(
          id: 13,
          name: 'كشري مصري',
          proteinType: contracts.ProteinType.legume, // Different protein
          carbsType: contracts.CarbsType.bread,
          category: contracts.MealCategory.egyptianTraditional,
          prepTimeMinutes: 50,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      const settings = contracts.AppSetting(
        cooldownDays: 14,
        preventRepeatProtein: true,
        preventRepeatCarbs: true,
      );

      final result = engine.compute(
        meals: vault,
        history: history,
        settings: settings,
        today: now,
      );

      // Verify: Level 0 relaxation succeeded because 3 non-chicken candidates exist (beef, fish, legume)
      expect(result.relaxationLevel, equals(0));
      expect(result.recommendations.length, equals(3));

      // Ensure chicken meal #10 was NOT recommended because yesterday's protein (chicken)
      // was preserved in the orphaned history snapshot!
      final recommendedNames = result.recommendations.map((m) => m.name).toList();
      expect(recommendedNames.contains('شاورما دجاج'), isFalse,
          reason: 'Snapshot from deleted meal must successfully prevent repeating yesterday protein');
      expect(recommendedNames, contains('طاجن لحمة بالبصل'));
      expect(recommendedNames, contains('صينية سمك ماكريل'));
      expect(recommendedNames, contains('كشري مصري'));
    });
  });
}
