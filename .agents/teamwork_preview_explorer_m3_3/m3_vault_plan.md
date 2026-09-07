# Milestone 3 — Meal Vault UI & Riverpod State Blueprint
**Identity:** `teamwork_preview_explorer_m3_3`  
**Working Directory:** `E:\Mohamed\Personal_Project\daily-meal\daily_meal\.agents\teamwork_preview_explorer_m3_3`  
**Date:** 2026-09-07  
**Scope:** Meal Vault Screen (`meal_vault_screen.dart`), Search & Multi-Criteria Filters, Add/Edit Meal Form Dialog (`add_edit_meal_dialog.dart`), Meal Deletion & Foreign Key Cascade Flow (`delete_meal_dialog.dart`), and Riverpod State Management (`vault_providers.dart`).

---

## 1. Executive Summary & Architectural Overview

The **Meal Vault** (خزانة الأكلات) serves as the persistent catalog and central knowledge base for "أكلة النهاردة". It empowers users to browse, search, filter, customize, add, edit, and delete authentic Egyptian meals. Every modification in the Vault directly feeds the Cooldown Recommendation Engine on the Home Screen via Riverpod unidirectional reactive streams.

### Core Architectural Principles:
1. **Unidirectional Reactive Data Flow**:
   - The database (`MealsDao.watchAllMeals()`) is the single source of truth.
   - Any mutation (Insert, Update, Delete, Toggle Favorite) writes to SQLite via Drift.
   - Drift automatically emits the updated `List<Meal>` stream to `allMealsProvider`.
   - `filteredMealsProvider` reacts immediately to update the Vault UI with zero manual refresh or duplicate state caching.
   - In parallel, `todayRecommendationsProvider` recalculates recommendations on the Home Screen automatically.
2. **Foreign Key Integrity & History Preservation (`KeyAction.setNull`)**:
   - In SQLite, the `meal_history` table defines `meal_id` with `ON DELETE SET NULL` and snapshot fields (`meal_name`, `protein_type`, `carbs_type`, `cooked_at`).
   - When a meal is deleted from the Vault, past cooking logs remain intact for statistics and fatigue calculations.
   - The deletion confirmation dialog explicitly reassures the user in clear Arabic that their cooking history will not be lost.
3. **Arabic RTL & Egyptian Culinary Ergonomics**:
   - Designed exclusively for Right-to-Left (RTL) flow (`TextDirection.rtl`).
   - Localized prep time formatting: `formatPrepTime(minutes)` (e.g. `5 دقائق` vs `45 دقيقة`).
   - Egyptian culinary categories and tags: "طبيخ ومسبك", "طواجن وصواني فرن", "سريع وسندوتشات / نواشف", "أسماك وبحريات", "شوربات ويخنات", "نباتي / قرديحي", "أكلة جمعة", "على قد الإيد".

---

## 2. File & Directory Layout

Following `PROJECT.md` specifications, the Vault feature lives cleanly inside `lib/features/vault/`:

```text
lib/features/vault/
├── presentation/
│   ├── add_edit_meal_dialog.dart           # Add / Edit Meal Form Modal
│   ├── meal_vault_screen.dart              # Main Vault Screen
│   └── widgets/
│       ├── delete_meal_dialog.dart         # Safe Deletion Confirmation Dialog
│       ├── meal_vault_card.dart            # Meal Card with actions & badges
│       ├── vault_empty_state.dart          # Empty search / Empty vault view
│       ├── vault_filter_bar.dart           # Search & filter chips bar
│       └── vault_image_picker_widget.dart  # Meal photo selector/thumbnail
└── providers/
    └── vault_providers.dart                # Riverpod Notifiers, Filter State, Streams
```

---

## 3. Riverpod State Architecture (`vault_providers.dart`)

### 3.1. Filter State Model
The filter state encapsulates all user criteria: free-text search, protein category, carbohydrate category, meal category, and boolean flags.

