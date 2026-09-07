import 'package:flutter/material.dart';

/// Quick action buttons for marking a meal as cooked today or leftover.
/// In RTL, the primary action ("طبخت دي النهاردة") is placed first so it appears on the right.
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
