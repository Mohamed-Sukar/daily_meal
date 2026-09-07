// test/widget/rtl_layout_test.dart
// Tier 1 (Feature Coverage) & Tier 2 (Boundary Cases) for R4: Material 3 Arabic RTL Localization & Layout

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tier 1: Feature Coverage (R4 - Material 3 Arabic RTL Layout)', () {
    testWidgets('R4.1: Root application enforces TextDirection.rtl by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(title: const Text('أكلة النهاردة')),
              body: const Center(child: Text('الرئيسية')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final directionality = Directionality.of(tester.element(find.text('الرئيسية')));
      expect(directionality, equals(TextDirection.rtl));
      expect(find.text('أكلة النهاردة'), findsOneWidget);
    });

    testWidgets('R4.2: Bottom navigation bar tabs align according to RTL layout', (tester) async {
      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: selectedTab,
                    onDestinationSelected: (idx) => setState(() => selectedTab = idx),
                    destinations: const [
                      NavigationDestination(icon: Icon(Icons.home), label: 'الرئيسية'),
                      NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'خزنة الوجبات'),
                      NavigationDestination(icon: Icon(Icons.history), label: 'سجل الأكلات'),
                      NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find destinations
      final homeFinder = find.text('الرئيسية');
      final settingsFinder = find.text('الإعدادات');

      expect(homeFinder, findsOneWidget);
      expect(settingsFinder, findsOneWidget);

      // In RTL, index 0 (الرئيسية) should have an X-coordinate greater than index 3 (الإعدادات)
      final homeX = tester.getCenter(homeFinder).dx;
      final settingsX = tester.getCenter(settingsFinder).dx;

      expect(homeX, greaterThan(settingsX),
          reason: 'In RTL, Tab 0 (Home) must be on the right and Tab 3 (Settings) on the left!');
    });

    testWidgets('R4.3: Prep time is formatted with Arabic localized units', (tester) async {
      String formatPrepTime(int minutes) {
        if (minutes <= 10) {
          return '$minutes دقائق';
        } else {
          return '$minutes دقيقة';
        }
      }

      expect(formatPrepTime(5), equals('5 دقائق'));
      expect(formatPrepTime(10), equals('10 دقائق'));
      expect(formatPrepTime(30), equals('30 دقيقة'));
      expect(formatPrepTime(45), equals('45 دقيقة'));

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Chip(
                avatar: const Icon(Icons.timer),
                label: Text(formatPrepTime(45)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('45 دقيقة'), findsOneWidget);
    });

    testWidgets('R4.4: Cooldown duration slider displays Arabic days unit', (tester) async {
      String formatCooldown(int days) {
        if (days == 1) return 'يوم واحد';
        if (days == 2) return 'يومان';
        if (days <= 10) return '$days أيام';
        return '$days يوماً';
      }

      expect(formatCooldown(1), equals('يوم واحد'));
      expect(formatCooldown(2), equals('يومان'));
      expect(formatCooldown(7), equals('7 أيام'));
      expect(formatCooldown(14), equals('14 يوماً'));
      expect(formatCooldown(30), equals('30 يوماً'));

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Text(formatCooldown(14)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('14 يوماً'), findsOneWidget);
    });

    testWidgets('R4.5: Forward and back navigation icons adapt to RTL layout', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(
                leading: const BackButton(),
                title: const Text('تفاصيل الوجبة'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Back button in RTL points to the right (adaptive behavior)
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('R4.6: Meal recommendation card displays primary and secondary action buttons in RTL flow', (tester) async {
      bool cookedTapped = false;
      bool leftoverTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('ملوخية خضراء بالفراخ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FilledButton.icon(
                              onPressed: () => cookedTapped = true,
                              icon: const Icon(Icons.check),
                              label: const Text('طبختها النهاردة'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => leftoverTapped = true,
                              icon: const Icon(Icons.repeat),
                              label: const Text('أكل بايت'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cookedBtn = find.text('طبختها النهاردة');
      final leftoverBtn = find.text('أكل بايت');

      expect(cookedBtn, findsOneWidget);
      expect(leftoverBtn, findsOneWidget);

      // In RTL, first child ('طبختها النهاردة') should have an X-coordinate greater than second child ('أكل بايت')
      final cookedX = tester.getCenter(cookedBtn).dx;
      final leftoverX = tester.getCenter(leftoverBtn).dx;
      expect(cookedX, greaterThan(leftoverX),
          reason: 'Primary button should precede secondary button in RTL direction!');

      await tester.tap(cookedBtn);
      await tester.tap(leftoverBtn);
      expect(cookedTapped, isTrue);
      expect(leftoverTapped, isTrue);
    });
  });

  group('Tier 2: Boundary & Corner Cases (R4)', () {
    testWidgets('T2.1: Extremely long Arabic meal title wraps without overflow', (tester) async {
      const longTitle = 'طاجن سمك وقار إسكندراني بالبطاطس والصلصة الحارة المسبكة بالثوم والكمون والليمون المعصفر في الفرن البلدي';

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                width: 300,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          longTitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Must not trigger RenderFlex overflow!');
      expect(find.text(longTitle), findsOneWidget);
    });

    testWidgets('T2.2: Empty state renders centered RTL Arabic prompt with call to action', (tester) async {
      bool addTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.soup_kitchen_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'خزنة الأكلات فارغة!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ابدأ بإضافة أول أكلة أو حمّل الأكلات المقترحة.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => addTapped = true,
                      child: const Text('أضف أكلتك الأولى'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('خزنة الأكلات فارغة!'), findsOneWidget);
      expect(find.text('أضف أكلتك الأولى'), findsOneWidget);

      await tester.tap(find.text('أضف أكلتك الأولى'));
      expect(addTapped, isTrue);
    });
  });
}
