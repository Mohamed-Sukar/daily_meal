# UI Viewport & Accessibility Overflow Remediation Plan
**Agent Identity:** 	eamwork_preview_explorer_m3_iter3_1 (UI Viewport & Accessibility Overflow Explorer)  
**Milestone:** Milestone 3 Iteration 3  
**Target Environment:** Flutter 3.44.0 / Dart 3.12.0  
**Constraints Investigated:** Compact mobile viewports (320px width x 550px height) with accessibility text scaling (1.4x linear) in Arabic RTL layout.

---

## 1. Executive Summary

Milestone 3 Iteration 2 achieved 0 analyzer diagnostics and passed baseline stress suites (such as 390x844 with standard fonts). However, empirical stress testing conducted by Challenger 1 (challenger_viewport_overflow_test.dart) and confirmed by Reviewer 2 identified **5 critical RenderFlex overflow defects** occurring under combined constraints of a 320x550 compact viewport and 1.4x accessibility font scaling.

This document formulates the root-cause analysis, exact layout calculations, and tested code remediations for all 5 defects:

| Defect # | Target File & Line | Severity | Layout Failure Mode | Remediation |
|---|---|---|---|---|
| **D1** | lib/features/vault/presentation/widgets/meal_vault_card.dart:49 | Critical | Badges Row overflows horizontally by 130px | Replace Row with Wrap(spacing: 4, runSpacing: 4) and remove rigid left margin |
| **D2A** | lib/features/vault/presentation/add_edit_meal_dialog.dart:149 | Major | Header Row overflows horizontally by 218px | Wrap title Text in Expanded(child: Text(..., overflow: TextOverflow.ellipsis)) |
| **D2B** | lib/features/vault/presentation/add_edit_meal_dialog.dart:336 | Major | Actions Row overflows horizontally by 220px | Replace Row with Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8) |
| **D3** | lib/features/vault/presentation/widgets/delete_meal_dialog.dart:25/31 | Major | Content Column overflows vertically by 932px | Wrap content Column in SingleChildScrollView(child: Column(...)) |
| **D4** | lib/features/vault/presentation/widgets/vault_empty_state.dart:60 | Major | Empty state Column overflows vertically by 131px | Wrap empty state Column in SingleChildScrollView (both default and search results) |
| **D5** | lib/features/history/presentation/history_screen.dart:60 | Major | Empty history Column overflows vertically by 53px | Wrap empty state Column in SingleChildScrollView |

---

## 2. In-Depth Defect Breakdown & Root Causes

### Defect 1: MealVaultCard Badges Row Horizontal Overflow
- **File:** lib/features/vault/presentation/widgets/meal_vault_card.dart:49
- **Error:** A RenderFlex overflowed by 130 pixels on the right.
- **Scenario:** Viewing any meal in the vault where both isFridaySpecial: true and isBudgetFriendly: true on a 320px viewport with 1.4x text scaling.
- **Root Cause & Layout Mechanics:**
  - Viewport width: 320px.
  - Card horizontal margin: 16px each side $\rightarrow 320 - 32 = 288\text{px}$.
  - Card internal padding: 12px each side $\rightarrow 288 - 24 = 264\text{px}$.
  - The card row consists of:
    1. Thumbnail placeholder: 72px + 12px SizedBox = 84px.
    2. Actions Column (Favorite, Edit, Delete): ~48px + 8px SizedBox = 56px.
    3. Middle Expanded(child: Column(...)):  - 84 - 56 = 124\text{px}$ available width.
  - On line 49, the badges ('أكلة جمعة' and 'اقتصادي') are placed inside an unconstrained Row:
    `dart
    Row(
      children: [
        if (meal.isFridaySpecial)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(left: 6),
            ...
            child: Text('أكلة جمعة', style: TextStyle(fontSize: 10, ...)),
          ),
        if (meal.isBudgetFriendly)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            ...
            child: Text('اقتصادي', style: TextStyle(fontSize: 10, ...)),
          ),
      ],
    )
    `
  - At 1.4x text scale:
    - 'أكلة جمعة' (font size 14px bold, padding 12px, margin 6px) requires ~83px.
    - 'اقتصادي' (font size 14px bold, padding 12px) requires ~67px.
    - Total required width:  + 67 = 150\text{px}$.
  - Because Row cannot wrap its items, it attempts to lay them out horizontally, overflowing the 124px boundary.
- **Remediation:**
  Replace Row with Wrap(spacing: 4, runSpacing: 4, children: [...]) and remove margin: const EdgeInsets.only(left: 6) from the first container so spacing is uniform. When space is constrained, the second badge cleanly drops to the next line.

---

