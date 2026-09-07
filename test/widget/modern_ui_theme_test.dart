import 'package:daily_meal/core/database/app_database.dart';
import 'package:daily_meal/core/theme/app_theme.dart';
import 'package:daily_meal/features/home/presentation/widgets/meal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildThemedApp({
  required Widget child,
  required ThemeData theme,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: child,
      ),
    ),
  );
}

Meal _createSampleMeal({
  int id = 1,
  String name = 'طاجن بامية باللحمة الضاني',
  bool isFridaySpecial = true,
  bool isBudgetFriendly = true,
  bool isFavorite = true,
}) {
  return Meal(
    id: id,
    name: name,
    category: MealCategory.egyptianTraditional,
    proteinType: ProteinType.beef,
    carbsType: CarbsType.rice,
    prepTime: 45,
    isFridaySpecial: isFridaySpecial,
    isBudgetFriendly: isBudgetFriendly,
    isFavorite: isFavorite,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('Modern Typography & Font Integration Tests', () {
    test('R1.1: lightTheme applies Cairo font family globally', () {
      final light = AppTheme.lightTheme;
      expect(light.textTheme.bodyMedium?.fontFamily, contains('Cairo'));
      expect(light.textTheme.titleLarge?.fontFamily, contains('Cairo'));
      expect(light.textTheme.bodyLarge?.fontFamily, contains('Cairo'));
    });

    test('R1.2: darkTheme applies Cairo font family globally', () {
      final dark = AppTheme.darkTheme;
      expect(dark.textTheme.bodyMedium?.fontFamily, contains('Cairo'));
      expect(dark.textTheme.titleLarge?.fontFamily, contains('Cairo'));
      expect(dark.textTheme.bodyLarge?.fontFamily, contains('Cairo'));
    });
  });

  group('Dark Mode Palette Modernization Tests', () {
    test('R2.1: darkTheme uses modern deep grays instead of pitch black or jarring colors', () {
      final dark = AppTheme.darkTheme;
      final cs = dark.colorScheme;

      expect(cs.brightness, equals(Brightness.dark));

      // Modern deep gray surface (e.g. #1A1A1A), not pitch black #000000
      expect(cs.surface, equals(const Color(0xFF1A1A1A)));
      expect(cs.surfaceDim, equals(const Color(0xFF141414)));
      expect(cs.surfaceContainerLow, equals(const Color(0xFF1E1E1E)));

      // Scaffold background uses deep gray
      expect(dark.scaffoldBackgroundColor, equals(const Color(0xFF141414)));

      // Soft, non-jarring contrast text
      expect(cs.onSurface, equals(const Color(0xFFEDEDED)));

      // Warm terracotta primary & saffron secondary
      expect(cs.primary, equals(const Color(0xFFFF8B66)));
      expect(cs.secondary, equals(const Color(0xFFFFB879)));
      expect(cs.tertiary, equals(const Color(0xFF81C784)));
    });

    test('R2.2: darkTheme card, chip, dialog and navigationBar themes match M3 standards', () {
      final dark = AppTheme.darkTheme;
      expect(dark.cardTheme.elevation, equals(0));
      expect(dark.cardTheme.color, equals(const Color(0xFF1E1E1E)));
      expect(dark.chipTheme.backgroundColor, equals(const Color(0xFF242424)));
      expect(dark.dialogTheme.backgroundColor, equals(const Color(0xFF2A2A2A)));
      expect(dark.navigationBarTheme.backgroundColor, equals(const Color(0xFF0F0F0F)));
    });
  });

  group('MealCard M3 Modern Styling Tests', () {
    testWidgets('R3.1: MealCard renders smoothly in light mode with all elements', (tester) async {
      final meal = _createSampleMeal();

      await tester.pumpWidget(
        _buildThemedApp(
          theme: AppTheme.lightTheme,
          child: SingleChildScrollView(
            child: MealCard(
              meal: meal,
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MealCard), findsOneWidget);
      expect(find.text('طاجن بامية باللحمة الضاني'), findsOneWidget);
      expect(find.text('⭐ الترشيح الأول (أفضل اختيار)'), findsOneWidget);
      expect(find.text('أكلة جمعة'), findsOneWidget);
      expect(find.text('اقتصادي'), findsOneWidget);
      expect(find.text('مفضلة'), findsOneWidget);
      expect(find.text('45 دقيقة'), findsOneWidget);
    });

    testWidgets('R3.2: MealCard renders smoothly in dark mode with dark-adaptive styling', (tester) async {
      final meal = _createSampleMeal();

      await tester.pumpWidget(
        _buildThemedApp(
          theme: AppTheme.darkTheme,
          child: SingleChildScrollView(
            child: MealCard(
              meal: meal,
              cardIndex: 0,
              onCookedToday: () {},
              onLeftover: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MealCard), findsOneWidget);
      expect(find.text('طاجن بامية باللحمة الضاني'), findsOneWidget);
      expect(find.text('⭐ الترشيح الأول (أفضل اختيار)'), findsOneWidget);
      expect(find.text('أكلة جمعة'), findsOneWidget);
      expect(find.text('اقتصادي'), findsOneWidget);
      expect(find.text('مفضلة'), findsOneWidget);
      expect(find.text('45 دقيقة'), findsOneWidget);
    });

    testWidgets('R3.3: MealCard secondary and tertiary card banners render properly', (tester) async {
      final meal1 = _createSampleMeal(id: 1, name: 'كفتة مشوية');
      final meal2 = _createSampleMeal(id: 2, name: 'كشري مصري');

      await tester.pumpWidget(
        _buildThemedApp(
          theme: AppTheme.darkTheme,
          child: SingleChildScrollView(
            child: Column(
              children: [
                MealCard(
                  meal: meal1,
                  cardIndex: 1,
                  onCookedToday: () {},
                  onLeftover: () {},
                ),
                MealCard(
                  meal: meal2,
                  cardIndex: 2,
                  onCookedToday: () {},
                  onLeftover: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('✨ اقتراح بديل أول (تنويع البروتين)'), findsOneWidget);
      expect(find.text('💡 اقتراح بديل ثانٍ (تنويع النشويات)'), findsOneWidget);
    });
  });
}
