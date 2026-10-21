import 'package:flutter/material.dart';

import '../data/auth_store.dart';
import '../data/mock_data.dart';
import '../manage_farms/my_farms_page.dart';
import '../screens/home.dart';
import '../theme/app_colors.dart';

/// Small label above a field (same look as the other forms).
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Label + text field with an icon. The input style comes from the theme.
/// With [isPassword] it hides the text and shows an eye button.
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

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _hidden = true;

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
                    onPressed: () => setState(() => _hidden = !_hidden),
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

/// Field checks shared by Sign Up, Log In, Edit Profile, Change Password.
class AuthValidators {
  static String? name(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null;

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Please enter your email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return ok ? null : 'Please enter a valid email';
  }

  /// Phone is optional, but when it is written it must look like 05XXXXXXXX.
  static String? phone(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    return RegExp(r'^05\d{8}$').hasMatch(value)
        ? null
        : 'Use the format 05XXXXXXXX';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Please enter a password';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }
}

/// English / العربية switch. Only changes AuthStore.arabic for now; the app
/// texts are not translated yet.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pill('English', !isArabic, () => AuthStore.arabic.value = false),
            const SizedBox(width: 6),
            _pill('العربية', isArabic, () => AuthStore.arabic.value = true),
          ],
        );
      },
    );
  }

  Widget _pill(String text, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// After Sign Up or Log In: a farm owner goes to My Farms, a farmer goes to
/// Home (Home shows the "No Farm Assigned" page when the farmer has no farm).
void openAppAfterAuth(BuildContext context) {
  final isOwner = AuthStore.role == UserRole.farmOwner;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => isOwner ? const MyFarmsPage() : const HomeScreen(),
    ),
    (route) => false,
  );
}