```dart
// lib/features/vault/providers/vault_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../core/providers/database_providers.dart'; // From M3_1: databaseProvider, mealsDaoProvider

class VaultFilterState {
  final String searchQuery;
  final ProteinType? selectedProtein;
  final CarbsType? selectedCarbs;
  final MealCategory? selectedCategory;
  final bool filterFridayOnly;
  final bool filterBudgetOnly;
  final bool filterFavoriteOnly;

  const VaultFilterState({
    this.searchQuery = '',
    this.selectedProtein,
    this.selectedCarbs,
    this.selectedCategory,
    this.filterFridayOnly = false,
    this.filterBudgetOnly = false,
    this.filterFavoriteOnly = false,
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      selectedProtein != null ||
      selectedCarbs != null ||
      selectedCategory != null ||
      filterFridayOnly ||
      filterBudgetOnly ||
      filterFavoriteOnly;

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.trim().isNotEmpty) count++;
    if (selectedProtein != null) count++;
    if (selectedCarbs != null) count++;
    if (selectedCategory != null) count++;
    if (filterFridayOnly) count++;
    if (filterBudgetOnly) count++;
    if (filterFavoriteOnly) count++;
    return count;
  }

  VaultFilterState copyWith({
    String? searchQuery,
    ProteinType? selectedProtein,
    CarbsType? selectedCarbs,
    MealCategory? selectedCategory,
    bool? filterFridayOnly,
    bool? filterBudgetOnly,
    bool? filterFavoriteOnly,
    bool clearProtein = false,
    bool clearCarbs = false,
    bool clearCategory = false,
  }) {
    return VaultFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedProtein: clearProtein ? null : (selectedProtein ?? this.selectedProtein),
      selectedCarbs: clearCarbs ? null : (selectedCarbs ?? this.selectedCarbs),
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      filterFridayOnly: filterFridayOnly ?? this.filterFridayOnly,
      filterBudgetOnly: filterBudgetOnly ?? this.filterBudgetOnly,
      filterFavoriteOnly: filterFavoriteOnly ?? this.filterFavoriteOnly,
    );
  }
}
```

### 3.2. Filter State Notifier
```dart
class VaultFilterNotifier extends Notifier<VaultFilterState> {
  @override
  VaultFilterState build() => const VaultFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleProtein(ProteinType protein) {
    if (state.selectedProtein == protein) {
      state = state.copyWith(clearProtein: true);
    } else {
      state = state.copyWith(selectedProtein: protein);
    }
  }

  void toggleCarbs(CarbsType carbs) {
    if (state.selectedCarbs == carbs) {
      state = state.copyWith(clearCarbs: true);
    } else {
      state = state.copyWith(selectedCarbs: carbs);
    }
  }

  void toggleCategory(MealCategory category) {
    if (state.selectedCategory == category) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  void toggleFridayFilter() {
    state = state.copyWith(filterFridayOnly: !state.filterFridayOnly);
  }

  void toggleBudgetFilter() {
    state = state.copyWith(filterBudgetOnly: !state.filterBudgetOnly);
  }

  void toggleFavoriteFilter() {
    state = state.copyWith(filterFavoriteOnly: !state.filterFavoriteOnly);
  }

  void resetFilters() {
    state = const VaultFilterState();
  }
}

final vaultFilterProvider = NotifierProvider<VaultFilterNotifier, VaultFilterState>(
  () => VaultFilterNotifier(),
);
```

