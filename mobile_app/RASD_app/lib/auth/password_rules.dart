
import 'package:flutter/material.dart';
 
import '../theme/app_colors.dart';
 
/// The password rules of the app, checked in one place.
///
/// Sign Up and Change Password both use this class, so the rules are always
/// the same and the checklist on screen matches the validation.
class PasswordRules {
  PasswordRules._();
 
  /// The five rules, in the order they appear in the checklist.
  static const List<String> labels = [
    'At least 8 characters',
    'An uppercase letter (A-Z)',
    'A lowercase letter (a-z)',
    'A number (0-9)',
    'A special character (! @ # \$ ...)',
  ];
 
  /// For [password], tells which of the five rules are met.
  static List<bool> check(String password) => [
        password.length >= 8,
        RegExp(r'[A-Z]').hasMatch(password),
        RegExp(r'[a-z]').hasMatch(password),
        RegExp(r'[0-9]').hasMatch(password),
        RegExp(r'[^A-Za-z0-9\s]').hasMatch(password),
      ];
 
  /// How many rules are met (0 to 5).
  static int score(String password) => check(password).where((ok) => ok).length;
 
  /// True when every rule is met.
  static bool isStrong(String password) => score(password) == labels.length;
 
  /// Error text for the field, or null when the password is strong.
  /// The text names only the rules that are still missing.
  static String? validate(String? password) {
    final value = password ?? '';
    if (value.isEmpty) return 'This field is required.';
    final results = check(value);
    final missing = <String>[
      if (!results[0]) 'at least 8 characters',
      if (!results[1]) 'an uppercase letter',
      if (!results[2]) 'a lowercase letter',
      if (!results[3]) 'a number',
      if (!results[4]) 'a special character',
    ];
    if (missing.isEmpty) return null;
    return 'Add ${_join(missing)}.';
  }
 
  /// Joins words as "a, b and c".
  static String _join(List<String> items) {
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }
}
 
/// Checklist and strength bar shown under a password field.
///
/// It rebuilds every time the user types, because it listens to [controller].
class PasswordRulesBox extends StatelessWidget {
  final TextEditingController controller;
 
  const PasswordRulesBox({super.key, required this.controller});
 
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final results = PasswordRules.check(controller.text);
        final score = PasswordRules.score(controller.text);
 
        // The bar has 4 parts: weak, fair, good, strong.
        final filled = score == 0 ? 0 : (score <= 2 ? 1 : (score == 3 ? 2 : (score == 4 ? 3 : 4)));
        final color = score <= 2
            ? AppColors.suspected
            : (score < 5 ? AppColors.monitoring : AppColors.primary);
        final label = score == 0
            ? ''
            : (score <= 2 ? 'Weak' : (score < 5 ? 'Medium' : 'Strong'));
 
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F7F4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i < filled ? color : const Color(0xFFE1E8E2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  SizedBox(
                    width: 56,
                    child: Text(
                      label,
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
              for (var i = 0; i < PasswordRules.labels.length; i++)
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
                        PasswordRules.labels[i],
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
