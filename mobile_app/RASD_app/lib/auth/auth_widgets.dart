
import 'package:flutter/material.dart';

import '../data/auth_store.dart';
import '../data/mock_data.dart';
import '../manage_farms/my_farms_page.dart';
import '../screens/home.dart';
import '../theme/app_colors.dart';
import 'password_rules.dart';

/// Small label displayed above a form field.
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  /// Builds the field label using the app theme.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

/// Shared text field with an optional password visibility button.
class AppTextField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool isPassword;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.isPassword = false,
    this.validator,
  });

  /// Creates the text field state.
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

/// Handles password visibility for the shared text field.
class _AppTextFieldState extends State<AppTextField> {
  bool _hidden = true;

  /// Builds the input field and its validation message.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(widget.label),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.isPassword && _hidden,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon),
            suffixIcon: widget.isPassword
                ? IconButton(
              onPressed: () {
                setState(() => _hidden = !_hidden);
              },
              icon: Icon(
                _hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Shared input validators for authentication and profile forms.
class AuthValidators {
  AuthValidators._();

  /// Returns the required-field message in the selected language.
  static String get requiredMessage =>
      AuthStore.arabic.value
          ? 'هذا الحقل مطلوب.'
          : 'This field is required.';

  /// Checks whether a required field is empty.
  static String? required(String? value) {
    return (value == null || value.trim().isEmpty)
        ? requiredMessage
        : null;
  }

  /// Validates a full name containing Arabic or English letters.
  static String? name(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return requiredMessage;
    }

    final isValid = name.length >= 2 &&
        RegExp(
          r"^[\p{L}\s.'-]+$",
          unicode: true,
        ).hasMatch(name);

    if (isValid) return null;

    return AuthStore.arabic.value
        ? 'أدخل اسمك الكامل باستخدام الأحرف فقط.'
        : 'Enter your full name, using letters only.';
  }

  /// Validates the email address format.
  static String? email(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return requiredMessage;
    }

    final isValid = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);

    if (isValid) return null;

    return AuthStore.arabic.value
        ? 'أدخل بريدًا إلكترونيًا صحيحًا مثل name@example.com.'
        : 'Enter a valid email, like name@example.com.';
  }

  /// Validates a Saudi mobile number starting with 05.
  static String? phone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return requiredMessage;
    }

    final isValid = RegExp(
      r'^05\d{8}$',
    ).hasMatch(phone);

    if (isValid) return null;

    return AuthStore.arabic.value
        ? 'أدخل رقم جوال يبدأ بـ 05 ويتكون من 10 أرقام.'
        : 'Enter a phone number that starts with 05 and has 10 digits.';
  }

  /// Validates the password using the existing five rules.
  static String? password(String? value) {
    return PasswordRules.validate(value);
  }
}

/// Language selector used in authentication screens.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  /// Builds the Arabic and English selection buttons.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pill(
              'English',
              !isArabic,
                  () => AuthStore.arabic.value = false,
            ),
            const SizedBox(width: 6),
            _pill(
              'العربية',
              isArabic,
                  () => AuthStore.arabic.value = true,
            ),
          ],
        );
      },
    );
  }

  /// Builds a selectable language button.
  Widget _pill(
      String text,
      bool selected,
      VoidCallback onTap,
      ) {
    return Material(
      color: selected
          ? AppColors.primary
          : Colors.white.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the correct screen after successful authentication.
void openAppAfterAuth(BuildContext context) {
  final isOwner = AuthStore.role == UserRole.farmOwner;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => isOwner
          ? const MyFarmsPage()
          : const HomeScreen(),
    ),
        (route) => false,
  );
}