### 3.3. Vault Stream & Derived Filtered Meals Providers
```dart
/// Watches all meals directly from SQLite via MealsDao
final allMealsProvider = StreamProvider<List<Meal>>((ref) {
  final mealsDao = ref.watch(mealsDaoProvider);
  return mealsDao.watchAllMeals();
});

/// Reactive filtered meals provider for the Vault UI
final filteredMealsProvider = Provider<AsyncValue<List<Meal>>>((ref) {
  final allMealsAsync = ref.watch(allMealsProvider);
  final filter = ref.watch(vaultFilterProvider);

  return allMealsAsync.whenData((meals) {
    return meals.where((meal) {
      // 1. Search Query (Name matching, case/whitespace insensitive)
      if (filter.searchQuery.trim().isNotEmpty) {
        final query = filter.searchQuery.trim().toLowerCase();
        if (!meal.name.toLowerCase().contains(query)) {
          return false;
        }
      }

      // 2. Protein Filter
      if (filter.selectedProtein != null && meal.proteinType != filter.selectedProtein) {
        return false;
      }

      // 3. Carbs Filter
      if (filter.selectedCarbs != null && meal.carbsType != filter.selectedCarbs) {
        return false;
      }

      // 4. Category Filter
      if (filter.selectedCategory != null && meal.category != filter.selectedCategory) {
        return false;
      }

      // 5. Boolean Tag Filters
      if (filter.filterFridayOnly && !meal.isFridaySpecial) {
        return false;
      }
      if (filter.filterBudgetOnly && !meal.isBudgetFriendly) {
        return false;
      }
      if (filter.filterFavoriteOnly && !meal.isFavorite) {
        return false;
      }

      return true;
    }).toList();
  });
});
```

### 3.4. Vault Controller (CRUD Mutations)
```dart
class VaultController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  MealsDao get _mealsDao => ref.read(mealsDaoProvider);

  /// Add new meal to SQLite
  Future<int> addMeal(MealsCompanion meal) async {
    state = const AsyncValue.loading();
    try {
      final id = await _mealsDao.insertMeal(meal);
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update existing meal
  Future<bool> updateMeal(Meal meal) async {
    state = const AsyncValue.loading();
    try {
      final success = await _mealsDao.updateMeal(meal);
      state = const AsyncValue.data(null);
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete meal by ID (History entries automatically nullify meal_id)
  Future<int> deleteMeal(int id) async {
    state = const AsyncValue.loading();
    try {
      final rows = await _mealsDao.deleteMeal(id);
      state = const AsyncValue.data(null);
      return rows;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(int id, bool currentStatus) async {
    try {
      await _mealsDao.toggleFavorite(id, currentStatus);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final vaultControllerProvider = NotifierProvider<VaultController, AsyncValue<void>>(
  () => VaultController(),
);
```

---

## 4. Meal Vault Screen (`meal_vault_screen.dart`)

### 4.1. Visual Layout & Specifications
- **AppBar**:
  - Title: `"خزانة الأكلات"`
  - Counter Badge in subtitle or action chip: e.g. `"${meals.length} أكلة مسجلة"`
  - Directionality: RTL.
- **Search Bar**:
  - Rounded Material 3 search bar with `Key('vault_search_field')`.
  - Leading search icon `Icon(Icons.search)`.
  - Hint text: `"ابحث عن أكلة بالاسم..."`.
  - Trailing clear icon when text is entered: `IconButton(icon: Icon(Icons.clear))` that clears the search controller and provider.
- **Filter Chips Bar (`VaultFilterBar`)**:
  - Three categorized rows or horizontally scrolling chip groups:
    1. **نوع البروتين (Protein)**:
       - Chips: `الكل`, `لحوم`, `دواجن`, `أسماك`, `نباتي`, `بيض / جبن`, `أخرى`.
       - Mapping to `ProteinType`:
         - لحوم -> `ProteinType.beef`
         - دواجن -> `ProteinType.chicken`
         - أسماك -> `ProteinType.fish`
         - نباتي -> `ProteinType.legume`
         - بيض / جبن -> `ProteinType.dairy`
         - أخرى -> `ProteinType.none`
    2. **نوع النشويات (Carbs)**:
       - Chips: `الكل`, `أرز`, `مكرونة`, `عيش`, `بطاطس`, `بدون نشويات`.
       - Mapping to `CarbsType`:
         - أرز -> `CarbsType.rice`
         - مكرونة -> `CarbsType.pasta`
         - عيش -> `CarbsType.bread`
         - بطاطس -> `CarbsType.potato`
         - بدون -> `CarbsType.none`
    3. **التصنيفات والسمات (Tags & Flags)**:
       - `جمعة` (Friday Special, icon: `Icons.star_rounded` or `Icons.mosque`)
       - `اقتصادي` (Budget Friendly, icon: `Icons.savings_outlined`)
       - `المفضلة` (Favorite Only, icon: `Icons.favorite_rounded`)
    - **Reset Action**: When `filter.hasActiveFilters` is true, an animated "مسح الفلاتر (${filter.activeFilterCount})" chip appears in destructive/secondary outline to reset all criteria with a single tap.
