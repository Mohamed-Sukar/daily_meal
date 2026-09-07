import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../providers/settings_providers.dart';
import 'widgets/legal_policies_dialog.dart' as widgets;

/// Formats cooldown duration with correct Arabic dual and plural grammar.
String formatCooldown(int days) {
  if (days == 1) return 'يوم واحد';
  if (days == 2) return 'يومان';
  if (days <= 10) return '$days أيام';
  return '$days يوماً';
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: settingsAsync.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Cooldown Slider Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'فترة استبعاد الأكلات (Cooldown)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              formatCooldown(settings.cooldownDays),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'المدة التي تظل فيها الأكلة مستبعدة من الاقتراحات بعد طبخها.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Slider(
                        value: settings.cooldownDays.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: formatCooldown(settings.cooldownDays),
                        onChanged: (val) {
                          ref
                              .read(settingsControllerProvider.notifier)
                              .updateCooldownDays(val.round());
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Theme Mode Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المظهر والألوان',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<AppThemeModePreference>(
                        segments: const [
                          ButtonSegment(
                            value: AppThemeModePreference.system,
                            label: Text('تلقائي'),
                            icon: Icon(Icons.brightness_auto),
                          ),
                          ButtonSegment(
                            value: AppThemeModePreference.light,
                            label: Text('فاتح'),
                            icon: Icon(Icons.light_mode),
                          ),
                          ButtonSegment(
                            value: AppThemeModePreference.dark,
                            label: Text('داكن'),
                            icon: Icon(Icons.dark_mode),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (selected) {
                          if (selected.isNotEmpty) {
                            ref
                                .read(settingsControllerProvider.notifier)
                                .updateThemeMode(selected.first);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Dietary Variety Rules Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'قواعد التنوع الغذائي',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('منع تكرار نوع البروتين المتتالي'),
                        subtitle: const Text('استبعاد نفس البروتين المطبوخ بالأمس أو اليوم'),
                        value: settings.preventRepeatProtein,
                        onChanged: (val) {
                          ref
                              .read(settingsControllerProvider.notifier)
                              .updateDietaryRules(preventProtein: val);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('منع تكرار نوع النشويات المتتالي'),
                        subtitle: const Text('تجنب تكرار الأرز أو المكرونة يومين وراء بعض'),
                        value: settings.preventRepeatCarbs,
                        onChanged: (val) {
                          ref
                              .read(settingsControllerProvider.notifier)
                              .updateDietaryRules(preventCarbs: val);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 4. Notifications Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تنبيه الاقتراح اليومي',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('تفعيل التذكير اليومي'),
                        subtitle: const Text('إشعار تذكير لتفقد اقتراحات وجبة اليوم'),
                        value: settings.notificationsEnabled,
                        onChanged: (val) {
                          ref
                              .read(settingsControllerProvider.notifier)
                              .toggleNotifications(val);
                        },
                      ),
                      if (settings.notificationsEnabled)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('موعد التذكير'),
                          subtitle: Text(
                            '${settings.notificationHour.toString().padLeft(2, '0')}:${settings.notificationMinute.toString().padLeft(2, '0')}',
                          ),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: settings.notificationHour,
                                minute: settings.notificationMinute,
                              ),
                            );
                            if (picked != null) {
                              ref
                                  .read(settingsControllerProvider.notifier)
                                  .updateNotificationTime(picked.hour, picked.minute);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 5. Legal Policies Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'السياسات القانونية',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('سياسة الخصوصية'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const widgets.LegalPoliciesDialog(isPrivacy: true),
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('إخلاء المسؤولية والشروط'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const widgets.LegalPoliciesDialog(isPrivacy: false),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 6. Reset Defaults Action
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await ref.read(settingsControllerProvider.notifier).resetToDefaults();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم استعادة الإعدادات الافتراضية')),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('استعادة الإعدادات الافتراضية'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, _) => Center(child: Text('حدث خطأ: $err')),
      ),
    );
  }
}
