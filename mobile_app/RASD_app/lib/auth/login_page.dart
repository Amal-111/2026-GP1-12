
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import '../services/rasd_errors.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';
import '../data/auth_store.dart';

import 'auth_widgets.dart';
import 'sign_up_page.dart';

/// Log In page.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// True while a login request is running.
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates the form and signs the user in with Firebase.
  Future<void> _logIn() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _busy = true);

    try {
      await RasdAuthService.logIn(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      // Open the appropriate screen based on the user's role.
      openAppAfterAuth(context);
    } catch (error) {
      if (mounted) {
        showRasdError(
          context,
          error,
          title: AuthStore.arabic.value
              ? 'تعذر تسجيل الدخول'
              : 'Could not log in',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, child) {
        return PalmScaffold(
          appBar: glassAppBar(
            title: isArabic ? 'تسجيل الدخول' : 'Log In',
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      12,
                    ),
                    child: Column(
                      children: [
                        // Logo and welcome message.
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
                                errorBuilder: (_, __, ___) =>
                                const SizedBox(
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
                                isArabic
                                    ? 'مرحبًا بعودتك'
                                    : 'Welcome back',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Login form.
                        GlassBox(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Email field.
                                AppTextField(
                                  label: isArabic
                                      ? 'البريد الإلكتروني'
                                      : 'Email',
                                  hint: 'name@example.com',
                                  icon: Icons.mail_outline,
                                  controller: _emailController,
                                  keyboardType:
                                  TextInputType.emailAddress,
                                  validator: AuthValidators.email,
                                ),

                                const SizedBox(height: 14),

                                // Password field.
                                AppTextField(
                                  label: isArabic
                                      ? 'كلمة المرور'
                                      : 'Password',
                                  hint: isArabic
                                      ? 'أدخل كلمة المرور'
                                      : 'Enter your password',
                                  icon: Icons.lock_outline,
                                  controller: _passwordController,
                                  isPassword: true,
                                  validator: (value) =>
                                  (value == null || value.isEmpty)
                                      ? AuthValidators.requiredMessage
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

                // Login button and sign-up navigation.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    16,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _logIn,
                          child: Text(
                            isArabic
                                ? 'تسجيل الدخول'
                                : 'Log In',
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      GlassLabel(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArabic
                                  ? 'ليس لديك حساب؟ '
                                  : "Don't have an account? ",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                            ),

                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const SignUpPage(),
                                  ),
                                );
                              },
                              child: Text(
                                isArabic
                                    ? 'إنشاء حساب'
                                    : 'Sign Up',
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
      },
    );
  }
}
