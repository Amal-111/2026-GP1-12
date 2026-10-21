import 'package:flutter/material.dart';

import '../auth/auth_widgets.dart';
import '../data/auth_store.dart';
import '../theme/glass_widgets.dart';

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

  void _update() {
    if (!_formKey.currentState!.validate()) return;

    final error = AuthStore.changePassword(
      _currentController.text,
      _newController.text,
    );

    if (error != null) {
      showCenterMessage(context, error, success: false);
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Change Password',
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
                          label: 'Current Password',
                          hint: 'Enter current password',
                          icon: Icons.lock_outline,
                          controller: _currentController,
                          isPassword: true,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Please enter your current password'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'New Password',
                          hint: 'At least 8 characters',
                          icon: Icons.lock_outline,
                          controller: _newController,
                          isPassword: true,
                          validator: AuthValidators.password,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Confirm New Password',
                          hint: 'Re-enter new password',
                          icon: Icons.lock_outline,
                          controller: _confirmController,
                          isPassword: true,
                          validator: (v) => v != _newController.text
                              ? 'Passwords do not match'
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
                child: ElevatedButton(
                  onPressed: _update,
                  child: const Text('Update Password'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
