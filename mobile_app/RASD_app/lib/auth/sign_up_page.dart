import 'package:flutter/material.dart';

import '../data/auth_store.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';
import 'auth_widgets.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  UserRole _role = UserRole.farmOwner;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _createAccount() {
    if (!_formKey.currentState!.validate()) return;

    final error = AuthStore.signUp(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      role: _role,
    );

    if (error != null) {
      showCenterMessage(context, error, success: false);
      return;
    }

    openAppAfterAuth(context);
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Sign Up',
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: GlassBox(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          icon: Icons.person_outline,
                          controller: _nameController,
                          validator: AuthValidators.name,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Email',
                          hint: 'name@example.com',
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
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Password',
                          hint: 'At least 8 characters',
                          icon: Icons.lock_outline,
                          controller: _passwordController,
                          isPassword: true,
                          validator: AuthValidators.password,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Confirm Password',
                          hint: 'Re-enter your password',
                          icon: Icons.lock_outline,
                          controller: _confirmController,
                          isPassword: true,
                          validator: (v) => v != _passwordController.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        const FieldLabel('I am a'),
                        Row(
                          children: [
                            Expanded(
                              child: _RoleCard(
                                icon: const PalmIcon(
                                  size: 30,
                                  color: AppColors.primary,
                                ),
                                title: 'Farm Owner',
                                subtitle: 'Manage farms & farmers',
                                selected: _role == UserRole.farmOwner,
                                onTap: () => setState(
                                  () => _role = UserRole.farmOwner,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _RoleCard(
                                icon: const Icon(
                                  Icons.person_rounded,
                                  size: 30,
                                  color: AppColors.primary,
                                ),
                                title: 'Farmer',
                                subtitle: 'Monitor palms',
                                selected: _role == UserRole.farmer,
                                onTap: () => setState(
                                  () => _role = UserRole.farmer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createAccount,
                      child: const Text('Create Account'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassLabel(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                          child: Text(
                            'Log In',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
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

class _RoleCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFDCEDE0)
              : Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.8),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            icon,
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
