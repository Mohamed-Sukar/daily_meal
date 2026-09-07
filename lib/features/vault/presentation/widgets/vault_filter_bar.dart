import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../providers/vault_providers.dart';

class VaultFilterBar extends ConsumerWidget {
  const VaultFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(vaultFilterProvider);
    final notifier = ref.read(vaultFilterProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Reset Button (visible when filters are active)
          if (filter.hasActiveFilters) ...[
            ActionChip(
              avatar: const Icon(Icons.clear, size: 16),
              label: Text('مسح (${filter.activeFilterCount})'),
              onPressed: () => notifier.resetFilters(),
            ),
            const SizedBox(width: 8),
          ],

          // Favorite Filter
          FilterChip(
            avatar: Icon(
              filter.isFavoriteOnly ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: filter.isFavoriteOnly ? Colors.redAccent : null,
            ),
            label: const Text('المفضلة'),
            selected: filter.isFavoriteOnly,
            onSelected: (_) => notifier.toggleFavoriteFilter(),
          ),
          const SizedBox(width: 6),

          // Friday Special Filter
          FilterChip(
            avatar: const Icon(Icons.stars_rounded, size: 16),
            label: const Text('أكلة جمعة'),
            selected: filter.isFridaySpecialOnly,
            onSelected: (_) => notifier.toggleFridayFilter(),
          ),
          const SizedBox(width: 6),

          // Budget Friendly Filter
          FilterChip(
            avatar: const Icon(Icons.savings_outlined, size: 16),
            label: const Text('اقتصادي'),
            selected: filter.isBudgetFriendlyOnly,
            onSelected: (_) => notifier.toggleBudgetFilter(),
          ),
          const SizedBox(width: 8),

          // Protein Chips
          for (final p in ProteinType.values) ...[
            FilterChip(
              label: Text(p.labelArabic),
              selected: filter.proteinType == p,
              onSelected: (_) => notifier.toggleProtein(p),
            ),
            const SizedBox(width: 6),
          ],

          // Carbs Chips
          for (final c in CarbsType.values) ...[
            FilterChip(
              label: Text(c.labelArabic),
              selected: filter.carbsType == c,
              onSelected: (_) => notifier.toggleCarbs(c),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