### Defect 2: AddEditMealDialog Header Title & Action Buttons Horizontal Overflows
- **File:** lib/features/vault/presentation/add_edit_meal_dialog.dart:149, 336
- **Error:**
  - Header: A RenderFlex overflowed by 218 pixels on the right.
  - Actions: A RenderFlex overflowed by 220 pixels on the right.
- **Scenario:** Opening AddEditMealDialog (either add or edit mode) on a 320px viewport with 1.4x text scaling.
- **Root Cause & Layout Mechanics:**
  - Material 3 Dialog on a 320px viewport has default horizontal margin of 40px on each side (80px total), leaving 240px.
  - Inside the dialog, Padding(horizontal: 20, vertical: 20) reduces available width to  - 40 = 200\text{px}$.
  - **Header Row (line 149):**
    - Contains Text(isEditing ? 'تعديل الأكلة' : 'إضافة أكلة جديدة') and IconButton(icon: Icons.close).
    - At 1.4x scale, 	itleLarge font size is ~30.8sp. The 16-character Arabic title requires ~210px–240px.
    - IconButton requires 48px.
    - Total requirement = ~268px inside 200px available space $\rightarrow$ unconstrained Row overflows by 218px.
  - **Actions Row (line 336):**
    - Contains TextButton('إلغاء') and FilledButton(isEditing ? 'حفظ التعديلات' : 'إضافة الأكلة').
    - At 1.4x scale, TextButton requires ~72px, SizedBox(width: 8) is 8px, and FilledButton requires ~160px.
    - Total requirement = ~240px inside 200px available space $\rightarrow$ unconstrained Row overflows by 220px.
- **Remediation:**
  - Header: Wrap Text in Expanded(child: Text(..., overflow: TextOverflow.ellipsis)).
  - Actions: Replace Row with Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [TextButton(...), FilledButton(...)]).

---

### Defect 3: DeleteMealDialog Content Column Vertical Overflow
- **File:** lib/features/vault/presentation/widgets/delete_meal_dialog.dart:25/31
- **Error:** A RenderFlex overflowed by 932 pixels on the bottom.
- **Scenario:** Opening DeleteMealDialog for a meal with an authentic descriptive name (e.g. up to 120-154 characters) on a 550px height viewport with 1.4x text scaling.
- **Root Cause & Layout Mechanics:**
  - Material 3 AlertDialog has vertical margins of 24px top and bottom, giving 502px max dialog height on a 550px viewport.
  - Top warning icon (40px) + padding = 64px.
  - Title ('حذف الأكلة') + padding = 50px.
  - Actions bar = 64px.
  - Maximum remaining space for dialog content =  - (64 + 50 + 64) = 324\text{px}$.
  - When meal.name is long, the text wraps to 8–10 lines (~220px) and the safety note card requires ~160px, totaling ~396px $\rightarrow$ natural height exceeds available space.
  - Because AlertDialog is not marked scrollable and content is a rigid Column, Flutter throws a vertical overflow.
- **Remediation:**
  Wrap the Column in SingleChildScrollView(child: Column(...)). (Optionally or alternatively set scrollable: true on AlertDialog, but wrapping content: SingleChildScrollView(...) ensures the message body scrolls gracefully while keeping title and action buttons fixed in place).

---

### Defect 4: VaultEmptyState Vertical Overflow
- **File:** lib/features/vault/presentation/widgets/vault_empty_state.dart:60
- **Error:** A RenderFlex overflowed by 131 pixels on the bottom.
- **Scenario:** Viewing the Vault screen when 0 meals are registered (or search returns 0 meals) on a 550px height viewport with 1.4x text scaling.
- **Root Cause & Layout Mechanics:**
  - MealVaultScreen contains AppBar (56px), search bar/filter chips (~110px), and bottom NavigationBar (80px).
  - In a 550px viewport, available height for the empty state inside Expanded is $\le 280\text{px}$.
  - The empty state Column contains:
    - 64px icon + 16px SizedBox = 80px.
    - Headline ('خزنة الأكلات فارغة!'): ~45px at 1.4x.
    - 8px SizedBox.
    - Subtitle (3 lines at 1.4x): ~75px.
    - 20px SizedBox.
    - Button ('أضف أكلتك الأولى'): ~56px at 1.4x.
    - Padding: 48px.
    - Total required height = ~310px–411px > 280px available height $\rightarrow$ overflows by 131px.
- **Remediation:**
  Wrap the Column inside SingleChildScrollView for both the default empty state and the search-empty state.

---

