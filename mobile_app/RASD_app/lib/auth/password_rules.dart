
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../data/auth_store.dart';

/// Password validation rules used across the app.
class PasswordRules {
  PasswordRules._();

  static const int rulesCount = 5;

  /// Returns the five password requirements in the selected language.
  static List<String> labels(bool isArabic) => isArabic
      ? [
    '8 أحرف على الأقل',
    'حرف كبير (A-Z)',
    'حرف صغير (a-z)',
    'رقم (0-9)',
    'رمز خاص (! @ # \$ ...)',
  ]
      : [
    'At least 8 characters',
    'An uppercase letter (A-Z)',
    'A lowercase letter (a-z)',
    'A number (0-9)',
    'A special character (! @ # \$ ...)',
  ];

  /// Checks each password requirement.
  static List<bool> check(String password) => [
    password.length >= 8,
    RegExp(r'[A-Z]').hasMatch(password),
    RegExp(r'[a-z]').hasMatch(password),
    RegExp(r'[0-9]').hasMatch(password),
    RegExp(r'[^A-Za-z0-9\s]').hasMatch(password),
  ];

  /// Counts how many password requirements are satisfied.
  static int score(String password) {
    return check(password).where((ok) => ok).length;
  }

  /// Checks whether the password satisfies all five requirements.
  static bool isStrong(String password) {
    return score(password) == rulesCount;
  }

  /// Returns a localized validation message for missing requirements.
  static String? validate(String? password) {
    final value = password ?? '';
    final isArabic = AuthStore.arabic.value;

    if (value.isEmpty) {
      return isArabic
          ? 'هذا الحقل مطلوب.'
          : 'This field is required.';
    }

    final results = check(value);

    final missing = isArabic
        ? <String>[
      if (!results[0]) '8 أحرف على الأقل',
      if (!results[1]) 'حرف كبير',
      if (!results[2]) 'حرف صغير',
      if (!results[3]) 'رقم',
      if (!results[4]) 'رمز خاص',
    ]
        : <String>[
      if (!results[0]) 'at least 8 characters',
      if (!results[1]) 'an uppercase letter',
      if (!results[2]) 'a lowercase letter',
      if (!results[3]) 'a number',
      if (!results[4]) 'a special character',
    ];

    if (missing.isEmpty) {
      return null;
    }

    return isArabic
        ? 'يجب أن تحتوي كلمة المرور على: ${_join(missing, true)}.'
        : 'Add ${_join(missing, false)}.';
  }

  /// Joins missing requirements into one readable message.
  static String _join(List<String> items, bool isArabic) {
    if (items.length == 1) {
      return items.first;
    }

    final separator = isArabic ? '، ' : ', ';
    final lastConnector = isArabic ? ' و' : ' and ';

    return '${items.sublist(0, items.length - 1).join(separator)}'
        '$lastConnector${items.last}';
  }
}

/// Displays password strength and the five requirement indicators.
class PasswordRulesBox extends StatelessWidget {
  final TextEditingController controller;

  const PasswordRulesBox({
    super.key,
    required this.controller,
  });

  /// Builds the live password strength indicator.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        AuthStore.arabic,
      ]),
      builder: (context, _) {
        final isArabic = AuthStore.arabic.value;
        final results = PasswordRules.check(controller.text);
        final score = PasswordRules.score(controller.text);
        final labels = PasswordRules.labels(isArabic);

        // Convert the score into four visual strength segments.
        final filled = score == 0
            ? 0
            : (score <= 2
            ? 1
            : (score == 3
            ? 2
            : (score == 4 ? 3 : 4)));

        final color = score <= 2
            ? AppColors.suspected
            : (score < 5
            ? AppColors.monitoring
            : AppColors.primary);

        final strengthLabel = score == 0
            ? ''
            : (score <= 2
            ? (isArabic ? 'ضعيفة' : 'Weak')
            : (score < 5
            ? (isArabic ? 'متوسطة' : 'Medium')
            : (isArabic ? 'قوية' : 'Strong')));

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F7F4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Password strength bar.
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i < filled
                              ? color
                              : const Color(0xFFE1E8E2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  SizedBox(
                    width: 56,
                    child: Text(
                      strengthLabel,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Live checklist of password requirements.
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        results[i]
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: results[i]
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: results[i]
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
