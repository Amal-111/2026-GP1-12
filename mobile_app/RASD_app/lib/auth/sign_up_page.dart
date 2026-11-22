
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_auth_service.dart';
import '../data/mock_data.dart';
import '../data/auth_store.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';
import '../services/rasd_errors.dart';

import 'auth_widgets.dart';
import 'password_rules.dart';
import 'login_page.dart';

/// Sign Up page for creating a new RASD account.
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

  /// Selected account role.
  UserRole _role = UserRole.farmOwner;

  /// Prevents multiple requests while processing.
  bool _busy = false;

  /// Indicates that email verification is pending.
  bool _awaitingVerification = false;

  /// Restores an unfinished email verification process.
  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _awaitingVerification = true;
      _emailController.text = user.email ?? '';
      _nameController.text = user.displayName ?? '';
    }
  }

  /// Releases the form controllers.
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();

    super.dispose();
  }

  /// Creates an account or completes registration after verification.
  Future<void> _createAccount() async {
    if (_busy) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      if (!_awaitingVerification) {
        // Create the Firebase account and send verification email.
        await RasdAuthService.signUp(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          password: _passwordController.text,
          role: _role,
        );

        if (!mounted) return;

        setState(() => _awaitingVerification = true);

        // Ask the user to verify their email before continuing.
        showCenterMessage(
          context,
          AuthStore.arabic.value
              ? 'تم إرسال رابط التحقق إلى بريدك الإلكتروني. '
              'افتح الرابط، ثم عد إلى التطبيق واضغط على متابعة.'
              : 'We sent a verification link to your email. '
              'Open it, then come back and tap Continue.',
          title: AuthStore.arabic.value
              ? 'تحقق من بريدك الإلكتروني'
              : 'Check your email',
        );
      } else {
        // Complete the profile after email verification.
        await RasdAuthService.completeRegistration(
          name: _nameController.text,
          phone: _phoneController.text,
          role: _role,
        );

        if (!mounted) return;

        // Navigate to the correct page based on the user's role.
        openAppAfterAuth(context);
      }
    } catch (error) {
      if (mounted) {
        showRasdError(
          context,
          error,
          title: _awaitingVerification
              ? (AuthStore.arabic.value
              ? 'تعذرت المتابعة'
              : 'Could not continue')
              : (AuthStore.arabic.value
              ? 'تعذر إنشاء الحساب'
              : 'Could not sign up'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Builds the registration form and email verification button.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, child) {
        return PalmScaffold(
          appBar: glassAppBar(
            title: isArabic ? 'إنشاء حساب' : 'Sign Up',
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
              ),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const LoginPage(),
                    ),
                  );
                }
              },
            ),
          ),

          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      12,
                    ),
                    child: GlassBox(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            // Full name.
                            AppTextField(
                              label: isArabic
                                  ? 'الاسم الكامل'
                                  : 'Full Name',
                              hint: isArabic
                                  ? 'أدخل اسمك الكامل'
                                  : 'Enter your full name',
                              icon: Icons.person_outline,
                              controller: _nameController,
                              validator: AuthValidators.name,
                            ),

                            const SizedBox(height: 14),

                            // Email address.
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

                            // Phone number.
                            AppTextField(
                              label: isArabic
                                  ? 'رقم الجوال'
                                  : 'Phone Number',
                              hint: '05XXXXXXXX',
                              icon: Icons.phone_outlined,
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: AuthValidators.phone,
                            ),

                            const SizedBox(height: 14),

                            // Password with existing validation rules.
                            AppTextField(
                              label: isArabic
                                  ? 'كلمة المرور'
                                  : 'Password',
                              hint: isArabic
                                  ? 'أنشئ كلمة مرور قوية'
                                  : 'Create a strong password',
                              icon: Icons.lock_outline,
                              controller: _passwordController,
                              isPassword: true,
                              validator: _awaitingVerification
                                  ? (_) => null
                                  : AuthValidators.password,
                            ),

                            // Live password requirements checklist.
                            if (!_awaitingVerification) ...[
                              const SizedBox(height: 10),
                              PasswordRulesBox(
                                controller: _passwordController,
                              ),
                            ],

                            const SizedBox(height: 14),

                            // Confirm password.
                            AppTextField(
                              label: isArabic
                                  ? 'تأكيد كلمة المرور'
                                  : 'Confirm Password',
                              hint: isArabic
                                  ? 'أعد إدخال كلمة المرور'
                                  : 'Re-enter your password',
                              icon: Icons.lock_outline,
                              controller: _confirmController,
                              isPassword: true,
                              validator: (value) =>
                              !_awaitingVerification &&
                                  value !=
                                      _passwordController.text
                                  ? (isArabic
                                  ? 'كلمتا المرور غير متطابقتين. '
                                  'أدخل كلمة المرور نفسها مرة أخرى.'
                                  : 'Passwords do not match. '
                                  'Type the same password again.')
                                  : null,
                            ),

                            const SizedBox(height: 14),

                            // Account role selection.
                            FieldLabel(
                              isArabic ? 'أنا:' : 'I am a',
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: _RoleCard(
                                    icon: const PalmIcon(
                                      size: 30,
                                      color: AppColors.primary,
                                    ),
                                    title: isArabic
                                        ? 'مالك المزرعة'
                                        : 'Farm Owner',
                                    subtitle: isArabic
                                        ? 'إدارة المزارع والمزارعين'
                                        : 'Manage farms & farmers',
                                    selected:
                                    _role == UserRole.farmOwner,
                                    onTap: () {
                                      setState(() {
                                        _role = UserRole.farmOwner;
                                      });
                                    },
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
                                    title: isArabic
                                        ? 'مزارع'
                                        : 'Farmer',
                                    subtitle: isArabic
                                        ? 'مراقبة النخيل'
                                        : 'Monitor palms',
                                    selected:
                                    _role == UserRole.farmer,
                                    onTap: () {
                                      setState(() {
                                        _role = UserRole.farmer;
                                      });
                                    },
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

                // Account creation and verification button.
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
                          onPressed: _busy
                              ? null
                              : _createAccount,
                          child: Text(
                            _awaitingVerification
                                ? (isArabic
                                ? 'تحققت من بريدي — متابعة'
                                : 'I Verified My Email — Continue')
                                : (isArabic
                                ? 'إنشاء حساب'
                                : 'Create Account'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Navigation to the login page.
                      GlassLabel(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArabic
                                  ? 'لديك حساب بالفعل؟ '
                                  : 'Already have an account? ',
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
                                    const LoginPage(),
                                  ),
                                );
                              },
                              child: Text(
                                isArabic
                                    ? 'تسجيل الدخول'
                                    : 'Log In',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight:
                                  FontWeight.w800,
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

/// Selectable card for choosing the account role.
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

  /// Builds the role card and highlights the selected role.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
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

            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),

            const SizedBox(height: 2),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