- **Meal List View**:
  - Reactive `ListView.separated` wrapped in `RefreshIndicator` or `AnimatedSwitcher`.
  - Renders `MealVaultCard` for each meal.
- **FloatingActionButton**:
  - Key: `Key('vault_add_fab')`
  - Extended FAB with icon `Icon(Icons.add)` and label `"إضافة أكلة"`.
  - Opens `AddEditMealDialog` in creation mode.

### 4.2. Empty State Handling (`VaultEmptyState`)
The empty state handles two distinct scenarios with polished Arabic copy:
1. **Scenario 1: Vault has 0 meals in total (New user / Fresh DB)**:
   - Icon: `Icon(Icons.soup_kitchen_outlined, size: 72, color: colorScheme.outline)`
   - Title: `"خزنة الأكلات فارغة!"` *(Matches `rtl_layout_test.dart` assertion exactly!)*
   - Subtitle: `"ابدأ بإضافة أول أكلة أو حمّل الأكلات المقترحة."`
   - Primary Button: `"أضف أكلتك الأولى"` with `Key('vault_empty_add_button')`, opening `AddEditMealDialog`.
2. **Scenario 2: Active search/filters return 0 matching results**:
   - Icon: `Icon(Icons.search_off_rounded, size: 64, color: colorScheme.outline)`
   - Title: `"لا توجد نتائج مطابقة"`
   - Subtitle: `"لم نجد أكلات تطابق كلمات البحث أو الفلاتر المحددة."`
   - Secondary Button: `"إعادة ضبط الفلاتر والبحث"` with `Key('vault_clear_filters_button')`, calling `ref.read(vaultFilterProvider.notifier).resetFilters()`.

---

## 5. Meal Vault Card Specification (`meal_vault_card.dart`)

Each meal card provides immediate visual context, tags, and three clear action buttons: Favorite Toggle, Edit, and Delete.

### 5.1. Card Elements
1. **Image Thumbnail / Themed Placeholder (`MealThumbnail`)**:
   - Width: 72dp, Height: 72dp, Border Radius: 12dp.
   - If `meal.photoPath != null` and points to a valid file: displays `Image.file(File(meal.photoPath!))` with graceful fallback.
   - Otherwise, displays a themed container (`colorScheme.primaryContainer`) with an Egyptian culinary icon corresponding to `meal.category`:
     - `MealCategory.egyptianTraditional` -> `Icons.soup_kitchen`
     - `MealCategory.ovenBaked` -> `Icons.microwave` / `Icons.dining`
     - `MealCategory.fastFood` -> `Icons.lunch_dining`
     - `MealCategory.seafood` -> `Icons.set_meal`
     - `MealCategory.soupStew` -> `Icons.ramen_dining`
     - `MealCategory.vegetarian` -> `Icons.eco`
2. **Meal Title**:
   - Bold text (`titleMedium`, `FontWeight.bold`), max 2 lines with `TextOverflow.ellipsis`.
   - Adapts to long Arabic titles without overflow (tested against `T2.1` in `rtl_layout_test.dart`).
3. **Prep Time Badge**:
   - Localized Arabic format matching `PROJECT.md` and test suite:
     ```dart
     String formatPrepTime(int minutes) {
       if (minutes <= 10) {
         return '$minutes دقائق';
       } else {
         return '$minutes دقيقة';
       }
     }
     ```
   - Rendered with `Icon(Icons.timer_outlined, size: 14)`.
