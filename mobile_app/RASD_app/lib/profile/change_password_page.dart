// Change Password screen with a live password-strength checklist.
import 'package:flutter/material.dart';

import '../auth/auth_widgets.dart';
import '../auth/password_rules.dart';
import '../services/rasd_errors.dart';
import '../services/firebase_auth_service.dart';
import '../theme/glass_widgets.dart';
import '../data/auth_store.dart';
/// Pops with `true` when the password was changed.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// True while a request is running (disables the button).
  bool _busy = false;
  /// Validates the form and changes the password.
  Future<void> _update() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await RasdAuthService.changePassword(_currentController.text, _newController.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showRasdError(
          context,
          error,
          title: AuthStore.arabic.value
              ? 'تعذر تغيير كلمة المرور'
              : 'Could not change password',

          credentialMessage: AuthStore.arabic.value
              ? 'كلمة المرور الحالية غير صحيحة.'
              : 'The current password is not correct.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
return PalmScaffold(
      appBar: glassAppBar(
title: isArabic ? 'تغيير كلمة المرور' : 'Change Password',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: GlassBox(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppTextField(
label: isArabic ? 'كلمة المرور الحالية' : 'Current Password',
hint: isArabic ? 'أدخل كلمة المرور الحالية' : 'Enter current password',
                          icon: Icons.lock_outline,
                          controller: _currentController,
                          isPassword: true,
                          validator: (v) => (v == null || v.isEmpty)
                              ? AuthValidators.requiredMessage
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
label: isArabic ? 'كلمة المرور الجديدة' : 'New Password',
hint: isArabic ? 'أنشئ كلمة مرور قوية' : 'Create a strong password',
                          icon: Icons.lock_outline,
                          controller: _newController,
                          isPassword: true,
                          validator: (v) {
                            final rules = PasswordRules.validate(v);
                            if (rules != null) return rules;
                            if (v == _currentController.text) {
return isArabic
? 'يجب أن تختلف كلمة المرور الجديدة عن كلمة المرور الحالية.'
: 'The new password must be different from the current one.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        // Live checklist of the password rules.
                        PasswordRulesBox(controller: _newController),
                        const SizedBox(height: 14),
                        AppTextField(
label: isArabic ? 'تأكيد كلمة المرور الجديدة' : 'Confirm New Password',
hint: isArabic ? 'أعيد إدخال كلمة المرور الجديدة' : 'Re-enter new password',
                          icon: Icons.lock_outline,
                          controller: _confirmController,
                          isPassword: true,
                          validator: (v) => v != _newController.text
? (isArabic
? 'كلمتا المرور غير متطابقتين'
: 'Passwords do not match. Type the same password again.')
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                // The button stays grey until every password rule is met.
                child: ListenableBuilder(
                  listenable: _newController,
                  builder: (context, _) => ElevatedButton(
                    onPressed: (_busy || !PasswordRules.isStrong(_newController.text))
                        ? null
                        : _update,
child: Text(
isArabic ? 'تحديث كلمة المرور' : 'Update Password',
),
                  ),
                ),
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
