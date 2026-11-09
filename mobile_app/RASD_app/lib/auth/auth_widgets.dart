// Shared widgets and input validators used by the Sign Up, Log In and profile screens.
import 'package:flutter/material.dart';
 
import '../data/auth_store.dart';
import '../data/mock_data.dart';
import '../manage_farms/my_farms_page.dart';
import '../screens/home.dart';
import '../theme/app_colors.dart';
import 'password_rules.dart';
 
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
 
/// State of the text field (handles show/hide password).
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
 
/// Field checks shared by Sign Up, Log In, Edit Profile and Change Password.
/// Each check returns the red message shown under the field, or null when the
/// value is fine. The wording is the same on every screen.
class AuthValidators {
  AuthValidators._();
 
  static const String requiredMessage = 'This field is required.';
 
  /// Any field that must not be empty.
  static String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? requiredMessage : null;
 
  /// Full name: letters (English or Arabic), spaces, dots, apostrophes and dashes.
  static String? name(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return requiredMessage;
    final ok = value.length >= 2 &&
        RegExp(r"^[\p{L}\s.'-]+$", unicode: true).hasMatch(value);
    return ok ? null : 'Enter your full name, using letters only.';
  }
 
  /// Email: must look like name@example.com.
  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return requiredMessage;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return ok ? null : 'Enter a valid email, like name@example.com.';
  }
 
  /// Phone: Saudi mobile number, 05 followed by 8 digits (10 digits in total).
  static String? phone(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return requiredMessage;
    return RegExp(r'^05\d{8}$').hasMatch(value)
        ? null
        : 'Enter a phone number that starts with 05 and has 10 digits.';
  }
 
  /// New password: must follow every password rule (see [PasswordRules]).
  static String? password(String? v) => PasswordRules.validate(v);
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
 
  /// Builds a selectable pill button.
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
 
