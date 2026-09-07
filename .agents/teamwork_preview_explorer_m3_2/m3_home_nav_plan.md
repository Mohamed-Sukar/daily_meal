# Milestone 3 Presentation Blueprint: Navigation, Home Screen & Spin the Wheel

**Author**: Explorer for Milestone 3 (Identity: `teamwork_preview_explorer_m3_2`)  
**Scope**: GoRouter StatefulShellRoute, ScaffoldWithNavBar, Home Screen 3-Card Stack, Quick Actions, Spin the Wheel Roulette, and Riverpod State Consumer Integration.  
**Target Directory**: `E:\Mohamed\Personal_Project\daily-meal\daily_meal`

---

## 1. Executive Summary & Architecture Overview

This blueprint specifies the complete presentation architecture for the primary user experience of **"أكلة النهاردة" (Daily Meal)**. It details the navigation frame, the dynamic recommendation presentation, the instant logging quick actions, and the interactive Spin the Wheel roulette dialog.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                             MaterialApp (ar, RTL)                           │
│                                       │                                     │
│                     GoRouter (appRouterProvider)                            │
│                                       │                                     │
│              StatefulShellRoute.indexedStack (ScaffoldWithNavBar)           │
│         ┌───────────────────┬───────────────────┬─────────────────┐         │
│         │                   │                   │                 │         │
│     Tab 0 (/)          Tab 1 (/vault)      Tab 2 (/history)  Tab 3 (/settings)
│    HomeScreen          MealVaultScreen      HistoryScreen    SettingsScreen │
│         │                                                                   │
│         ├─ Header (Greeting + Spin the Wheel Action)                        │
│         ├─ Relaxation / Fallback Status Banner (Levels 1-5)                 │
│         ├─ 3-Card Suggestion Stack (MealCard)                               │
│         │    ├─ Card 1 (Primary Star - highest score)                       │
│         │    ├─ Card 2 (Secondary Alternate - distinct protein)             │
│         │    └─ Card 3 (Tertiary Alternate - distinct carbs/protein)        │
│         │         │                                                         │
│         │         └─ QuickActions ("طبخت دي النهاردة" / "بواقي أكل")        │
│         └─ Empty State (خزنة الأكلات فارغة!)                                │
│                                                                             │
│     SpinWheelDialog (Modal Roulette with CustomPainter & Decelerating Curve)│
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Dependencies & Package Specifications

To implement this layer, the following dependencies must be present in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # Persistence (M1)
  drift: ^2.24.0
  drift_flutter: ^0.2.4
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.5
  path: ^1.9.1

  # State Management (M3)
  flutter_riverpod: ^2.6.1

  # Navigation (M3)
  go_router: ^14.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.13
  drift_dev: ^2.24.0
