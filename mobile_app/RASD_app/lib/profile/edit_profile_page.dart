import 'package:flutter/material.dart';

import '../auth/auth_widgets.dart';
import '../data/auth_store.dart';
import '../services/firebase_auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';

/// Pops with `true` when the changes were saved.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: AuthStore.name);
    _emailController = TextEditingController(text: AuthStore.email);
    _phoneController = TextEditingController(text: AuthStore.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _busy = false;
  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (_emailController.text.trim() != AuthStore.email) {
      showCenterMessage(context, 'Email changes require a separate verification flow.', success: false);
      return;
    }
    setState(() => _busy = true);
    try {
      await RasdAuthService.updateProfile(name: _nameController.text, phone: _phoneController.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showCenterMessage(context, RasdAuthService.message(error), success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Edit Profile',
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
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 42,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        AppTextField(
                          label: 'Full Name',
                          hint: 'Full Name',
                          icon: Icons.person_outline,
                          controller: _nameController,
                          validator: AuthValidators.name,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Email',
                          hint: 'Email',
                          icon: Icons.mail_outline,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: AuthValidators.email,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Phone Number',
                          hint: '05XXXXXXXX',
                          icon: Icons.phone_outlined,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: AuthValidators.phone,
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
                  onPressed: _busy ? null : _save,
                  child: const Text('Save Changes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