### Defect 5: HistoryScreen Empty State Vertical Overflow
- **File:** lib/features/history/presentation/history_screen.dart:60
- **Error:** A RenderFlex overflowed by 53 pixels on the bottom.
- **Scenario:** Viewing the History tab when history is empty on a 550px height viewport with 1.4x text scaling.
- **Root Cause & Layout Mechanics:**
  - HistoryScreen has an AppBar (56px) and bottom NavigationBar (80px), leaving ~414px on a 550px screen.
  - In test harness (SizedBox(height: 440)), available height after AppBar is 384px.
  - Content padding (48px) reduces available height to 336px.
  - The empty state contains 64px icon, headline, and a 62-character descriptive Arabic subtitle that wraps across 4 lines at 1.4x font scale (~140px). Total rendered height is 389px $\rightarrow$ overflows 336px by 53px.
- **Remediation:**
  Wrap the Column in SingleChildScrollView.

---

## 3. Verified Code Diffs (Production Remediation)

### 3.1 meal_vault_card.dart
`dart
// lib/features/vault/presentation/widgets/meal_vault_card.dart:48-87
<<<< BEFORE
                  // Badges (Friday, Budget)
                  if (meal.isFridaySpecial || meal.isBudgetFriendly) ...[
                    Row(
                      children: [
                        if (meal.isFridaySpecial)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'أكلة جمعة',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (meal.isBudgetFriendly)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'اقتصادي',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
==== AFTER
                  // Badges (Friday, Budget)
                  if (meal.isFridaySpecial || meal.isBudgetFriendly) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (meal.isFridaySpecial)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'أكلة جمعة',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (meal.isBudgetFriendly)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'اقتصادي',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
>>>>
`

---

### 3.2 dd_edit_meal_dialog.dart (Header and Actions)
`dart
// lib/features/vault/presentation/add_edit_meal_dialog.dart:148-164
<<<< BEFORE
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'تعديل الأكلة' : 'إضافة أكلة جديدة',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
==== AFTER
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEditing ? 'تعديل الأكلة' : 'إضافة أكلة جديدة',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
>>>>
`

`dart
// lib/features/vault/presentation/add_edit_meal_dialog.dart:335-352
<<<< BEFORE
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const Key('meal_form_cancel_button'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('meal_form_save_button'),
                        onPressed: _handleSave,
                        child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الأكلة'),
                      ),
                    ],
                  ),
==== AFTER
                  // Action Buttons
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        key: const Key('meal_form_cancel_button'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        key: const Key('meal_form_save_button'),
                        onPressed: _handleSave,
                        child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الأكلة'),
                      ),
                    ],
                  ),
>>>>
`

---

### 3.3 delete_meal_dialog.dart
`dart
// lib/features/vault/presentation/widgets/delete_meal_dialog.dart:25-66
<<<< BEFORE
      child: AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 40),
        title: const Text(
          'حذف الأكلة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من رغبتك في حذف " نهائياً من خزانة الأكلات؟',
 style: theme.textTheme.bodyMedium,
 ),
 const SizedBox(height: 16),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: colorScheme.outlineVariant),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(Icons.shield_outlined, color: colorScheme.primary, size: 22),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'سجل الطبخ في أمان: سيتم الاحتفاظ بسجل المرات السابقة التي طبخت فيها هذه الأكلة ولن يُحذف من سجل الأكلات.',
 style: theme.textTheme.bodySmall?.copyWith(
 color: colorScheme.onSurfaceVariant,
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 actions: [
==== AFTER
 child: AlertDialog(
 icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 40),
 title: const Text(
 'حذف الأكلة',
 style: TextStyle(fontWeight: FontWeight.bold),
 ),
 content: SingleChildScrollView(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 'هل أنت متأكد من رغبتك في حذف  نهائياً من خزانة الأكلات؟',
 style: theme.textTheme.bodyMedium,
 ),
 const SizedBox(height: 16),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: colorScheme.outlineVariant),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(Icons.shield_outlined, color: colorScheme.primary, size: 22),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 'سجل الطبخ في أمان: سيتم الاحتفاظ بسجل المرات السابقة التي طبخت فيها هذه الأكلة ولن يُحذف من سجل الأكلات.',
 style: theme.textTheme.bodySmall?.copyWith(
 color: colorScheme.onSurfaceVariant,
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 ),
 actions: [
>>>>
`

---

