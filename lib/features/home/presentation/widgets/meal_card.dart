import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import 'quick_actions.dart';

/// Formats preparation time in Arabic according to Egyptian linguistic conventions:
/// <= 10 minutes: '$minutes دقائق'
/// > 10 minutes: '$minutes دقيقة'
String formatPrepTime(int minutes) {
  if (minutes <= 10) {
    return '$minutes دقائق';
  } else {
    return '$minutes دقيقة';
  }
}

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrimary = cardIndex == 0;

    return Card(
      elevation: isPrimary ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPrimary
            ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5)
            : BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Priority Banner
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

                  // 4. Meal Title (Wraps up to 3 lines without overflow)
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

                  // 5. Metadata Chips (Prep time, Category, Protein, Carbs)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.timer_outlined, size: 16),
                        label: Text(formatPrepTime(meal.prepTime)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      Chip(
                        avatar: const Icon(Icons.category_outlined, size: 16),
                        label: Text(meal.category.labelArabic),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      Chip(
                        avatar: const Icon(Icons.egg_alt_outlined, size: 16),
                        label: Text(meal.proteinType.labelArabic),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
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

                  // 6. Quick Action Buttons
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
            theme.colorScheme.primary.withValues(alpha: 0.12),
            theme.colorScheme.tertiary.withValues(alpha: 0.18),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: cardIndex == 0 ? 48 : 36,
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
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
