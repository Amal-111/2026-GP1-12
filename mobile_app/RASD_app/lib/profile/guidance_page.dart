// Guidance page: signs of red palm weevil infestation and what to do.
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../data/auth_store.dart';
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
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, child) {
        final signs = isArabic
            ? [
          'خروج سائل بني ولزج من الجذع أو قاعدة السعف.',
          'وجود ثقوب في الجذع مع ألياف نباتية ممضوغة حولها.',
          'اصفرار السعف الأوسط أو ذبوله وتدليه.',
          'رائحة تخمر كريهة بالقرب من التاج.',
          'ميلان التاج أو ضعفه أو انهياره (في المراحل المتأخرة).',
        ]
            : _signs;

        final steps = isArabic
            ? [
          'افحص الجذع والتاج بحثًا عن العلامات التحذيرية المذكورة أعلاه.',
          'سجّل العلاج في صفحة تفاصيل النخلة.',
          'استمر في متابعة النخلة أثناء وجودها تحت المراقبة.',
          'أبلغ الجهة الزراعية المحلية عن حالات الإصابة المؤكدة.',
        ]
            : _steps;

        return PalmScaffold(
          appBar: glassAppBar(
            title: isArabic ? 'الإرشادات' : 'Guidance',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Heading(
                        isArabic
                            ? 'علامات الإصابة بسوسة النخيل الحمراء'
                            : 'Warning signs of Red Palm Weevil',
                      ),
                      Text(
                        isArabic
                            ? 'ما الذي يجب البحث عنه عند فحص النخلة'
                            : 'What to look for when you inspect a palm',
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final sign in signs) _Bullet(sign),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                GlassBox(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Heading(
                        isArabic
                            ? 'معاني حالات النخيل في التطبيق'
                            : 'What the app statuses mean',
                      ),
                      const SizedBox(height: 4),
                      _StatusRow(
                        icon: Icons.check_circle_rounded,
                        color: AppColors.healthy,
                        name: isArabic ? 'سليمة' : 'Healthy',
                        text: isArabic
                            ? 'لم يرصد المستشعر أي نشاط غير طبيعي.'
                            : 'No unusual activity detected by the sensor.',
                      ),
                      _StatusRow(
                        icon: Icons.warning_rounded,
                        color: AppColors.suspected,
                        name: isArabic ? 'مشتبه بالأصابه' : 'Suspected',
                        text: isArabic
                            ? 'تم رصد اهتزاز غير طبيعي. افحص النخلة.'
                            : 'Unusual vibration was detected. Inspect the palm.',
                      ),
                      _StatusRow(
                        icon: Icons.access_time_rounded,
                        color: AppColors.monitoring,
                        name: isArabic ? 'تحت المراقبة' : 'Under Monitoring',
                        text: isArabic
                            ? 'تم تسجيل العلاج وتتم متابعة النخلة.'
                            : 'Treatment was recorded and the palm is being watched.',
                      ),
                      _StatusRow(
                        icon: Icons.wifi_off_rounded,
                        color: AppColors.offline,
                        name: isArabic ? 'المستشعر غير متصل' : 'Sensor Offline',
                        text: isArabic
                            ? 'توقف المستشعر عن إرسال البيانات. تحقق من الطاقة والإشارة.'
                            : 'The sensor stopped sending data. Check its power and signal.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                GlassBox(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Heading(
                        isArabic
                            ? 'ماذا تفعل إذا كانت النخلة مشتبهًا بها؟'
                            : 'If a palm is Suspected',
                      ),
                      const SizedBox(height: 4),
                      for (var i = 0; i < steps.length; i++)
                        _Step(number: i + 1, text: steps[i]),
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
                          isArabic
                              ? 'يقدم تطبيق رصد إنذارًا مبكرًا فقط. ولا يتم تأكيد إصابة النخلة إلا من خلال الفحص الميداني.'
                              : 'RASD gives an early warning only. A palm is confirmed infested by a physical inspection.',
                          style: Theme
                              .of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
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
      },
    );
  }
}
/// Section heading.
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

/// Bulleted text line.
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

/// Row describing a palm status.
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

/// One numbered step.
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