4. **Category & Ingredient Tags**:
   - Category chip (e.g. `طواجن وصواني`, `طبيخ ومسبك`).
   - Protein chip (e.g. `لحمة`, `فراخ`).
   - Carbs chip (e.g. `أرز`, `مكرونة`).
   - Friday badge: if `meal.isFridaySpecial`, displays amber chip with `"جمعة"`.
   - Budget badge: if `meal.isBudgetFriendly`, displays green chip with `"اقتصادي"`.
5. **Action Buttons (RTL Order)**:
   - **Favorite Toggle**:
     - `IconButton(key: Key('meal_favorite_button_${meal.id}'))`
     - Icon: `meal.isFavorite ? Icon(Icons.favorite, color: Colors.redAccent) : Icon(Icons.favorite_border)`
     - Handler: `ref.read(vaultControllerProvider.notifier).toggleFavorite(meal.id, meal.isFavorite)`.
   - **Edit Button**:
     - `IconButton(key: Key('meal_edit_button_${meal.id}'), icon: Icon(Icons.edit_outlined))`
     - Handler: Opens `AddEditMealDialog(mealToEdit: meal)`.
   - **Delete Button**:
     - `IconButton(key: Key('meal_delete_button_${meal.id}'), icon: Icon(Icons.delete_outline, color: colorScheme.error))`
     - Handler: Opens `DeleteMealDialog(meal: meal)`.

---

## 6. Add / Edit Meal Modal Form (`add_edit_meal_dialog.dart`)

The Add/Edit modal is implemented as a scrollable `Dialog` or full modal bottom sheet that adapts seamlessly across phone screens and prevents keyboard overlap.

### 6.1. Form Fields & State
- **Form Key**: `final _formKey = GlobalKey<FormState>();`
- **Fields Specification Table**:

| Field | Widget Type | Required? | Initial Value (Edit Mode) | Validation Rules & Arabic Errors | Key |
|-------|-------------|-----------|---------------------------|-----------------------------------|-----|
| **اسم الأكلة (Name)** | `TextFormField` | نعم (Yes) | `mealToEdit?.name ?? ''` | 1. Empty check: `"من فضلك أدخل اسم الأكلة"`<br>2. Min 2 chars: `"اسم الأكلة يجب أن يكون حرفين على الأقل"`<br>3. Max 120 chars: `maxLength: 120` | `Key('meal_form_name_field')` |
| **التصنيف (Category)** | `DropdownButtonFormField<MealCategory>` | نعم (Yes) | `mealToEdit?.category ?? MealCategory.egyptianTraditional` | Must be selected: `"من فضلك اختر تصنيف الأكلة"` | `Key('meal_form_category_dropdown')` |
| **نوع البروتين (Protein)** | `DropdownButtonFormField<ProteinType>` | نعم (Yes) | `mealToEdit?.proteinType ?? ProteinType.beef` | Must be selected: `"من فضلك اختر نوع البروتين"` | `Key('meal_form_protein_dropdown')` |
| **نوع النشويات (Carbs)** | `DropdownButtonFormField<CarbsType>` | نعم (Yes) | `mealToEdit?.carbsType ?? CarbsType.rice` | Must be selected: `"من فضلك اختر نوع النشويات"` | `Key('meal_form_carbs_dropdown')` |
| **وقت التحضير (Prep Time)** | `TextFormField` (Number) | نعم (Yes) | `mealToEdit?.prepTime.toString() ?? '30'` | 1. Empty check: `"من فضلك أدخل وقت التحضير بالدقائق"`<br>2. Positive int: `int.tryParse(val) != null && val > 0` else `"يجب إدخال عدد صحيح أكبر من صفر"` | `Key('meal_form_prep_time_field')` |
| **مسار الصورة (Photo Path)** | `VaultImagePickerWidget` | اختياري (Optional) | `mealToEdit?.photoPath` | Optional valid local path or empty | `Key('meal_form_photo_picker')` |
| **أكلة خاصة بالجمعة** | `CheckboxListTile` / `SwitchListTile` | لا | `mealToEdit?.isFridaySpecial ?? false` | Boolean flag | `Key('meal_form_friday_checkbox')` |
| **أكلة اقتصادية** | `CheckboxListTile` / `SwitchListTile` | لا | `mealToEdit?.isBudgetFriendly ?? false` | Boolean flag | `Key('meal_form_budget_checkbox')` |
| **إضافة للمفضلة** | `CheckboxListTile` / `SwitchListTile` | لا | `mealToEdit?.isFavorite ?? false` | Boolean flag | `Key('meal_form_favorite_checkbox')` |

