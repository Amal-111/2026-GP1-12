import 'package:flutter/material.dart';

import '../data/auth_store.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';
import 'auth_widgets.dart';
import 'sign_up_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _logIn() {
    if (!_formKey.currentState!.validate()) return;

    final error = AuthStore.logIn(
      _emailController.text,
      _passwordController.text,
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
        title: 'Log In',
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
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  children: [
                    GlassBox(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 14,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/rasd_logo.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 72,
                              height: 72,
                              child: Center(
                                child: PalmIcon(
                                  size: 52,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Welcome back',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassBox(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
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
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline,
                              controller: _passwordController,
                              isPassword: true,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Please enter your password'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                      onPressed: _logIn,
                      child: const Text('Log In'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassLabel(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignUpPage(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign Up',
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