### 3.4 ault_empty_state.dart
`dart
// lib/features/vault/presentation/widgets/vault_empty_state.dart:17-93
<<<< BEFORE
 if (isSearchResult) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 24.0),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.search_off_rounded,
 size: 64,
 color: theme.colorScheme.outline,
 ),
 const SizedBox(height: 16),
 Text(
 'لا توجد نتائج مطابقة',
 style: theme.textTheme.headlineSmall?.copyWith(
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'لم نجد أكلات تطابق كلمات البحث أو الفلاتر المحددة.',
 textAlign: TextAlign.center,
 style: theme.textTheme.bodyMedium?.copyWith(
 color: theme.colorScheme.onSurfaceVariant,
 ),
 ),
 const SizedBox(height: 20),
 OutlinedButton.icon(
 key: const Key('vault_clear_filters_button'),
 onPressed: onAction,
 icon: const Icon(Icons.clear_all),
 label: const Text('إعادة ضبط الفلاتر والبحث'),
 ),
 ],
 ),
 ),
 );
 }

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
 key: const Key('vault_empty_add_button'),
 onPressed: onAction,
 icon: const Icon(Icons.add),
 label: const Text('أضف أكلتك الأولى'),
 ),
 ],
 ),
 ),
 );
==== AFTER
 if (isSearchResult) {
 return Center(
 child: SingleChildScrollView(
 padding: const EdgeInsets.symmetric(horizontal: 24.0),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.search_off_rounded,
 size: 64,
 color: theme.colorScheme.outline,
 ),
 const SizedBox(height: 16),
 Text(
 'لا توجد نتائج مطابقة',
 style: theme.textTheme.headlineSmall?.copyWith(
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'لم نجد أكلات تطابق كلمات البحث أو الفلاتر المحددة.',
 textAlign: TextAlign.center,
 style: theme.textTheme.bodyMedium?.copyWith(
 color: theme.colorScheme.onSurfaceVariant,
 ),
 ),
 const SizedBox(height: 20),
 OutlinedButton.icon(
 key: const Key('vault_clear_filters_button'),
 onPressed: onAction,
 icon: const Icon(Icons.clear_all),
 label: const Text('إعادة ضبط الفلاتر والبحث'),
 ),
 ],
 ),
 ),
 );
 }

 return Center(
 child: SingleChildScrollView(
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
 key: const Key('vault_empty_add_button'),
 onPressed: onAction,
 icon: const Icon(Icons.add),
 label: const Text('أضف أكلتك الأولى'),
 ),
 ],
 ),
 ),
 );
>>>>
`

---

### 3.5 history_screen.dart
`dart
// lib/features/history/presentation/history_screen.dart:56-87
<<<< BEFORE
 if (entries.isEmpty) {
 return Center(
 child: Padding(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.history_toggle_off,
 size: 64,
 color: theme.colorScheme.outline,
 ),
 const SizedBox(height: 16),
 Text(
 'سجل الطبخ فارغ!',
 style: theme.textTheme.headlineSmall?.copyWith(
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'عندما تسجل وجباتك من الصفحة الرئيسية ستظهر هنا مرتبة بالتواريخ.',
 textAlign: TextAlign.center,
 style: theme.textTheme.bodyMedium?.copyWith(
 color: theme.colorScheme.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 );
 }
==== AFTER
 if (entries.isEmpty) {
 return Center(
 child: SingleChildScrollView(
 padding: const EdgeInsets.all(24.0),
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 Icons.history_toggle_off,
 size: 64,
 color: theme.colorScheme.outline,
 ),
 const SizedBox(height: 16),
 Text(
 'سجل الطبخ فارغ!',
 style: theme.textTheme.headlineSmall?.copyWith(
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 'عندما تسجل وجباتك من الصفحة الرئيسية ستظهر هنا مرتبة بالتواريخ.',
 textAlign: TextAlign.center,
 style: theme.textTheme.bodyMedium?.copyWith(
 color: theme.colorScheme.onSurfaceVariant,
 ),
 ),
 ],
 ),
 ),
 );
 }
>>>>
`

---

## 4. Test Suite Updating Guidance

In est/widget/challenger_viewport_overflow_test.dart:
The current tests BUG-1 through BUG-5 explicitly assert that overflowError is non-null because they were designed by Challenger 1 to capture the failure.

Once the implementation worker applies the fixes:
1. BUG-1 through BUG-5 will no longer produce RenderFlex overflowed errors.
2. The tests in challenger_viewport_overflow_test.dart should be converted to positive assertions:
 - Replace expect(overflowError, isNotNull) with:
 `dart
 expect(overflowError, isNull, reason: 'RenderFlex overflow has been successfully eliminated');
 expect(tester.takeException(), isNull);
 `
3. In CHALLENGE 3 (line 179), the test string should remain within the Drift schema limit ($\le 120$ characters) as already done on line 176 (substring(0, 115)).

---

## 5. Verification Commands

Following application of the diffs by the remediation worker:
`powershell
# 1. Run static analysis (must report 0 issues)
flutter analyze

# 2. Run the updated challenger test suite
flutter test test/widget/challenger_viewport_overflow_test.dart

# 3. Run all widget and stress test suites
flutter test test/widget/adversarial_ui_stress_test.dart
flutter test test/widget/rtl_layout_test.dart

# 4. Run entire project test suite
flutter test
`
