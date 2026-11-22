
import 'package:flutter/material.dart';

import '../auth/auth_widgets.dart';
import '../data/auth_store.dart';
import '../services/firebase_auth_service.dart';
import '../services/rasd_errors.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';

/// Pops with true only when the changes are fully saved.
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
  late final TextEditingController _passwordController;

  bool _busy = false;
  bool _verificationPending = false;
  String? _pendingEmail;

  /// Loads the current profile into the editable fields.
  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(text: AuthStore.name);

    _emailController =
        TextEditingController(text: AuthStore.email);

    _phoneController =
        TextEditingController(text: AuthStore.phone);

    _passwordController = TextEditingController();

    _emailController.addListener(() {
      if (!mounted) return;

      setState(() {
        // A verification link applies to one specific email.
        // If the email is changed again, request a new link.
        if (_verificationPending &&
            _emailController.text.trim().toLowerCase() !=
                _pendingEmail?.toLowerCase()) {
          _verificationPending = false;
          _pendingEmail = null;
        }
      });
    });
  }

  /// Releases all profile field controllers.
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Saves name/phone and requests verification if email changed.
  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    final newEmail = _emailController.text.trim();
    final oldEmail = AuthStore.email.trim();

    final emailChanged =
        newEmail.toLowerCase() != oldEmail.toLowerCase();

    if (emailChanged &&
        _passwordController.text.trim().isEmpty) {
      showCenterMessage(
        context,
        AuthStore.arabic.value
            ? 'أدخل كلمة المرور الحالية لتأكيد تغيير البريد.'
            : 'Enter your current password to change your email.',
        success: false,
      );
      return;
    }

    setState(() => _busy = true);

    try {
      // Keep the existing name and phone update.
      await RasdAuthService.updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
      );

      if (emailChanged) {
        // Re-authenticate and send the verification link.
        await RasdAuthService.requestEmailChange(
          newEmail: newEmail,
          currentPassword: _passwordController.text,
        );

        if (!mounted) return;

        setState(() {
          _verificationPending = true;
          _pendingEmail = newEmail;
        });

        await showCenterMessage(
          context,
          AuthStore.arabic.value
              ? 'تم إرسال رابط التحقق إلى البريد الجديد. '
              'افتح الرابط، ثم عد إلى التطبيق '
              'واضغط على زر تأكيد البريد.'
              : 'A verification link has been sent to '
              'your new email. Open the link, then '
              'return to the app and confirm your email.',
          title: AuthStore.arabic.value
              ? 'التحقق من البريد الإلكتروني'
              : 'Email Verification',
        );

        // Do not close the page while verification is pending.
        return;
      }

      // Name/phone update completed without changing email.
      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showRasdError(
          context,
          error,
          title: AuthStore.arabic.value
              ? 'تعذر حفظ التغييرات'
              : 'Could not save changes',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Confirms the email change with Firebase Authentication.
  Future<void> _confirmEmailChange() async {
    if (_busy || !_verificationPending || _pendingEmail == null) {
      return;
    }

    setState(() => _busy = true);

    try {
      final user = RasdAuthService.auth.currentUser;

      if (user == null) {
        throw StateError(
          AuthStore.arabic.value
              ? 'انتهت جلسة تسجيل الدخول. '
              'سجل الدخول بالبريد الجديد لإكمال التحديث.'
              : 'Your session has ended. Sign in with '
              'your new email to complete the update.',
        );
      }

      // Fetch the latest email state from Firebase Auth.
      await user.reload();

      final updatedUser =
          RasdAuthService.auth.currentUser;

      final currentEmail =
      updatedUser?.email?.trim().toLowerCase();

      final expectedEmail =
      _pendingEmail!.trim().toLowerCase();

      // Do not accept confirmation based only on a button press.
      if (currentEmail != expectedEmail ||
          updatedUser?.emailVerified != true) {
        if (!mounted) return;

        showCenterMessage(
          context,
          AuthStore.arabic.value
              ? 'لم يكتمل التحقق من البريد الجديد بعد. '
              'افتح رابط التحقق ثم حاول مرة أخرى.'
              : 'Your new email has not been verified yet. '
              'Open the verification link and try again.',
          success: false,
        );

        return;
      }

      // Sync the verified Auth email to Realtime Database.
      await RasdAuthService.functions
          .httpsCallable('syncVerifiedEmail')
          .call();

      // Refresh AuthStore with the updated account information.
      await RasdAuthService.loadProfile();

      if (!mounted) return;

      setState(() {
        _verificationPending = false;
        _pendingEmail = null;
      });

      // Now the update is fully completed.
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showRasdError(
          context,
          error,
          title: AuthStore.arabic.value
              ? 'تعذر تأكيد البريد الإلكتروني'
              : 'Could not confirm email',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Builds the profile form and email verification controls.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, child) {
        final emailChanged =
            _emailController.text.trim().toLowerCase() !=
                AuthStore.email.trim().toLowerCase();

        return PalmScaffold(
          appBar: glassAppBar(
            title: isArabic
                ? 'تعديل الملف الشخصي'
                : 'Edit Profile',
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
              ),
              onPressed: _busy
                  ? null
                  : () => Navigator.pop(context),
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
                      20,
                    ),
                    child: GlassBox(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 42,
                                color: AppColors.primary,
                              ),
                            ),

                            const SizedBox(height: 20),

                            AppTextField(
                              label: isArabic
                                  ? 'الاسم الكامل'
                                  : 'Full Name',
                              hint: isArabic
                                  ? 'الاسم الكامل'
                                  : 'Full Name',
                              icon: Icons.person_outline,
                              controller: _nameController,
                              validator: AuthValidators.name,
                            ),

                            const SizedBox(height: 14),

                            AppTextField(
                              label: isArabic
                                  ? 'البريد الإلكتروني'
                                  : 'Email',
                              hint: isArabic
                                  ? 'البريد الإلكتروني'
                                  : 'Email',
                              icon: Icons.mail_outline,
                              controller: _emailController,
                              keyboardType:
                              TextInputType.emailAddress,
                              validator: AuthValidators.email,
                            ),

                            const SizedBox(height: 14),

                            if (emailChanged &&
                                !_verificationPending) ...[
                              AppTextField(
                                label: isArabic
                                    ? 'كلمة المرور الحالية'
                                    : 'Current Password',
                                hint: isArabic
                                    ? 'أدخل كلمة المرور الحالية'
                                    : 'Enter your current password',
                                icon: Icons.lock_outline,
                                controller: _passwordController,
                                isPassword: true,
                                validator:
                                AuthValidators.required,
                              ),

                              const SizedBox(height: 14),
                            ],

                            AppTextField(
                              label: isArabic
                                  ? 'رقم الجوال'
                                  : 'Phone Number',
                              hint: '05XXXXXXXX',
                              icon: Icons.phone_outlined,
                              controller: _phoneController,
                              keyboardType:
                              TextInputType.phone,
                              validator: AuthValidators.phone,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : (_verificationPending
                          ? _confirmEmailChange
                          : _save),
                      child: Text(
                        _verificationPending
                            ? (isArabic
                            ? 'تم التحقق من بريدي الإلكتروني'
                            : "I've Verified My Email")
                            : (isArabic
                            ? 'حفظ التغييرات'
                            : 'Save Changes'),
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
