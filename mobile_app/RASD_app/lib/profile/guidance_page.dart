import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';

/// Red Palm Weevil guidance: warning signs, what the app statuses mean and
/// what to do for a suspected palm.
class GuidancePage extends StatelessWidget {
  const GuidancePage({super.key});

  static const _signs = [
    'Brown, sticky fluid oozing from the trunk or the base of the fronds',
    'Holes in the trunk, with chewed plant fibres around them',
    'Central fronds that turn yellow, wilt or droop',
    'A fermented, unpleasant smell near the crown',
    'A crown that leans, weakens or collapses (late stage)',
  ];

  static const _steps = [
    'Inspect the trunk and crown for the warning signs above.',
    'Record the treatment in the palm details page.',
    'Keep checking the palm while it is Under Monitoring.',
    'Report confirmed infestations to the local agriculture authority.',
  ];

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Guidance',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            GlassBox(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Heading('Warning signs of Red Palm Weevil'),
                  Text(
                    'What to look for when you inspect a palm',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  for (final sign in _signs) _Bullet(sign),
                ],
              ),
            ),

            const SizedBox(height: 12),

            GlassBox(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Heading('What the app statuses mean'),
                  SizedBox(height: 4),
                  _StatusRow(
                    icon: Icons.check_circle_rounded,
                    color: AppColors.healthy,
                    name: 'Healthy',
                    text: 'No unusual activity detected by the sensor.',
                  ),
                  _StatusRow(
                    icon: Icons.warning_rounded,
                    color: AppColors.suspected,
                    name: 'Suspected',
                    text: 'Unusual vibration was detected. Inspect the palm.',
                  ),
                  _StatusRow(
                    icon: Icons.access_time_rounded,
                    color: AppColors.monitoring,
                    name: 'Under Monitoring',
                    text: 'Treatment was recorded and the palm is being watched.',
                  ),
                  _StatusRow(
                    icon: Icons.wifi_off_rounded,
                    color: AppColors.offline,
                    name: 'Sensor Offline',
                    text:
                        'The sensor stopped sending data. Check its power and signal.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            GlassBox(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Heading('If a palm is Suspected'),
                  const SizedBox(height: 4),
                  for (var i = 0; i < _steps.length; i++)
                    _Step(number: i + 1, text: _steps[i]),
                ],
              ),
            ),

            const SizedBox(height: 12),

            GlassLabel(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'RASD gives an early warning only. A palm is confirmed '
                      'infested by a physical inspection.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.circle, size: 7, color: AppColors.secondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String text;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.name,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
