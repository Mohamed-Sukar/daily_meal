import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/admin_auth_service.dart';
import '../data/models/cloud_meal.dart';
import '../data/vault_admin_repository.dart';
import 'widgets/add_meal_dialog.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'all';

  final _categories = const [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'tabeekh', 'label': 'طبيخ'},
    {'key': 'casserole', 'label': 'صواني'},
    {'key': 'dry_sandwich', 'label': 'نواشف'},
    {'key': 'popular', 'label': 'شعبي'},
    {'key': 'seafood', 'label': 'بحريات'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddMealDialog([CloudMeal? meal]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddMealDialog(initialMeal: meal),
    );
  }

  void _confirmDelete(CloudMeal meal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف الأكلة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف "${meal.name}" من الخزنة العامة؟',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(vaultAdminRepositoryProvider).deleteVaultMeal(meal.id);
            },
            child: Text('حذف', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _approveStaging(CloudMeal stagingMeal) async {
    await ref.read(vaultAdminRepositoryProvider).approveStagingMeal(stagingMeal);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم اعتماد "${stagingMeal.name}" وإضافتها للخزنة!')),
      );
    }
  }

  void _rejectStaging(CloudMeal stagingMeal) async {
    await ref.read(vaultAdminRepositoryProvider).rejectStagingMeal(stagingMeal.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم رفض مقترح "${stagingMeal.name}".')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).value;
    final vaultMealsAsync = ref.watch(vaultMealsStreamProvider);
    final stagingMealsAsync = ref.watch(stagingMealsStreamProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'لوحة تحكم خزانة الأكلات (Admin)',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      user.email ?? 'المشرف',
                      style: GoogleFonts.cairo(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => ref.read(adminAuthProvider).signOut(),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory_2_outlined),
              text: 'أكلات الخزنة المعتمدة (${vaultMealsAsync.value?.length ?? 0})',
            ),
            Tab(
              icon: const Icon(Icons.pending_actions_rounded),
              text: 'مقترحات قيد المراجعة (${stagingMealsAsync.value?.length ?? 0})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Vault Meals
          _buildVaultTab(vaultMealsAsync, theme),

          // Tab 2: Staging Meals
          _buildStagingTab(stagingMealsAsync, theme),
        ],
      ),
    );
  }

  Widget _buildVaultTab(AsyncValue<List<CloudMeal>> mealsAsync, ThemeData theme) {
    return mealsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'تعذر جلب الأكلات من Firestore:\n$err',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(),
              ),
              const SizedBox(height: 16),
              Text(
                'تأكد من تفعيل Cloud Firestore في Firebase Console',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      data: (meals) {
        final filteredMeals = meals.where((m) {
          final matchesSearch =
              m.name.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesCat =
              _selectedCategory == 'all' || m.category == _selectedCategory;
          return matchesSearch && matchesCat;
        }).toList();

        return Column(
          children: [
            // Controls header
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث عن أكلة في الخزنة...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _openAddMealDialog(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      'إضافة أكلة جديدة',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),

            // Category Chips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((c) {
                    final isSelected = _selectedCategory == c['key'];
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(c['label']!, style: GoogleFonts.cairo()),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = c['key']!;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const Divider(height: 1),

            // Meals List / Grid
            Expanded(
              child: filteredMeals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fastfood_outlined,
                            size: 64,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            meals.isEmpty
                                ? 'لا توجد أكلات في الخزنة حتى الآن.\nاضغط "إضافة أكلة جديدة" لإضافة أكلة.'
                                : 'لا توجد نتائج تطابق بحثك.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredMeals.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final meal = filteredMeals[index];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Meal Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: meal.imageUrl != null &&
                                          meal.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          meal.imageUrl!,
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              Container(
                                            width: 72,
                                            height: 72,
                                            color: theme.colorScheme
                                                .surfaceContainerHigh,
                                            child: const Icon(
                                                Icons.restaurant_rounded),
                                          ),
                                        )
                                      : Container(
                                          width: 72,
                                          height: 72,
                                          color: theme.colorScheme
                                              .surfaceContainerHigh,
                                          child: const Icon(
                                              Icons.restaurant_rounded),
                                        ),
                                ),
                                const SizedBox(width: 16),

                                // Meal Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            meal.name,
                                            style: GoogleFonts.cairo(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (meal.isFridaySpecial)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'جمعة',
                                                style: GoogleFonts.cairo(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber.shade900,
                                                ),
                                              ),
                                            ),
                                          if (meal.isBudgetFriendly) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'اقتصادي',
                                                style: GoogleFonts.cairo(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (meal.isStarterMeal) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.teal.shade300,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.stars_rounded,
                                                      size: 11,
                                                      color: Colors
                                                          .teal.shade700),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'وجبة أساسية',
                                                    style: GoogleFonts.cairo(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.teal.shade900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          _badge(
                                              'التصنيف: ${_translateCategory(meal.category)}',
                                              theme),
                                          _badge(
                                              'البروتين: ${_translateProtein(meal.proteinType)}',
                                              theme),
                                          _badge(
                                              'النشويات: ${_translateCarbs(meal.carbsType)}',
                                              theme),
                                          _badge(
                                              '⏱️ ${meal.prepTimeMinutes} دقيقة',
                                              theme),
                                        ],
                                      ),
                                      if (meal.notes != null &&
                                          meal.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          meal.notes!,
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Actions
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'تعديل',
                                      onPressed: () => _openAddMealDialog(meal),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'حذف من الخزنة',
                                      onPressed: () => _confirmDelete(meal),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStagingTab(AsyncValue<List<CloudMeal>> stagingAsync, ThemeData theme) {
    return stagingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('خطأ في جلب المقترحات: $err', style: GoogleFonts.cairo()),
      ),
      data: (stagingMeals) {
        if (stagingMeals.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد مقترحات معلقة حالياً!',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أي أكلة يقترحها المستخدمون ستظهر هنا لتراجعها وتعتمدها.',
                  style: GoogleFonts.cairo(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: stagingMeals.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final meal = stagingMeals[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                meal.name,
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'مقترح جديد',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              _badge('التصنيف: ${_translateCategory(meal.category)}', theme),
                              _badge('البروتين: ${_translateProtein(meal.proteinType)}', theme),
                              _badge('⏱️ ${meal.prepTimeMinutes} دقيقة', theme),
                            ],
                          ),
                          if (meal.notes != null && meal.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'ملاحظات المستخدم: ${meal.notes}',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _approveStaging(meal),
                          icon: const Icon(Icons.check_rounded),
                          label: Text('اعتماد ونشر', style: GoogleFonts.cairo()),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _rejectStaging(meal),
                          icon: const Icon(Icons.close_rounded, color: Colors.red),
                          label: Text(
                            'رفض',
                            style: GoogleFonts.cairo(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _badge(String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(fontSize: 12),
      ),
    );
  }

  String _translateCategory(String cat) {
    switch (cat) {
      case 'tabeekh':
        return 'طبيخ';
      case 'casserole':
        return 'صواني فرن';
      case 'dry_sandwich':
        return 'نواشف';
      case 'popular':
        return 'شعبي';
      case 'seafood':
        return 'بحريات';
      default:
        return cat;
    }
  }

  String _translateProtein(String p) {
    switch (p) {
      case 'chicken':
        return 'فراخ';
      case 'beef':
        return 'لحمة';
      case 'fish':
        return 'سمك';
      case 'meatless':
        return 'أرديحي';
      default:
        return 'أخرى';
    }
  }

  String _translateCarbs(String c) {
    switch (c) {
      case 'rice':
        return 'أرز';
      case 'pasta':
        return 'مكرونة';
      case 'bread':
        return 'عيش';
      default:
        return 'بدون';
    }
  }
}