```

---

## 3. GoRouter & Navigation Bar (`lib/core/router/app_router.dart`)

### 3.1 Design Principles
1. **Stateful Navigation**: Employs `StatefulShellRoute.indexedStack` to maintain the scroll position and state of all 4 tabs across switching.
2. **Strict RTL Alignment**: Adheres to Arabic layout principles where Tab 0 (`الرئيسية`) appears on the right edge and Tab 3 (`الإعدادات`) on the left edge.
3. **Arabic Tab Labels & Icons**:
   - Tab 0: `الرئيسية` (`Icons.home_outlined` / `Icons.home`)
   - Tab 1: `خزانة الأكلات` (`Icons.restaurant_menu_outlined` / `Icons.restaurant_menu`)
   - Tab 2: `السجل` (`Icons.history_outlined` / `Icons.history`)
   - Tab 3: `الإعدادات` (`Icons.settings_outlined` / `Icons.settings`)

### 3.2 Concrete Code Implementation

```dart
// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/vault/presentation/meal_vault_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
final _shellNavigatorHome = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorVault = GlobalKey<NavigatorState>(debugLabel: 'shellVault');
final _shellNavigatorHistory = GlobalKey<NavigatorState>(debugLabel: 'shellHistory');
final _shellNavigatorSettings = GlobalKey<NavigatorState>(debugLabel: 'shellSettings');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Home (الرئيسية)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHome,
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),

          // Branch 1: Vault (خزانة الأكلات)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorVault,
            routes: [
              GoRoute(
                path: '/vault',
                name: 'vault',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MealVaultScreen(),
                ),
              ),
            ],
          ),

          // Branch 2: History (السجل)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHistory,
            routes: [
              GoRoute(
                path: '/history',
                name: 'history',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HistoryScreen(),
                ),
              ),
            ],
          ),

          // Branch 3: Settings (الإعدادات)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettings,
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        indicatorColor: theme.colorScheme.primaryContainer,
        destinations: const [
          NavigationDestination(
            key: ValueKey('nav_destination_home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            key: ValueKey('nav_destination_vault'),
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'خزانة الأكلات',
          ),
          NavigationDestination(
            key: ValueKey('nav_destination_history'),
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'السجل',
          ),
          NavigationDestination(
            key: ValueKey('nav_destination_settings'),
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
```

---

## 4. Home Screen Presentation (`lib/features/home/presentation/home_screen.dart`)

### 4.1 UI Anatomy & Layout Hierarchy
1. **Dynamic Arabic Header**:
   - Displays Egyptian greeting personalized by the hour ("صباح الفل والجمال", "أكلة النهاردة هنطبخ إيه؟", "مساء الهنا والسرور").
   - Displays today's formatted Hijri/Gregorian date in Arabic.
   - Includes the **"لف العجلة" (Spin the Wheel)** action button with dynamic disabled state when fewer than 2 meals are available.
2. **Status / Relaxation Banner**:
   - Displayed conditionally whenever `RecommendationResult.relaxationLevel > 0`.
   - Explains the exact graceful degradation reason in plain Egyptian Arabic (e.g., "تم تقليص فترة الاستبعاد إلى النصف لتوفير اقتراحات كافية").
3. **3-Card Recommendation Stack**:
   - Card 1: **الترشيح الأول (النجم)** — Prominent card with elevation 4, accent border, and priority badge.
   - Card 2: **اقتراح بديل 1** — Elevation 2, guaranteeing a distinct protein type from Card 1.
   - Card 3: **اقتراح بديل 2** — Elevation 1, guaranteeing distinct carbs or protein from Cards 1 & 2.
4. **Empty State Prompt**:
   - Conforms directly to test `T2.2` in `rtl_layout_test.dart` with centered prompt `خزنة الأكلات فارغة!` and action button `أضف أكلتك الأولى`.

### 4.2 Concrete Code Implementation

```dart
// lib/features/home/presentation/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../domain/cooldown_engine.dart';
import '../providers/recommendation_provider.dart';
import 'widgets/meal_card.dart';
import 'widgets/spin_wheel_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(todayRecommendationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('أكلة النهاردة'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'تحديث الاقتراحات',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(todayRecommendationsProvider),
          ),
        ],
      ),
      body: recsAsync.when(
        data: (result) {
          if (result.recommendations.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildRecommendationsView(context, ref, result);
        },
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        error: (err, stack) => _buildErrorState(context, ref, err),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.soup_kitchen_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'خزنة الأكلات فارغة!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بإضافة أول أكلة أو حمّل الأكلات المقترحة.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/vault'),
              icon: const Icon(Icons.add),
              label: const Text('أضف أكلتك الأولى'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تجهيز الاقتراحات',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(todayRecommendationsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsView(
    BuildContext context,
    WidgetRef ref,
    RecommendationResult<Meal> result,
  ) {
    final theme = Theme.of(context);
    final meals = result.recommendations;
    final canSpin = meals.length >= 2;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(todayRecommendationsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // 1. Header with greeting and Spin the Wheel
          _buildGreetingHeader(context, meals, canSpin),

          const SizedBox(height: 16),

          // 2. Status / Relaxation Banner (when fallback cascade is active)
          if (result.relaxationLevel > 0) ...[
            _buildRelaxationBanner(context, result),
            const SizedBox(height: 16),
          ],

          // 3. Section Title
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'اقتراحات النهاردة المختارة لك:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. 3-Card Suggestion Stack
          for (int i = 0; i < meals.length; i++) ...[
            MealCard(
              meal: meals[i],
              cardIndex: i,
              onCookedToday: () => _handleCookedToday(context, ref, meals[i]),
              onLeftover: () => _handleLeftover(context, ref, meals[i]),
            ),
            if (i < meals.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(BuildContext context, List<Meal> meals, bool canSpin) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'صباح الفل والجمال ☀️';
    } else if (hour >= 12 && hour < 18) {
      greeting = 'أكلة النهاردة.. هنطبخ إيه؟ 🍲';
    } else {
      greeting = 'مساء الهنا والسرور 🌙';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اخترنا لك أفضل 3 وجبات متنوعة ومتوازنة.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: canSpin
                ? () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => SpinWheelDialog(
                        candidates: meals,
                        onWinnerCooked: (winner) => _handleCookedToday(context, null, winner),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.casino_outlined, size: 20),
            label: const Text('لف العجلة'),
          ),
        ],
      ),
    );
  }

  Widget _buildRelaxationBanner(BuildContext context, RecommendationResult<Meal> result) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.tertiary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.onTertiaryContainer,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه التنوع الغذائي (مستوى ${result.relaxationLevel})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.relaxationReason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCookedToday(BuildContext context, WidgetRef? ref, Meal meal) async {
    // Controller dispatch through Riverpod provider
    final container = ref != null ? ref.read(recommendationControllerProvider.notifier) : null;
    await container?.markCookedToday(meal);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بالهنا والشفا! تم تسجيل "${meal.name}" في السجل.'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              container?.undoLastCookingLog();
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLeftover(BuildContext context, WidgetRef ref, Meal meal) async {
    final container = ref.read(recommendationControllerProvider.notifier);
    await container.markLeftover(meal);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل بواقي أكل "${meal.name}".'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              container.undoLastCookingLog();
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
```

---

## 5. Meal Card Stack Component (`lib/features/home/presentation/widgets/meal_card.dart`)

### 5.1 Card Structure & Specifications
1. **Priority Header Tag**:
   - Card 1: `⭐ الترشيح الأول (أفضل اختيار)`
   - Card 2: `✨ اقتراح بديل (بروتين مختلف)`
   - Card 3: `💡 فكرة إضافية (تنوع في النشويات)`
2. **Meal Title**:
   - Rendered with `maxLines: 3` and `TextOverflow.ellipsis` to strictly fulfill boundary test `T2.1: Extremely long Arabic meal title wraps without overflow`.
3. **Arabic Localized Prep Time**:
   - Helper function conforming to test `R4.3`:
     ```dart
     String formatPrepTime(int minutes) {
       if (minutes <= 10) return '$minutes دقائق';
       return '$minutes دقيقة';
     }
     ```
4. **Nutritional & Category Tags**:
   - Category label using Drift extension `meal.category.labelArabic`.
   - Protein chip using `meal.proteinType.labelArabic`.
   - Carbs chip using `meal.carbsType.labelArabic`.
5. **Special Badges**:
   - **Friday Special** (`isFridaySpecial`): Amber badge with `Icons.stars_rounded` and label `أكلة جمعة`.
   - **Budget Friendly** (`isBudgetFriendly`): Green badge with `Icons.savings_outlined` and label `اقتصادي`.
   - **Favorite** (`isFavorite`): Coral badge with `Icons.favorite` and label `مفضلة`.
6. **Embedded Quick Actions**:
   - Hosts `QuickActions` with "طبخت دي النهاردة" and "بواقي أكل".

### 5.2 Concrete Code Implementation

```dart
// lib/features/home/presentation/widgets/meal_card.dart
import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import 'quick_actions.dart';

class MealCard extends StatelessWidget {
  final Meal meal;
  final int cardIndex;
  final VoidCallback onCookedToday;
  final VoidCallback onLeftover;
  final VoidCallback? onTap;

  const MealCard({
    super.key,
    required this.meal,
    required this.cardIndex,
    required this.onCookedToday,
    required this.onLeftover,
    this.onTap,
  });

  String _formatPrepTime(int minutes) {
    if (minutes <= 10) {
      return '$minutes دقائق';
    } else {
      return '$minutes دقيقة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = cardIndex == 0;

    return Card(
      elevation: isPrimary ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPrimary
            ? BorderSide(color: theme.colorScheme.primary.withOpacity(0.5), width: 1.5)
            : BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Banner: Priority Tag
            _buildPriorityBanner(context, isPrimary),

            // 2. Photo / Egyptian Graphic Placeholder
            _buildHeroImage(context),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3. Badges Row (Friday, Budget, Favorite)
                  _buildBadgesRow(context),

                  const SizedBox(height: 8),

                  // 4. Meal Title (T2.1: Multi-line wrapped without overflow)
                  Text(
                    meal.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isPrimary ? 20 : 18,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Metadata Tags (Prep time, Category, Protein, Carbs)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Prep Time (R4.3)
                      Chip(
                        avatar: const Icon(Icons.timer_outlined, size: 16),
                        label: Text(_formatPrepTime(meal.prepTime)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      // Category
                      Chip(
                        avatar: const Icon(Icons.category_outlined, size: 16),
                        label: Text(meal.category.labelArabic),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      // Protein Tag
                      Chip(
                        avatar: const Icon(Icons.egg_alt_outlined, size: 16),
                        label: Text(meal.proteinType.labelArabic),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      // Carbs Tag
                      Chip(
                        avatar: const Icon(Icons.bakery_dining_outlined, size: 16),
                        label: Text(meal.carbsType.labelArabic),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // 6. Quick Action Buttons (R4.6: RTL primary preceding secondary)
                  QuickActions(
                    onCookedToday: onCookedToday,
                    onLeftover: onLeftover,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBanner(BuildContext context, bool isPrimary) {
    final theme = Theme.of(context);
    String title;
    Color bgColor;
    Color fgColor;

    switch (cardIndex) {
      case 0:
        title = '⭐ الترشيح الأول (أفضل اختيار)';
        bgColor = theme.colorScheme.primaryContainer;
        fgColor = theme.colorScheme.onPrimaryContainer;
        break;
      case 1:
        title = '✨ اقتراح بديل أول (تنويع البروتين)';
        bgColor = theme.colorScheme.secondaryContainer;
        fgColor = theme.colorScheme.onSecondaryContainer;
        break;
      case 2:
      default:
        title = '💡 اقتراح بديل ثانٍ (تنويع النشويات)';
        bgColor = theme.colorScheme.surfaceContainerHighest;
        fgColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = meal.photoPath != null &&
        meal.photoPath!.isNotEmpty &&
        File(meal.photoPath!).existsSync();

    if (hasPhoto) {
      return SizedBox(
        height: cardIndex == 0 ? 180 : 130,
        width: double.infinity,
        child: Image.file(
          File(meal.photoPath!),
          fit: BoxFit.cover,
        ),
      );
    }

    // Egyptian Kitchen Aesthetic Placeholder
    return Container(
      height: cardIndex == 0 ? 140 : 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.12),
            theme.colorScheme.tertiary.withOpacity(0.18),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: cardIndex == 0 ? 48 : 36,
          color: theme.colorScheme.primary.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildBadgesRow(BuildContext context) {
    final badges = <Widget>[];

    if (meal.isFridaySpecial) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.shade600),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, size: 14, color: Colors.amber.shade900),
              const SizedBox(width: 4),
              Text(
                'أكلة جمعة',
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (meal.isBudgetFriendly) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green.shade600),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.savings_outlined, size: 14, color: Colors.green.shade800),
              const SizedBox(width: 4),
              Text(
                'اقتصادي',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (meal.isFavorite) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red.shade600),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, size: 14, color: Colors.red.shade800),
              const SizedBox(width: 4),
              Text(
                'مفضلة',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      children: badges,
    );
  }
}
```

---

## 6. Quick Action Buttons (`lib/features/home/presentation/widgets/quick_actions.dart`)

### 6.1 Layout & RTL Verification
In test `R4.6` of `rtl_layout_test.dart`:
- The primary button (`طبخت دي النهاردة` / `طبختها النهاردة`) must be rendered first in the `Row`.
- In RTL layout, the first child's X coordinate is greater than the second child's X coordinate (`dx(cooked) > dx(leftover)`).
- Secondary button is `بواقي أكل` (or `أكل بايت`).

### 6.2 Concrete Code Implementation

```dart
// lib/features/home/presentation/widgets/quick_actions.dart
import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback onCookedToday;
  final VoidCallback onLeftover;

  const QuickActions({
    super.key,
    required this.onCookedToday,
    required this.onLeftover,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Primary Action Button (in RTL, rendered on right side)
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('btn_cooked_today'),
            onPressed: onCookedToday,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              'طبخت دي النهاردة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Secondary Action Button (in RTL, rendered to the left)
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('btn_leftover'),
            onPressed: onLeftover,
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: const Text(
              'بواقي أكل',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
```

---

## 7. Spin the Wheel Roulette (`lib/features/home/presentation/widgets/spin_wheel_dialog.dart`)

### 7.1 Mathematical & Animation Model
1. **Candidate Validation**:
   - Per test `T2.1` in `riverpod_reactivity_test.dart`, the roulette requires at least 2 candidates to spin. If candidates < 2, the dialog alerts the user and prevents spinning.
2. **Animation**:
   - `AnimationController` with duration = 4.0 seconds.
   - Curve: `Curves.easeOutCubic` to realistically simulate inertial friction.
3. **Winning Angle Calculation**:
   - Total slices: $N = \text{candidates.length}$.
   - Sector sweep angle: $\theta = \frac{2\pi}{N}$.
   - Winning index $k \in [0, N - 1]$ chosen uniformly at random.
   - Target stop angle: $\phi = 2\pi \times M + \left(k + 0.5\right) \times \theta$, where $M = 6$ (number of full revolutions).
4. **Custom Wheel Painter**:
   - Paints $N$ circular wedges in alternating warm Egyptian hues.
   - Draws radiating Arabic meal titles along slice medians.
   - Draws outer decorative pegs and center spinner hub.
   - Top indicator pointer pointing directly downwards at 12 o'clock.

### 7.2 Concrete Code Implementation

```dart
// lib/features/home/presentation/widgets/spin_wheel_dialog.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

class SpinWheelDialog extends StatefulWidget {
  final List<Meal> candidates;
  final ValueChanged<Meal>? onWinnerCooked;

  const SpinWheelDialog({
    super.key,
    required this.candidates,
    this.onWinnerCooked,
  });

  @override
  State<SpinWheelDialog> createState() => _SpinWheelDialogState();
}

class _SpinWheelDialogState extends State<SpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  double _currentAngle = 0.0;
  Meal? _winnerMeal;
  bool _isSpinning = false;

  final List<Color> _palette = const [
    Color(0xFFE57373), // Coral Red
    Color(0xFFFFB74D), // Saffron Amber
    Color(0xFF4DB6AC), // Nile Teal
    Color(0xFF81C784), // Mint Green
    Color(0xFFBA68C8), // Violet
    Color(0xFFFFD54F), // Mustard
    Color(0xFF4DD0E1), // Cyan
    Color(0xFFA1887F), // Warm Spice
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning || widget.candidates.length < 2) return;

    setState(() {
      _isSpinning = true;
      _winnerMeal = null;
    });

    final random = math.Random();
    final candidateCount = widget.candidates.length;
    final winnerIndex = random.nextInt(candidateCount);
    final sectorAngle = (2 * math.pi) / candidateCount;

    // Pointer is at 12 o'clock (-pi / 2).
    // Target angle brings the chosen sector directly under the pointer.
    final targetSectorAngle = (winnerIndex + 0.5) * sectorAngle;
    const fullSpins = 6 * 2 * math.pi;
    final endAngle = _currentAngle + fullSpins + (2 * math.pi - targetSectorAngle);

    _animation = Tween<double>(begin: _currentAngle, end: endAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {});
      });

    _controller.forward(from: 0.0).then((_) {
      setState(() {
        _currentAngle = endAngle % (2 * math.pi);
        _winnerMeal = widget.candidates[winnerIndex];
        _isSpinning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidates = widget.candidates;

    if (candidates.length < 2) {
      return AlertDialog(
        title: const Text('عجلة الحظ'),
        content: const Text('عجلة الحظ تحتاج أكلتين على الأقل للتدوير!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.casino, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'عجلة الحظ 🎡',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isSpinning ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Roulette Wheel with Top Arrow Pointer
            SizedBox(
              height: 260,
              width: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating Wheel
                  Transform.rotate(
                    angle: _controller.isAnimating ? _animation.value : _currentAngle,
                    child: CustomPaint(
                      size: const Size(250, 250),
                      painter: _WheelPainter(
                        candidates: candidates,
                        palette: _palette,
                        theme: theme,
                      ),
                    ),
                  ),

                  // Center Spin Hub
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: Icon(
                      Icons.star,
                      size: 24,
                      color: theme.colorScheme.primary,
                    ),
                  ),

                  // Top Indicator Arrow (Pointing Down at 12 o'clock)
                  Positioned(
                    top: 0,
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 40,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Winner Display
            if (_winnerMeal != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '🎉 أكلة النهاردة وقعت على:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _winnerMeal!.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isSpinning ? null : _spin,
                    child: Text(_winnerMeal == null ? 'ابدأ التدوير' : 'لف تاني'),
                  ),
                ),
                if (_winnerMeal != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onWinnerCooked?.call(_winnerMeal!);
                    },
                    child: const Text('طبخت دي'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<Meal> candidates;
  final List<Color> palette;
  final ThemeData theme;

  _WheelPainter({
    required this.candidates,
    required this.palette,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final count = candidates.length;
    final sweepAngle = (2 * math.pi) / count;

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white;

    for (int i = 0; i < count; i++) {
      final startAngle = i * sweepAngle;
      paint.color = palette[i % palette.length];

      // Draw Sector Wedge
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Draw Radiating Meal Name
      final textAngle = startAngle + sweepAngle / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);

      final span = TextSpan(
        text: _truncate(candidates[i].name, 14),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
        ),
      );

      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.rtl,
      )..layout();

      // Position text along outer radius
      tp.paint(canvas, Offset(radius * 0.32, -tp.height / 2));
      canvas.restore();
    }

    // Outer Rim Border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = theme.colorScheme.primary,
    );
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.candidates != candidates;
  }
}
```

---

## 8. Riverpod State Consumer Integration & Contracts

### 8.1 Required Providers (Coordinated with Explorer 1)
In `lib/features/home/providers/recommendation_provider.dart`:

```dart
// Derived stream provider emitting top recommendations with CooldownEngine
final todayRecommendationsProvider = StreamProvider<RecommendationResult<Meal>>((ref) {
  final mealsAsync = ref.watch(allMealsProvider);
  final historyAsync = ref.watch(mealHistoryProvider);
  final settingsAsync = ref.watch(appSettingsProvider);

  final meals = mealsAsync.valueOrNull ?? [];
  final history = historyAsync.valueOrNull ?? [];
  final settings = settingsAsync.valueOrNull ?? const AppSetting();

  final engine = ref.watch(cooldownEngineProvider);
  return Stream.value(
    engine.compute<Meal>(
      meals: meals,
      history: history,
      settings: settings,
      today: DateTime.now(),
    ),
  );
});

// Recommendation mutation controller for marking cooked/leftovers
final recommendationControllerProvider =
    AsyncNotifierProvider<RecommendationController, void>(RecommendationController.new);

class RecommendationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markCookedToday(Meal meal, {String? notes}) async {
    final historyDao = ref.read(mealHistoryDaoProvider);
    await historyDao.logCookedMeal(meal, notes: notes);
  }

  Future<void> markLeftover(Meal meal, {String? notes}) async {
    final historyDao = ref.read(mealHistoryDaoProvider);
    await historyDao.logLeftoverMeal(meal, notes: notes);
  }

  Future<void> undoLastCookingLog() async {
    final historyDao = ref.read(mealHistoryDaoProvider);
    final recent = await historyDao.getRecentHistory(limit: 1);
    if (recent.isNotEmpty) {
      await historyDao.deleteHistoryEntry(recent.first.id);
    }
  }
}
```

### 8.2 State Mutation Lifecycle
1. User taps "طبخت دي النهاردة" on Card 1.
2. `recommendationControllerProvider.markCookedToday(meal)` inserts a row into Drift `meal_history` table.
3. Reactive `watchHistory()` stream in Drift emits the new history snapshot.
4. `todayRecommendationsProvider` automatically re-evaluates `CooldownEngine.compute()`.
5. The cooked meal is immediately placed into the cooldown window.
6. A fresh candidate replaces Card 1, and the cards update with zero manual boilerplate!

---

## 9. Egyptian RTL Arabic Localization & Visual Standards

### 9.1 Arabic Pluralization Rules
To comply with tests `R4.3` and `R4.4`:
- **Prep Time**:
  * $\le 10$ minutes: `$minutes دقائق` (e.g. `5 دقائق`, `10 دقائق`)
  * $> 10$ minutes: `$minutes دقيقة` (e.g. `15 دقيقة`, `45 دقيقة`)
- **Cooldown Days**:
  * 1 day: `يوم واحد`
  * 2 days: `يومان`
  * $3 \le \text{days} \le 10$: `$days أيام` (e.g. `7 أيام`)
  * $> 10$ days: `$days يوماً` (e.g. `14 يوماً`, `30 يوماً`)

### 9.2 Material 3 Theme Integration
- Uses `ColorScheme.fromSeed(seedColor: Color(0xFFC04A26))` (Warm Egyptian Terracotta / Brick Red).
- High contrast accessible labels.
- Arabic typography uses default system Arabic font (Tajawal / Cairo / Roboto Fallback).

---

## 10. Test Compliance Matrix

| Test ID | Test Name | Blueprint Compliance Specification |
|---------|-----------|-----------------------------------|
| **R4.1** | Root RTL enforcement | `MaterialApp(locale: Locale('ar'))` with RTL Directionality |
| **R4.2** | NavigationBar RTL alignment | Tab 0 (`الرئيسية`) at rightmost index, Tab 3 (`الإعدادات`) at leftmost index |
| **R4.3** | Prep time Arabic formatting | `_formatPrepTime()` helper (`<=10 دقائق`, `>10 دقيقة`) |
| **R4.4** | Cooldown slider Arabic units | `formatCooldown()` helper (`يوم واحد`, `يومان`, `أيام`, `يوماً`) |
| **R4.5** | BackButton RTL auto-mirroring | Flutter adaptive back button mirroring in RTL AppBar |
| **R4.6** | Primary / Secondary buttons RTL order | Primary (`طبخت دي النهاردة`) precedes Secondary (`بواقي أكل`) in RTL Row |
| **T2.1** | Long Arabic title wrapping | `Text(meal.name, maxLines: 3, overflow: TextOverflow.ellipsis)` |
| **T2.2** | Empty State centered prompt | `خزنة الأكلات فارغة!` with `أضف أكلتك الأولى` action button |
| **T2.1 (Reactivity)** | Spin the Wheel candidate check | Prevents spinning if `candidates.length < 2` |
| **T3.2 (E2E)** | Cooked today immediate cooldown | Controller logs to history; reactive stream re-runs CooldownEngine |
| **T3.3 (E2E)** | Leftover protein fatigue | Controller logs leftover; prevents repeat protein in next recommendation |
| **T3.5 (E2E)** | Spin the Wheel selection | Winner is picked from eligible recommendations, marked cooked, enters cooldown |

---

## 11. Implementation Action Plan for Milestone 3 Workers

When implementing Milestone 3:
1. **File 1**: `lib/core/router/app_router.dart`
   - Implement `appRouterProvider` and `ScaffoldWithNavBar` with the 4 tabs.
2. **File 2**: `lib/features/home/presentation/widgets/quick_actions.dart`
   - Implement `QuickActions` with "طبخت دي النهاردة" and "بواقي أكل".
3. **File 3**: `lib/features/home/presentation/widgets/meal_card.dart`
   - Implement `MealCard` with badges, tags, and prep time formatting.
4. **File 4**: `lib/features/home/presentation/widgets/spin_wheel_dialog.dart`
   - Implement `SpinWheelDialog` with custom painter and animated roulette.
5. **File 5**: `lib/features/home/presentation/home_screen.dart`
   - Assemble `HomeScreen` with header, relaxation banner, 3-card stack, and empty state.
6. **File 6**: `lib/features/home/providers/recommendation_provider.dart`
   - Bind `todayRecommendationsProvider` and `recommendationControllerProvider` with Drift DAOs.