### 6.2. Egyptian Category & Ingredient Label Mapping
To ensure 100% adherence to both prompt terminology and Drift database enums:
```dart
Map<MealCategory, String> mealCategoryLabels = {
  MealCategory.egyptianTraditional: 'طبيخ ومسبك / شعبي ومحاشي',
  MealCategory.ovenBaked: 'صواني وطواجن فرن',
  MealCategory.fastFood: 'نواشف وسريع وسندوتشات',
  MealCategory.seafood: 'أسماك وبحريات',
  MealCategory.soupStew: 'شوربات ويخنات',
  MealCategory.vegetarian: 'قرديحي / نباتي',
};

Map<ProteinType, String> proteinTypeLabels = {
  ProteinType.beef: 'لحوم / مفروم',
  ProteinType.chicken: 'دواجن / فراخ',
  ProteinType.fish: 'أسماك وبحريات',
  ProteinType.legume: 'نباتي / بقوليات (عدس، كشري، فول)',
  ProteinType.dairy: 'بيض / أجبان',
  ProteinType.none: 'بدون بروتين / أخرى',
};

Map<CarbsType, String> carbsTypeLabels = {
  CarbsType.rice: 'أرز (مصري / بسمتي / صيادية)',
  CarbsType.pasta: 'مكرونة (صلصة / بشاميل)',
  CarbsType.bread: 'عيش (بلدي / شامي)',
  CarbsType.potato: 'بطاطس',
  CarbsType.grains: 'حبوب / فريك',
  CarbsType.none: 'بدون نشويات',
};
```

### 6.3. Form Save & Mutation Flow
```dart
Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  final name = _nameController.text.trim();
  final prepMinutes = int.parse(_prepTimeController.text.trim());
  final isEditing = widget.mealToEdit != null;

  try {
    if (isEditing) {
      final updatedMeal = widget.mealToEdit!.copyWith(
        name: name,
        category: _selectedCategory,
        proteinType: _selectedProtein,
        carbsType: _selectedCarbs,
        prepTime: prepMinutes,
        photoPath: Value(_photoPath),
        isFridaySpecial: _isFridaySpecial,
        isBudgetFriendly: _isBudgetFriendly,
        isFavorite: _isFavorite,
        updatedAt: DateTime.now(),
      );

      await ref.read(vaultControllerProvider.notifier).updateMeal(updatedMeal);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تعديل أكلة "$name" بنجاح'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final newCompanion = MealsCompanion(
        name: Value(name),
        category: Value(_selectedCategory),
        proteinType: Value(_selectedProtein),
        carbsType: Value(_selectedCarbs),
        prepTime: Value(prepMinutes),
        photoPath: _photoPath != null ? Value(_photoPath) : const Value.absent(),
        isFridaySpecial: Value(_isFridaySpecial),
        isBudgetFriendly: Value(_isBudgetFriendly),
        isFavorite: Value(_isFavorite),
      );

      await ref.read(vaultControllerProvider.notifier).addMeal(newCompanion);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت إضافة "$name" إلى خزانة الأكلات'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحفظ: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
```

---

## 7. Meal Deletion Flow & History Preservation (`delete_meal_dialog.dart`)

### 7.1. Foreign Key Cascade Mechanics
- In SQLite/Drift, the table definition is:
  ```dart
  IntColumn get mealId => integer().nullable().customConstraint('REFERENCES meals(id) ON DELETE SET NULL')();
  ```
