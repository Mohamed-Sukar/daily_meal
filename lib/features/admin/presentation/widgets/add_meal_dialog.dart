import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/cloud_meal.dart';
import '../../data/vault_admin_repository.dart';

class AddMealDialog extends ConsumerStatefulWidget {
  final CloudMeal? initialMeal;

  const AddMealDialog({super.key, this.initialMeal});

  @override
  ConsumerState<AddMealDialog> createState() => _AddMealDialogState();
}

class _AddMealDialogState extends ConsumerState<AddMealDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _prepTimeController;
  late final TextEditingController _notesController;

  late String _category;
  late String _proteinType;
  late String _carbsType;
  late bool _isFridaySpecial;
  late bool _isBudgetFriendly;
  late bool _isStarterMeal;

  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _isSaving = false;

  final _categories = const [
    {'key': 'tabeekh', 'label': 'طبيخ وخضار'},
    {'key': 'casserole', 'label': 'صواني وطواجن فرن'},
    {'key': 'dry_sandwich', 'label': 'نواشف وساندوتشات'},
    {'key': 'popular', 'label': 'أكل شعبي'},
    {'key': 'seafood', 'label': 'أسماك وبحريات'},
  ];

  final _proteins = const [
    {'key': 'chicken', 'label': 'فراخ / دواجن'},
    {'key': 'beef', 'label': 'لحوم حمراء'},
    {'key': 'fish', 'label': 'أسماك'},
    {'key': 'meatless', 'label': 'بدون لحوم (أرديحي)'},
    {'key': 'other', 'label': 'أخرى'},
  ];

  final _carbs = const [
    {'key': 'rice', 'label': 'أرز'},
    {'key': 'pasta', 'label': 'مكرونة'},
    {'key': 'bread', 'label': 'عيش / خبز'},
    {'key': 'none', 'label': 'بدون نشويات'},
  ];

  @override
  void initState() {
    super.initState();
    final meal = widget.initialMeal;
    _nameController = TextEditingController(text: meal?.name ?? '');
    _imageUrlController = TextEditingController(text: meal?.imageUrl ?? '');
    _prepTimeController = TextEditingController(
      text: (meal?.prepTimeMinutes ?? 30).toString(),
    );
    _notesController = TextEditingController(text: meal?.notes ?? '');

    _category = meal?.category ?? 'tabeekh';
    _proteinType = meal?.proteinType ?? 'chicken';
    _carbsType = meal?.carbsType ?? 'rice';
    _isFridaySpecial = meal?.isFridaySpecial ?? false;
    _isBudgetFriendly = meal?.isBudgetFriendly ?? false;
    _isStarterMeal = meal?.isStarterMeal ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
    _prepTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = file.name;
      });
    }
  }

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ref.read(vaultAdminRepositoryProvider);

      String? imageUrl = _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim();

      // If user picked a local file, upload it to Storage
      if (_pickedImageBytes != null && _pickedImageName != null) {
        final uploadedUrl = await repo.uploadMealImage(
          _pickedImageBytes!,
          _pickedImageName!,
        );
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        }
      }

      final mealToSave = CloudMeal(
        id: widget.initialMeal?.id ?? '',
        name: _nameController.text.trim(),
        imageUrl: imageUrl,
        category: _category,
        proteinType: _proteinType,
        carbsType: _carbsType,
        prepTimeMinutes: int.tryParse(_prepTimeController.text.trim()) ?? 30,
        isFridaySpecial: _isFridaySpecial,
        isBudgetFriendly: _isBudgetFriendly,
        isStarterMeal: _isStarterMeal,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: widget.initialMeal?.createdAt ?? DateTime.now(),
        status: 'approved',
      );

      if (widget.initialMeal == null) {
        await repo.addVaultMeal(mealToSave);
      } else {
        await repo.updateVaultMeal(mealToSave);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.initialMeal != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'تعديل أكلة في الخزنة' : 'إضافة أكلة جديدة للخزنة',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الأكلة *',
                          hintText: 'مثال: صينية بطاطس بالفراخ + أرز بالشعرية',
                          prefixIcon: Icon(Icons.restaurant_menu_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'يرجى إدخال اسم الأكلة' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'تصنيف الأكلة',
                                border: OutlineInputBorder(),
                              ),
                              items: _categories
                                  .map((c) => DropdownMenuItem(
                                        value: c['key'],
                                        child: Text(c['label']!,
                                            style: GoogleFonts.cairo(fontSize: 14)),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _category = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _proteinType,
                              decoration: const InputDecoration(
                                labelText: 'نوع البروتين',
                                border: OutlineInputBorder(),
                              ),
                              items: _proteins
                                  .map((p) => DropdownMenuItem(
                                        value: p['key'],
                                        child: Text(p['label']!,
                                            style: GoogleFonts.cairo(fontSize: 14)),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _proteinType = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _carbsType,
                              decoration: const InputDecoration(
                                labelText: 'نوع النشويات',
                                border: OutlineInputBorder(),
                              ),
                              items: _carbs
                                  .map((c) => DropdownMenuItem(
                                        value: c['key'],
                                        child: Text(c['label']!,
                                            style: GoogleFonts.cairo(fontSize: 14)),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _carbsType = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _prepTimeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'وقت التحضير (دقيقة)',
                                prefixIcon: Icon(Icons.timer_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: Text('أكلة جمعة / عزومات',
                                  style: GoogleFonts.cairo(fontSize: 14)),
                              value: _isFridaySpecial,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) =>
                                  setState(() => _isFridaySpecial = v ?? false),
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: Text('أكلة اقتصادية / توفير',
                                  style: GoogleFonts.cairo(fontSize: 14)),
                              value: _isBudgetFriendly,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) =>
                                  setState(() => _isBudgetFriendly = v ?? false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: _isStarterMeal
                              ? Colors.teal.shade50
                              : theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isStarterMeal
                                ? Colors.teal.shade400
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: SwitchListTile(
                          title: Row(
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                color: _isStarterMeal ? Colors.teal.shade700 : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'وجبة أساسية للمستخدمين الجدد (Starter Pack)',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _isStarterMeal ? Colors.teal.shade900 : null,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'تُنزل هذه الوجبة تلقائياً عند تثبيت التطبيق لأول مرة لأي مستخدم جديد',
                            style: GoogleFonts.cairo(fontSize: 12),
                          ),
                          value: _isStarterMeal,
                          onChanged: (v) => setState(() => _isStarterMeal = v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'صورة الأكلة:',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.upload_file_rounded),
                                  label: Text(
                                    _pickedImageBytes != null
                                        ? 'تم اختيار صورة محلياً'
                                        : 'رفع صورة من الجهاز',
                                    style: GoogleFonts.cairo(fontSize: 13),
                                  ),
                                ),
                                if (_pickedImageBytes != null) ...[
                                  const SizedBox(width: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      _pickedImageBytes!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _imageUrlController,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'أو ضع رابط صورة مباشر (URL)',
                                prefixIcon: Icon(Icons.link_rounded),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات أو مقترحات تقديم (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('إلغاء', style: GoogleFonts.cairo()),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveMeal,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        isEdit ? 'حفظ التعديلات' : 'إضافة إلى الخزنة',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
