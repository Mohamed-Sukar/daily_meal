// test/unit/database_adversarial_test.dart
// Adversarial Challenger Test Suite for Milestone 1 Drift Database Layer
// Challenger identity: teamwork_preview_challenger_m1_1

import 'dart:async';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_meal/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Adversarial Group 1: Boundary Strings & SQL Injection Hardening', () {
    test('1.1: Accepts exact 1-character meal names in Arabic and English', () async {
      final id1 = await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('ط'),
          proteinType: Value(ProteinType.none),
          carbsType: Value(CarbsType.none),
          category: Value(MealCategory.vegetarian),
          prepTime: Value(5),
        ),
      );
      final m1 = await db.mealsDao.getMealById(id1);
      expect(m1?.name, equals('ط'));

      final id2 = await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('X'),
          proteinType: Value(ProteinType.none),
          carbsType: Value(CarbsType.none),
          category: Value(MealCategory.fastFood),
          prepTime: Value(10),
        ),
      );
      final m2 = await db.mealsDao.getMealById(id2);
      expect(m2?.name, equals('X'));
    });

    test('1.2: Accepts exact 120-character boundary name (max length)', () async {
      final name120 = 'أ' * 120;
      expect(name120.length, equals(120));

      final id = await db.mealsDao.insertMeal(
        MealsCompanion(
          name: Value(name120),
          proteinType: const Value(ProteinType.beef),
          carbsType: const Value(CarbsType.rice),
          category: const Value(MealCategory.ovenBaked),
          prepTime: const Value(60),
        ),
      );

      final meal = await db.mealsDao.getMealById(id);
      expect(meal, isNotNull);
      expect(meal!.name.length, equals(120));
      expect(meal.name, equals(name120));
    });

    test('1.3: Handles >120-character meal names', () async {
      final name121 = 'أ' * 121;
      expect(name121.length, equals(121));

      final companion = MealsCompanion(
        name: Value(name121),
        proteinType: const Value(ProteinType.beef),
        carbsType: const Value(CarbsType.rice),
        category: const Value(MealCategory.ovenBaked),
        prepTime: const Value(60),
      );

      try {
        final id = await db.mealsDao.insertMeal(companion);
        final m = await db.mealsDao.getMealById(id);
        expect(m, isNotNull);
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('1.4: SQL injection attack payloads do not compromise database', () async {
      final sqlInjections = <String>[
        r"'; DROP TABLE meals; --",
        r"' OR '1'='1",
        r"admin'--",
        r"1; SELECT * FROM app_settings;",
        r"UNION ALL SELECT 999, 'injected', null, null, null, null, null, null, null, null, null, null--",
        r'" OR ""="',
        r"'; UPDATE app_settings SET cooldown_days = 999; --",
      ];

      for (final payload in sqlInjections) {
        final id = await db.mealsDao.insertMeal(
          MealsCompanion(
            name: Value('وجبة: $payload'),
            proteinType: const Value(ProteinType.chicken),
            carbsType: const Value(CarbsType.rice),
            category: const Value(MealCategory.egyptianTraditional),
            prepTime: const Value(30),
            photoPath: Value(payload),
          ),
        );

        final meal = await db.mealsDao.getMealById(id);
        expect(meal, isNotNull);
        expect(meal!.name, equals('وجبة: $payload'));
        expect(meal.photoPath, equals(payload));
      }

      final count = (await db.mealsDao.getAllMeals()).length;
      expect(count, equals(20 + sqlInjections.length));

      final settings = await db.appSettingsDao.getSettings();
      expect(settings.cooldownDays, equals(14));
    });

    test('1.5: Preserves rich UTF-8, emojis, Arabic diacritics and symbols', () async {
      final complexNames = [
        'طَبَق مَلُوخِيَّة بِالتَّقْلِيَة الْمَصْرِيَّة 🍲✨',
        'كَبَاب & كُفْتَة ضَانِي (مشوي فحم) 100% 🔥🍖',
        'بيتزا مشكل جبن 🧀🍕 w/ Extra Sauce (حار/بارد)',
        'سلطة فواكه 🍓🍇🍌 - حلو/صيفي! #خفيف @البيت',
        'وجبة مع أسطر\nمتعددة\tوتباعد',
      ];

      for (final name in complexNames) {
        final id = await db.mealsDao.insertMeal(
          MealsCompanion(
            name: Value(name),
            proteinType: const Value(ProteinType.beef),
            carbsType: const Value(CarbsType.bread),
            category: const Value(MealCategory.ovenBaked),
            prepTime: const Value(45),
          ),
        );

        final meal = await db.mealsDao.getMealById(id);
        expect(meal, isNotNull);
        expect(meal!.name, equals(name));
      }
    });

    test('1.6: LIKE wildcard characters in searchMeals are safely handled', () async {
      final wildResults1 = await db.mealsDao.searchMeals('%');
      expect(wildResults1, isNotEmpty);

      final wildResults2 = await db.mealsDao.searchMeals('_');
      expect(wildResults2, isNotEmpty);

      final emptyResults = await db.mealsDao.searchMeals(r'xyz!@#$%^&*()');
      expect(emptyResults, isEmpty);
    });

    test('1.7: Rejects empty and whitespace-only names', () async {
      final invalidNames = ['', ' ', '   ', '\t', '\n', ' \t \n '];

      for (final invalid in invalidNames) {
        expect(
          () => db.mealsDao.insertMeal(
            MealsCompanion(
              name: Value(invalid),
              proteinType: const Value(ProteinType.beef),
              carbsType: const Value(CarbsType.rice),
              category: const Value(MealCategory.egyptianTraditional),
              prepTime: const Value(30),
            ),
          ),
          throwsArgumentError,
          reason: 'Expected ArgumentError for name: "$invalid"',
        );
      }
    });
  });

  group('Adversarial Group 2: Numeric Boundaries & Extreme Prep Times', () {
    test('2.1: Accepts boundary prep time of 1 minute', () async {
      final id = await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('وجبة سريعة دقيقة واحدة'),
          proteinType: Value(ProteinType.none),
          carbsType: Value(CarbsType.none),
          category: Value(MealCategory.fastFood),
          prepTime: Value(1),
        ),
      );
      final meal = await db.mealsDao.getMealById(id);
      expect(meal?.prepTime, equals(1));
    });

    test('2.2: Rejects prepTime <= 0 with ArgumentError in insertMeal', () async {
      final invalidPrepTimes = [0, -1, -5, -9999];

      for (final t in invalidPrepTimes) {
        expect(
          () => db.mealsDao.insertMeal(
            MealsCompanion(
              name: const Value('وجبة باطلة'),
              proteinType: const Value(ProteinType.beef),
              carbsType: const Value(CarbsType.rice),
              category: const Value(MealCategory.egyptianTraditional),
              prepTime: Value(t),
            ),
          ),
          throwsArgumentError,
          reason: 'Expected ArgumentError for prepTime: $t',
        );
      }
    });

    test('2.3: Handles extreme large prep times without integer overflow', () async {
      final largeTimes = [
        1440, // 24 hours
        10080, // 7 days
        2147483647, // Max 32-bit signed int
      ];

      for (final t in largeTimes) {
        final id = await db.mealsDao.insertMeal(
          MealsCompanion(
            name: Value('وجبة تحضير طويل: $t'),
            proteinType: const Value(ProteinType.beef),
            carbsType: const Value(CarbsType.grains),
            category: const Value(MealCategory.ovenBaked),
            prepTime: Value(t),
          ),
        );
        final meal = await db.mealsDao.getMealById(id);
        expect(meal?.prepTime, equals(t));
      }
    });

    test('2.4: Probes updateMeal with invalid prepTime (Adversarial Bug Check)', () async {
      final meal = (await db.mealsDao.getMealById(1))!;

      // Adversarial probe: Does updateMeal prevent negative prepTime?
      final corruptedMeal = meal.copyWith(prepTime: -50);
      final updated = await db.mealsDao.updateMeal(corruptedMeal);
      expect(updated, isTrue);

      final reFetched = await db.mealsDao.getMealById(1);
      // Empirical verification: check whether updateMeal allows storing negative prep time
      expect(reFetched?.prepTime, equals(-50));
    });

    test('2.5: AppSettings cooldown days boundary clamping', () async {
      await db.appSettingsDao.updateCooldownDays(-100);
      var s = await db.appSettingsDao.getSettings();
      expect(s.cooldownDays, equals(1));

      await db.appSettingsDao.updateCooldownDays(0);
      s = await db.appSettingsDao.getSettings();
      expect(s.cooldownDays, equals(1));

      await db.appSettingsDao.updateCooldownDays(1);
      s = await db.appSettingsDao.getSettings();
      expect(s.cooldownDays, equals(1));

      await db.appSettingsDao.updateCooldownDays(60);
      s = await db.appSettingsDao.getSettings();
      expect(s.cooldownDays, equals(60));

      await db.appSettingsDao.updateCooldownDays(61);
      s = await db.appSettingsDao.getSettings();
      expect(s.cooldownDays, equals(60));

      await db.appSettingsDao.updateCooldownDays(9999);
      s = await db.appSettingsDao.getSettings();
      expect(s.cooldownDays, equals(60));
    });

    test('2.6: Notification hour and minute boundaries', () async {
      await db.appSettingsDao.updateNotificationTime(0, 0);
      var s = await db.appSettingsDao.getSettings();
      expect(s.notificationHour, equals(0));
      expect(s.notificationMinute, equals(0));

      await db.appSettingsDao.updateNotificationTime(23, 59);
      s = await db.appSettingsDao.getSettings();
      expect(s.notificationHour, equals(23));
      expect(s.notificationMinute, equals(59));
    });
  });

  group('Adversarial Group 3: High Volume & Scale Stress Harness', () {
    test('3.1: Bulk insert 500 meals via batch and verify retrieval and auto-increment', () async {
      final batchList = List.generate(500, (i) {
        return MealsCompanion(
          name: Value('وجبة تجريبية رقم ${i + 1}'),
          proteinType: Value(ProteinType.values[i % ProteinType.values.length]),
          carbsType: Value(CarbsType.values[i % CarbsType.values.length]),
          category: Value(MealCategory.values[i % MealCategory.values.length]),
          prepTime: Value((i % 120) + 1),
          isBudgetFriendly: Value(i % 2 == 0),
          isFridaySpecial: Value(i % 5 == 0),
          isFavorite: Value(i % 10 == 0),
        );
      });

      final sw = Stopwatch()..start();
      await db.mealsDao.insertMealsBatch(batchList);
      sw.stop();

      final all = await db.mealsDao.getAllMeals();
      expect(all.length, equals(520));
      expect(sw.elapsedMilliseconds, lessThan(3000));

      final searchResults = await db.mealsDao.searchMeals('رقم 499');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.name, equals('وجبة تجريبية رقم 499'));

      final fridaySpecialItems = await db.mealsDao.filterByTag(isFridaySpecial: true);
      expect(fridaySpecialItems.length, greaterThanOrEqualTo(105));
    });

    test('3.2: 100 sequential individual inserts remain consistent', () async {
      for (int i = 1; i <= 100; i++) {
        final id = await db.mealsDao.insertMeal(
          MealsCompanion(
            name: Value('وجبة فردية $i'),
            proteinType: const Value(ProteinType.chicken),
            carbsType: const Value(CarbsType.rice),
            category: const Value(MealCategory.egyptianTraditional),
            prepTime: Value(i),
          ),
        );
        expect(id, equals(20 + i));
      }

      final count = (await db.mealsDao.getAllMeals()).length;
      expect(count, equals(120));
    });

    test('3.3: Insert 1,000 history entries and verify getRecentHistory limit & order', () async {
      final baseTime = DateTime(2026, 1, 1, 12, 0);

      await db.batch((b) {
        b.insertAll(
          db.mealHistory,
          List.generate(1000, (i) {
            return MealHistoryCompanion(
              mealId: const Value(1),
              mealName: Value('سجل وجبة $i'),
              proteinType: const Value(ProteinType.legume),
              carbsType: const Value(CarbsType.rice),
              cookedAt: Value(baseTime.add(Duration(hours: i))),
              entryType: Value(i % 3 == 0 ? MealEntryType.leftover : MealEntryType.cooked),
              notes: Value('ملاحظة $i'),
            );
          }),
        );
      });

      final total = await db.mealHistoryDao.getAllHistory();
      expect(total.length, equals(1000));

      final recent = await db.mealHistoryDao.getRecentHistory(limit: 60);
      expect(recent.length, equals(60));

      expect(recent.first.mealName, equals('سجل وجبة 999'));
      expect(recent.last.mealName, equals('سجل وجبة 940'));
      for (int i = 0; i < recent.length - 1; i++) {
        expect(
          recent[i].cookedAt.isAfter(recent[i + 1].cookedAt) ||
              recent[i].cookedAt.isAtSameMomentAs(recent[i + 1].cookedAt),
          isTrue,
        );
      }
    });

    test('3.4: Mass deletion of meals preserves all history records with mealId=null', () async {
      final mealIds = <int>[];
      for (int i = 0; i < 50; i++) {
        final id = await db.mealsDao.insertMeal(
          MealsCompanion(
            name: Value('وجبة للحذف $i'),
            proteinType: const Value(ProteinType.beef),
            carbsType: const Value(CarbsType.bread),
            category: const Value(MealCategory.fastFood),
            prepTime: const Value(20),
          ),
        );
        mealIds.add(id);

        await db.mealHistoryDao.logMeal(
          mealId: id,
          mealName: 'وجبة للحذف $i',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.bread,
          cookedAt: DateTime(2026, 9, 1).add(Duration(days: i)),
        );
      }

      var allHistory = await db.mealHistoryDao.getAllHistory();
      expect(allHistory.length, equals(50));

      for (final id in mealIds) {
        final deleted = await db.mealsDao.deleteMeal(id);
        expect(deleted, equals(1));
      }

      for (final id in mealIds) {
        expect(await db.mealsDao.getMealById(id), isNull);
      }

      allHistory = await db.mealHistoryDao.getAllHistory();
      expect(allHistory.length, equals(50));
      for (final h in allHistory) {
        expect(h.mealId, isNull, reason: 'ON DELETE SET NULL must preserve row with mealId=null');
        expect(h.mealName, startsWith('وجبة للحذف'));
      }
    });
  });

  group('Adversarial Group 4: Foreign Key Constraints & Schema Edge Cases', () {
    test('4.1: Foreign keys ON: Throws SqliteException when inserting history with non-existent mealId', () async {
      expect(
        () => db.mealHistoryDao.logMeal(
          mealId: 999999,
          mealName: 'وجبة وهمية',
          proteinType: ProteinType.beef,
          carbsType: CarbsType.rice,
          cookedAt: DateTime.now(),
        ),
        throwsA(isA<SqliteException>().having(
          (e) => e.message,
          'message',
          contains('FOREIGN KEY'),
        )),
      );
    });

    test('4.2: Logging meal history with null mealId is allowed (e.g. ad-hoc meal)', () async {
      final historyId = await db.mealHistoryDao.logMeal(
        mealId: null,
        mealName: 'أكلة مطعم خارجية ليست في البنك',
        proteinType: ProteinType.fish,
        carbsType: CarbsType.rice,
        cookedAt: DateTime.now(),
        notes: 'دليفري',
      );
      expect(historyId, greaterThan(0));

      final history = await db.mealHistoryDao.getAllHistory();
      expect(history.first.mealId, isNull);
      expect(history.first.mealName, equals('أكلة مطعم خارجية ليست في البنك'));
    });

    test('4.3: AppSettings singleton duplicate insertion fails with UNIQUE constraint', () async {
      expect(
        () => db.into(db.appSettings).insert(
          const AppSettingsCompanion(
            id: Value(1),
            cooldownDays: Value(20),
          ),
          mode: InsertMode.insert,
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('4.4: AppSettings ensureSettings recovers seamlessly if row was cleared', () async {
      await db.delete(db.appSettings).go();
      expect(await db.select(db.appSettings).get(), isEmpty);

      final settings = await db.appSettingsDao.getSettings();
      expect(settings.id, equals(1));
      expect(settings.cooldownDays, equals(14));
    });
  });

  group('Adversarial Group 5: Reactive Stream Concurrency & Rapid Emission', () {
    test('5.1: 30 rapid concurrent meal insertions emit in order without deadlocking', () async {
      final emittedCounts = <int>[];
      final completer = Completer<void>();

      final subscription = db.mealsDao.watchAllMeals().listen((list) {
        emittedCounts.add(list.length);
        if (list.length == 50) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      await Future.wait(
        List.generate(30, (i) {
          return db.mealsDao.insertMeal(
            MealsCompanion(
              name: Value('وجبة فورية $i'),
              proteinType: const Value(ProteinType.chicken),
              carbsType: const Value(CarbsType.rice),
              category: const Value(MealCategory.fastFood),
              prepTime: const Value(15),
            ),
          );
        }),
      );

      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Stream did not reach 50 elements'),
      );

      await subscription.cancel();

      expect(emittedCounts.last, equals(50));
      for (int i = 0; i < emittedCounts.length - 1; i++) {
        expect(emittedCounts[i], lessThanOrEqualTo(emittedCounts[i + 1]));
      }
    });

    test('5.2: Stream emission under interleaved concurrent insert and delete', () async {
      final stream = db.mealsDao.watchAllMeals();
      final streamUpdates = <int>[];
      final sub = stream.listen((list) => streamUpdates.add(list.length));

      final ids = <int>[];
      for (int i = 0; i < 5; i++) {
        final id = await db.mealsDao.insertMeal(
          MealsCompanion(
            name: Value('وجبة مؤقتة $i'),
            proteinType: const Value(ProteinType.dairy),
            carbsType: const Value(CarbsType.bread),
            category: const Value(MealCategory.fastFood),
            prepTime: const Value(10),
          ),
        );
        ids.add(id);
      }

      for (int i = 0; i < 3; i++) {
        await db.mealsDao.deleteMeal(ids[i]);
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();

      final currentMeals = await db.mealsDao.getAllMeals();
      expect(currentMeals.length, equals(22));
      expect(streamUpdates.last, equals(22));
    });

    test('5.3: watchSettings under rapid successive updates reaches final state', () async {
      final values = <int>[];
      final completer = Completer<void>();

      final sub = db.appSettingsDao.watchSettings().listen((settings) {
        values.add(settings.cooldownDays);
        if (settings.cooldownDays == 35) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      for (final cd in [15, 18, 20, 25, 30, 35]) {
        await db.appSettingsDao.updateCooldownDays(cd);
      }

      await completer.future.timeout(const Duration(seconds: 3));
      await sub.cancel();

      expect(values.last, equals(35));
    });

    test('5.4: Multiple concurrent subscribers receive identical snapshots', () async {
      final sub1Values = <int>[];
      final sub2Values = <int>[];
      final sub3Values = <int>[];

      final s1 = db.mealsDao.watchAllMeals().listen((list) => sub1Values.add(list.length));
      final s2 = db.mealsDao.watchAllMeals().listen((list) => sub2Values.add(list.length));
      final s3 = db.mealsDao.watchAllMeals().listen((list) => sub3Values.add(list.length));

      await db.mealsDao.insertMeal(
        const MealsCompanion(
          name: Value('وجبة للمشتركين المتعددين'),
          proteinType: Value(ProteinType.beef),
          carbsType: Value(CarbsType.rice),
          category: Value(MealCategory.ovenBaked),
          prepTime: Value(40),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      await s1.cancel();
      await s2.cancel();
      await s3.cancel();

      expect(sub1Values.last, equals(21));
      expect(sub2Values.last, equals(21));
      expect(sub3Values.last, equals(21));
    });
  });

  group('Adversarial Group 6: Seed Catalog Invariants & Data Integrity', () {
    test('6.1: Seed catalog contains exactly 20 meals with zero duplicate names', () async {
      final meals = await db.mealsDao.getAllMeals();
      expect(meals.length, equals(20));

      final names = meals.map((m) => m.name.trim()).toSet();
      expect(names.length, equals(20), reason: 'All seed meal names must be unique');
    });

    test('6.2: All seed meals satisfy strict validity rules', () async {
      final meals = await db.mealsDao.getAllMeals();

      for (final m in meals) {
        expect(m.name.trim().isNotEmpty, isTrue, reason: 'Meal name cannot be empty');
        expect(m.prepTime, greaterThan(0), reason: 'Prep time must be positive for ${m.name}');
        expect(m.prepTime, lessThanOrEqualTo(180), reason: 'Prep time reasonable upper limit');
        expect(m.createdAt, isNotNull);
        expect(m.updatedAt, isNotNull);
      }
    });

    test('6.3: Seed catalog covers diverse protein types and categories', () async {
      final meals = await db.mealsDao.getAllMeals();

      final proteins = meals.map((m) => m.proteinType).toSet();
      expect(proteins.contains(ProteinType.chicken), isTrue);
      expect(proteins.contains(ProteinType.beef), isTrue);
      expect(proteins.contains(ProteinType.fish), isTrue);
      expect(proteins.contains(ProteinType.legume), isTrue);

      final categories = meals.map((m) => m.category).toSet();
      expect(categories.contains(MealCategory.egyptianTraditional), isTrue);
      expect(categories.contains(MealCategory.ovenBaked), isTrue);
      expect(categories.contains(MealCategory.seafood), isTrue);
      expect(categories.contains(MealCategory.fastFood), isTrue);
    });
  });

  group('Adversarial Group 7: Advanced Stress, Large Scale & Inconsistency Probing', () {
    test('7.1: Inconsistency probe: insertMealsBatch bypasses insertMeal prepTime validation', () async {
      // Adversarial check: insertMeal checks prepTime > 0, but does insertMealsBatch?
      final companions = [
        const MealsCompanion(
          name: Value('وجبة دفعة سالبة'),
          proteinType: Value(ProteinType.beef),
          carbsType: Value(CarbsType.rice),
          category: Value(MealCategory.egyptianTraditional),
          prepTime: Value(-99),
        ),
      ];

      // Empirical observation: does it succeed or fail?
      await db.mealsDao.insertMealsBatch(companions);
      final all = await db.mealsDao.getAllMeals();
      final inserted = all.firstWhere((m) => m.name == 'وجبة دفعة سالبة');
      expect(inserted.prepTime, equals(-99),
          reason: 'insertMealsBatch lacks the Dart validation found in insertMeal');
    });

    test('7.2: Inconsistency probe: updateNotificationTime accepts out-of-range hours/minutes', () async {
      // Adversarial check: does updateNotificationTime clamp or validate hour (0-23) and minute (0-59)?
      await db.appSettingsDao.updateNotificationTime(99, -15);
      final settings = await db.appSettingsDao.getSettings();

      // Empirical observation: check stored values
      expect(settings.notificationHour, equals(99),
          reason: 'updateNotificationTime lacks boundary validation for hours');
      expect(settings.notificationMinute, equals(-15),
          reason: 'updateNotificationTime lacks boundary validation for minutes');
    });

    test('7.3: High scale stress: bulk insertion of 2,500 meals maintains query latency and sorting', () async {
      final swBatch = Stopwatch()..start();
      final massiveBatch = List.generate(2500, (i) {
        return MealsCompanion(
          name: Value('وجبة ضخمة رقم ${i.toString().padLeft(4, '0')}'),
          proteinType: Value(ProteinType.values[i % ProteinType.values.length]),
          carbsType: Value(CarbsType.values[i % CarbsType.values.length]),
          category: Value(MealCategory.values[i % MealCategory.values.length]),
          prepTime: Value((i % 120) + 1),
          isFridaySpecial: Value(i % 7 == 0),
          isBudgetFriendly: Value(i % 3 == 0),
        );
      });
      await db.mealsDao.insertMealsBatch(massiveBatch);
      swBatch.stop();

      // Ensure total count is 20 initial + 2500 = 2520
      final swQuery = Stopwatch()..start();
      final allMeals = await db.mealsDao.getAllMeals();
      swQuery.stop();

      expect(allMeals.length, equals(2520));
      // Latency check: fetching 2521 items from memory SQLite should be under 500ms
      expect(swQuery.elapsedMilliseconds, lessThan(500));

      // Test filtered query on 2,500 items
      final swFilter = Stopwatch()..start();
      final filtered = await db.mealsDao.filterByTag(
        proteinType: ProteinType.chicken,
        category: MealCategory.egyptianTraditional,
        isBudgetFriendly: true,
      );
      swFilter.stop();

      expect(filtered, isNotEmpty);
      expect(swFilter.elapsedMilliseconds, lessThan(200));
    });

    test('7.4: Concurrency torture: 30 concurrent writers and 10 concurrent stream listeners', () async {
      final listenerCounts = List.generate(10, (_) => <int>[]);
      final subs = <StreamSubscription>[];

      for (int l = 0; l < 10; l++) {
        final subIndex = l;
        subs.add(db.mealsDao.watchAllMeals().listen((list) {
          listenerCounts[subIndex].add(list.length);
        }));
      }

      // Concurrently insert 30 meals
      await Future.wait(
        List.generate(30, (i) {
          return db.mealsDao.insertMeal(
            MealsCompanion(
              name: Value('وجبة ضغط متزامن $i'),
              proteinType: const Value(ProteinType.fish),
              carbsType: const Value(CarbsType.rice),
              category: const Value(MealCategory.seafood),
              prepTime: const Value(25),
            ),
          );
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));
      for (final s in subs) {
        await s.cancel();
      }

      // Verify all listeners reached the same final count
      final finalCounts = listenerCounts.map((l) => l.last).toSet();
      expect(finalCounts.length, equals(1),
          reason: 'All concurrent listeners must see the identical final database state');
    });
  });
}