- When a meal is deleted with `mealsDao.deleteMeal(meal.id)`:
  1. SQLite sets `meal_id = NULL` on all associated records in `meal_history`.
  2. The historical snapshot fields (`meal_name`, `protein_type`, `carbs_type`, `cooked_at`, `entry_type`) remain untouched.
  3. Cooldown math and history timeline can still display the meal's name and dietary category for fatigue protection!
- The user confirmation dialog explicitly communicates this benefit to eliminate fear of data loss.

### 7.2. Delete Dialog Structure
```dart
// lib/features/vault/presentation/widgets/delete_meal_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../providers/vault_providers.dart';

class DeleteMealDialog extends ConsumerWidget {
  final Meal meal;

  const DeleteMealDialog({super.key, required this.meal});

  static Future<bool?> show(BuildContext context, Meal meal) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => DeleteMealDialog(meal: meal),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
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
              'هل أنت متأكد من رغبتك في حذف "${meal.name}" نهائياً من خزانة الأكلات؟',
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
          TextButton(
            key: const Key('meal_delete_cancel_button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('meal_delete_confirm_button'),
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () async {
              await ref.read(vaultControllerProvider.notifier).deleteMeal(meal.id);
              if (context.mounted) {
                Navigator.of(context).pop(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حذف "${meal.name}" مع الاحتفاظ بسجل طبخها السابق'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('حذف الأكلة'),
          ),
        ],
      ),
    );
  }
}
```

---

## 8. Widget Tree Hierarchy

```text
MealVaultScreen (ConsumerWidget)
└── Directionality (textDirection: TextDirection.rtl)
    └── Scaffold
        ├── AppBar
        │   ├── Title: "خزانة الأكلات"
        │   └── Subtitle / Badge: "${totalMeals} أكلة"
        ├── Body: Column
        │   ├── VaultSearchBar
        │   │   └── SearchBar (TextField with Key: 'vault_search_field')
        │   ├── VaultFilterBar
        │   │   ├── Protein FilterChips Row ('vault_protein_filter_chip_*')
        │   │   ├── Carbs FilterChips Row ('vault_carbs_filter_chip_*')
        │   │   └── Tag FilterChips Row ('vault_tag_filter_chip_*')
        │   └── Expanded
        │       └── filteredMeals.when(
        │           ├── loading: Center(CircularProgressIndicator)
        │           ├── error: ErrorWidget
        │           └── data:
        │               ├── if empty & no active filters -> VaultEmptyState (DB empty)
        │               ├── if empty & active filters -> VaultEmptyState (No search match)
        │               └── if has meals -> ListView.builder
        │                   └── MealVaultCard(meal)
        │                       ├── MealThumbnail
        │                       ├── MealDetails (Name, Prep Time, Tags)
        │                       └── ActionButtons Row
        │                           ├── FavoriteIconButton
        │                           ├── EditIconButton
        │                           └── DeleteIconButton
        └── FloatingActionButton (Key: 'vault_add_fab')
            └── opens AddEditMealDialog
```

---

## 9. Comprehensive Key & Test Contract Table

The following Keys are strictly guaranteed for widget testing and E2E automation:

