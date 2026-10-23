import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';

/// Small design pieces shared by the Manage Palms pages, in the same
/// style as the palm list / palm details pages.

Color palmStatusColor(String status) {
  switch (status) {
    case 'Healthy':
      return AppColors.healthy;
    case 'Suspected':
      return AppColors.suspected;
    case 'Under Monitoring':
      return AppColors.monitoring;
    default:
      return AppColors.textSecondary;
  }
}

/// Icon for a status (null = palm icon).
IconData? palmStatusIcon(String status) {
  switch (status) {
    case 'Suspected':
      return Icons.warning_rounded;
    case 'Under Monitoring':
      return Icons.access_time_rounded;
    default:
      return null;
  }
}

/// Colored square with the status icon (palm for healthy).
class StatusTile extends StatelessWidget {
  final String status;
  final double size;

  const StatusTile({super.key, required this.status, this.size = 54});

  @override
  Widget build(BuildContext context) {
    final color = palmStatusColor(status);
    final icon = palmStatusIcon(status);
    return Container(
      width: size,
      height: size + 4,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: icon == null
            ? PalmIcon(color: color, size: size * 0.56)
            : Icon(icon, color: color, size: size * 0.56),
      ),
    );
  }
}

/// Small colored label, e.g. "Suspected" or "Step 1 of 3".
class InfoChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const InfoChip({
    super.key,
    required this.text,
    this.color = AppColors.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top card of a page: beige box with a palm, a title and a label,
/// like the top of the Palm Details page.
class PalmHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? chip;

  const PalmHeaderCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.chip,
  });

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      child: Row(
        children: [
          Container(
            width: 76,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.beige,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: PalmIcon(size: 48, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                if (chip != null) ...[
                  const SizedBox(height: 8),
                  chip!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Title at the top of a card: green icon + bold text + thin line.
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionTitle({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }
}

/// Round tinted icon button (edit / delete on the palm cards).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
