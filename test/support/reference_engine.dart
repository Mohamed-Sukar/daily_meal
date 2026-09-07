// test/support/reference_engine.dart
// Authoritative Reference Recommendation Engine adhering to architecture_report.md § 3

import 'dart:math';
import 'contracts.dart';

class RecommendationEngine {
  const RecommendationEngine();

  RecommendationResult compute({
    required List<Meal> meals,
    required List<MealHistoryData> history,
    required AppSetting settings,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final normalizedToday = DateTime(now.year, now.month, now.day);

    if (meals.isEmpty) {
      return RecommendationResult(
        recommendations: const [],
        relaxationLevel: 5,
        relaxationReason: 'قاعدة بيانات الوجبات فارغة، يرجى إضافة وجبات.',
        computedDate: normalizedToday,
      );
    }

    // Identify last cooked meal (within 1 day) for context
    MealHistoryData? lastCooked;
    final sortedHistory = List<MealHistoryData>.from(history)
      ..sort((a, b) {
        final dateCmp = b.cookedDate.compareTo(a.cookedDate);
        if (dateCmp != 0) return dateCmp;
        return b.createdAt.compareTo(a.createdAt);
      });

    for (final entry in sortedHistory) {
      final daysDiff = _daysBetween(entry.cookedDate, normalizedToday);
      if (daysDiff <= 1) {
        lastCooked = entry;
        break;
      }
    }

    final lastProtein = lastCooked?.proteinType;
    final lastCarbs = lastCooked?.carbsType;

    // Execute 5-Level Graceful Degradation
    for (int level = 0; level <= 5; level++) {
      final candidates = _filterCandidates(
        meals: meals,
        history: sortedHistory,
        settings: settings,
        today: normalizedToday,
        lastProtein: lastProtein,
        lastCarbs: lastCarbs,
        level: level,
      );

      final ranked = _rankAndSelectDiversity(
        candidates: candidates,
        today: normalizedToday,
        cooldownDays: settings.cooldownDays,
      );

      if (ranked.length >= 3 || level == 5 || meals.length < 3) {
        return RecommendationResult(
          recommendations: ranked.take(min(3, meals.length)).toList(),
          relaxationLevel: level,
          relaxationReason: _relaxationReason(level),
          computedDate: normalizedToday,
        );
      }
    }

    return RecommendationResult(
      recommendations: meals.take(min(3, meals.length)).toList(),
      relaxationLevel: 5,
      relaxationReason: _relaxationReason(5),
      computedDate: normalizedToday,
    );
  }

  List<Meal> _filterCandidates({
    required List<Meal> meals,
    required List<MealHistoryData> history,
    required AppSetting settings,
    required DateTime today,
    required ProteinType? lastProtein,
    required CarbsType? lastCarbs,
    required int level,
  }) {
    final effectiveCooldown = _calculateEffectiveCooldown(settings.cooldownDays, level);

    return meals.where((meal) {
      // Find the last cooked date for this meal
      DateTime? lastCookedDate;
      for (final h in history) {
        if (h.mealId == meal.id) {
          final hDate = DateTime(h.cookedDate.year, h.cookedDate.month, h.cookedDate.day);
          if (lastCookedDate == null || hDate.isAfter(lastCookedDate)) {
            lastCookedDate = hDate;
          }
        }
      }

      // Check Cooldown
      if (lastCookedDate != null) {
        final deltaDays = _daysBetween(lastCookedDate, today);

        if (level == 4) {
          // Emergency: Only exclude meals cooked today
          if (deltaDays == 0) return false;
        } else if (level < 5) {
          if (deltaDays <= effectiveCooldown) return false;
        }
      }

      // Check Carbs Repeat
      if (level == 0 && settings.preventRepeatCarbs && lastCarbs != null && lastCarbs != CarbsType.none) {
        if (meal.carbsType == lastCarbs) return false;
      }

      // Check Protein Repeat
      if (level <= 2 && settings.preventRepeatProtein && lastProtein != null && lastProtein != ProteinType.none) {
        if (meal.proteinType == lastProtein) return false;
      }

      return true;
    }).toList();
  }

  int _calculateEffectiveCooldown(int configDays, int level) {
    switch (level) {
      case 0:
      case 1:
        return configDays;
      case 2:
        return min(configDays, max(1, configDays ~/ 2));
      case 3:
        return min(configDays, max(1, configDays ~/ 4));
      case 4:
      case 5:
      default:
        return 1;
    }
  }

  double calculateMealScore({
    required Meal meal,
    required List<MealHistoryData> history,
    required DateTime today,
    required int cooldownDays,
  }) {
    DateTime? lastCookedDate;
    for (final h in history) {
      if (h.mealId == meal.id) {
        final hDate = DateTime(h.cookedDate.year, h.cookedDate.month, h.cookedDate.day);
        if (lastCookedDate == null || hDate.isAfter(lastCookedDate)) {
          lastCookedDate = hDate;
        }
      }
    }

    // 1. Recency Component
    double sRecency;
    if (lastCookedDate == null) {
      sRecency = 25.0; // Rewards untried meals
    } else {
      final deltaDays = _daysBetween(lastCookedDate, today);
      sRecency = min(20.0, (deltaDays - cooldownDays) / 2.0);
    }

    // 2. Friday Special Component
    double sFriday = 0.0;
    final isFriday = today.weekday == DateTime.friday;
    if (isFriday) {
      sFriday = meal.isFridaySpecial ? 15.0 : 0.0;
    } else {
      sFriday = meal.isFridaySpecial ? -5.0 : 0.0;
    }

    // 3. Favorite Component
    final sFavorite = meal.isFavorite ? 5.0 : 0.0;

    // 4. Budget Component
    final sBudget = meal.isBudgetFriendly ? 2.0 : 0.0;

    // 5. Deterministic Daily Jitter
    final jitter = ((today.day * 17 + meal.id * 31) % 100) / 25.0;

    return sRecency + sFriday + sFavorite + sBudget + jitter;
  }

  List<Meal> _rankAndSelectDiversity({
    required List<Meal> candidates,
    required DateTime today,
    required int cooldownDays,
  }) {
    if (candidates.isEmpty) return const [];

    // Sort descending by score
    final scored = candidates.map((m) {
      return MapEntry(
        m,
        calculateMealScore(
          meal: m,
          history: const [],
          today: today,
          cooldownDays: cooldownDays,
        ),
      );
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selected = <Meal>[];
    final remaining = scored.map((e) => e.key).toList();

    // 1. Select Card 1: Top scoring meal
    selected.add(remaining.removeAt(0));

    // 2. Select Card 2: Highest scoring candidate with distinct protein
    if (remaining.isNotEmpty) {
      final card2Index = remaining.indexWhere((m) => m.proteinType != selected[0].proteinType);
      if (card2Index != -1) {
        selected.add(remaining.removeAt(card2Index));
      } else {
        selected.add(remaining.removeAt(0));
      }
    }

    // 3. Select Card 3: Highest scoring candidate with distinct protein from both
    if (remaining.isNotEmpty) {
      final existingProteins = selected.map((m) => m.proteinType).toSet();
      var card3Index = remaining.indexWhere((m) => !existingProteins.contains(m.proteinType));

      if (card3Index == -1) {
        // Fallback: try different carbs
        final existingCarbs = selected.map((m) => m.carbsType).toSet();
        card3Index = remaining.indexWhere((m) => !existingCarbs.contains(m.carbsType));
      }

      if (card3Index != -1) {
        selected.add(remaining.removeAt(card3Index));
      } else {
        selected.add(remaining.removeAt(0));
      }
    }

    return selected;
  }

  int _daysBetween(DateTime from, DateTime to) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    return t.difference(f).inDays;
  }

  String _relaxationReason(int level) {
    switch (level) {
      case 0:
        return 'اقتراحات مثالية مطابقة لجميع شروط التنوع الغذائي وفترة الاستبعاد.';
      case 1:
        return 'تم السماح بتكرار صنف النشويات لتوفير اقتراحات كافية.';
      case 2:
        return 'تم تقليص فترة الاستبعاد إلى النصف لتوفير اقتراحات كافية.';
      case 3:
        return 'تم تخفيف شرط البروتين وفترة الاستبعاد لتوفير اقتراحات متنوعة.';
      case 4:
        return 'وضع الطوارئ: استبعاد وجبات اليوم فقط لتوفير اقتراحات.';
      case 5:
      default:
        return 'تم عرض جميع الوجبات المتاحة لعدم توفر خيارات أخرى.';
    }
  }
}