| Component | Target Key | Usage |
|---|---|---|
| **Search Input** | `Key('vault_search_field')` | Entering search queries in Vault screen |
| **Clear Search** | `Key('vault_search_clear_button')` | Clearing search input |
| **Add Meal FAB** | `Key('vault_add_fab')` | FloatingActionButton to add a meal |
| **Empty State Add Button** | `Key('vault_empty_add_button')` | "أضف أكلتك الأولى" button in empty state |
| **Reset Filters Button** | `Key('vault_clear_filters_button')` | Resetting all active filters |
| **Meal Vault Card** | `Key('meal_card_${meal.id}')` | Individual meal card container |
| **Favorite Toggle** | `Key('meal_favorite_button_${meal.id}')` | Heart button on meal card |
| **Edit Meal Button** | `Key('meal_edit_button_${meal.id}')` | Edit pencil icon on meal card |
| **Delete Meal Button** | `Key('meal_delete_button_${meal.id}')` | Trash icon on meal card |
| **Delete Confirm** | `Key('meal_delete_confirm_button')` | Confirm deletion in modal dialog |
| **Delete Cancel** | `Key('meal_delete_cancel_button')` | Cancel deletion in modal dialog |
| **Form Name Field** | `Key('meal_form_name_field')` | TextFormField for meal name |
| **Form Prep Time Field** | `Key('meal_form_prep_time_field')` | TextFormField for prep minutes |
| **Form Category Dropdown** | `Key('meal_form_category_dropdown')` | DropdownButtonFormField for Category |
| **Form Protein Dropdown** | `Key('meal_form_protein_dropdown')` | DropdownButtonFormField for Protein |
| **Form Carbs Dropdown** | `Key('meal_form_carbs_dropdown')` | DropdownButtonFormField for Carbs |
| **Form Friday Checkbox** | `Key('meal_form_friday_checkbox')` | SwitchListTile for Friday special |
| **Form Budget Checkbox** | `Key('meal_form_budget_checkbox')` | SwitchListTile for Budget friendly |
| **Form Favorite Checkbox** | `Key('meal_form_favorite_checkbox')` | SwitchListTile for Favorite |
| **Form Save Button** | `Key('meal_form_save_button')` | FilledButton to submit add/edit form |
| **Form Cancel Button** | `Key('meal_form_cancel_button')` | TextButton to cancel dialog |

---

## 10. Verification & Quality Assurance Strategy

1. **Reactivity Verification**:
   - When a meal is added via `AddEditMealDialog`, Drift triggers `watchAllMeals()`.
   - `filteredMealsProvider` emits the new list within the same frame loop.
   - The Vault list updates immediately without needing to pop and re-enter the tab.
   - `test/widget/riverpod_reactivity_test.dart` passes (R4.1, R4.4).
2. **Layout & RTL Compliance**:
   - Directionality set to `TextDirection.rtl`.
   - Empty state matches `rtl_layout_test.dart` (text `"خزنة الأكلات فارغة!"`).
   - Prep time matches `formatPrepTime(minutes)` (e.g. `5 دقائق`, `45 دقيقة`).
   - Long title stress test does not cause `RenderFlex` overflow.
3. **Data Integrity on Deletion**:
   - `MealsDao.deleteMeal(id)` deletes the row from `meals`.
   - Drift and SQLite foreign key trigger sets `meal_id` in `meal_history` to `NULL`.
   - History logs remain visible in History tab.
   - Cooldown engine continues to respect history snapshots.

---

## 11. Worker Execution Checklist

When implementing Milestone 3 Vault components:
- [ ] Create `lib/features/vault/providers/vault_providers.dart` with `VaultFilterState`, `VaultFilterNotifier`, `allMealsProvider`, `filteredMealsProvider`, and `VaultController`.
- [ ] Create `lib/features/vault/presentation/widgets/vault_empty_state.dart` handling both 0-meal vault and 0-search match states.
- [ ] Create `lib/features/vault/presentation/widgets/vault_filter_bar.dart` with Protein, Carbs, and Tag filter chips.
- [ ] Create `lib/features/vault/presentation/widgets/meal_vault_card.dart` with thumbnail, badges, prep time, and action buttons.
- [ ] Create `lib/features/vault/presentation/widgets/delete_meal_dialog.dart` with clear history preservation messaging.
- [ ] Create `lib/features/vault/presentation/add_edit_meal_dialog.dart` with complete Egyptian categories, form validation, and Drift companion dispatch.
- [ ] Create `lib/features/vault/presentation/meal_vault_screen.dart` assembling the search bar, filter chips, reactive list, and "إضافة أكلة" FAB.
- [ ] Verify using `flutter test test/widget/rtl_layout_test.dart` and `test/widget/riverpod_reactivity_test.dart`.
