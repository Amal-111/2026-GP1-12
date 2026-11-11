// Profile screen: account info, language, notifications and log out.
import 'package:flutter/material.dart';
import '../services/rasd_farms_service.dart';
import '../auth/welcome_page.dart';
import '../data/auth_store.dart';
import '../services/firebase_auth_service.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';
import 'guidance_page.dart';

/// Profile page. Used as the Profile tab in Home and as a normal page
/// (for example from the profile button in My Farms).
class ProfilePage extends StatefulWidget {
  final bool showBackButton;

  const ProfilePage({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// Opens a page and shows a success message when it returns.
  Future<void> _open(Widget page, String successMessage) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    if (done == true && mounted) {
      setState(() {});
      showCenterMessage(context, successMessage);
    }
  }

  /// Asks for confirmation, then logs out.
  Future<void> _confirmLogOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AuthStore.arabic.value ? 'تسجيل الخروج؟' : 'Log out?',
        ),
        content: Text(
          AuthStore.arabic.value
              ? 'ستحتاج إلى تسجيل الدخول مرة أخرى لاستخدام رصد.'
              : 'You will need to log in again to use RASD.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AuthStore.arabic.value ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(AuthStore.arabic.value ? 'تسجيل الخروج' : 'Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await RasdAuthService.logOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
final isFarmer = AuthStore.role == UserRole.farmer;
final farmLabel = AuthStore.farmName ?? 'No farm assigned';

return PalmScaffold(
      appBar: glassAppBar(
title: isArabic ? 'الملف الشخصي' : 'Profile',
        leading: widget.showBackButton
            ? null
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              // Name, email, role and farm
              GlassBox(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 38,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AuthStore.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            AuthStore.email,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
_Chip(
isArabic
? (isFarmer ? 'مزارع' : 'مالك المزرعة')
: (isFarmer ? 'Farmer' : 'Farm Owner'),
filled: true,
),
                              if (isFarmer)
                                FutureBuilder<String>(
                                  future: RasdAuthService.getMyAssignedFarmName(),
                                  builder: (context, snapshot) {
if (snapshot.hasError) {
return _Chip(
isArabic ? 'تعذر تحميل المزرعة' : 'Unable to load farm',
);
}

if (!snapshot.hasData) {
return _Chip(
isArabic ? 'جارٍ التحميل...' : 'Loading...',
);
}

                                    return _Chip(snapshot.data!);
                                  },
                                )

                              else
                                StreamBuilder<List<FarmRecord>>(
                                  stream: RasdFarmsService.watchMyFarms(),
                                  builder: (context, snapshot) {
if (snapshot.hasError) {
return _Chip(
isArabic ? 'غير متاح' : 'Unavailable',
);
}

if (!snapshot.hasData) {
return const _Chip('...');
}

final count = snapshot.data!.length;

return _Chip(
isArabic
? '$count ${count == 1 ? 'مزرعة' : 'مزارع'}'
: '$count ${count == 1 ? 'Farm' : 'Farms'}',
);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              GlassBox(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
_SectionLabel(isArabic ? 'الحساب' : 'Account'),
                    _MenuRow(
                      icon: Icons.edit_outlined,
label: isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile',
                      trailing: const _Chevron(),
                      onTap: () => _open(
                        const EditProfilePage(),
isArabic
? 'تم تحديث الملف الشخصي بنجاح.'
: 'Profile updated successfully.',
                      ),
                    ),
                    const _RowDivider(),
                    _MenuRow(
                      icon: Icons.lock_outline,
label: isArabic ? 'تغيير كلمة المرور' : 'Change Password',
                      trailing: const _Chevron(),
                      onTap: () => _open(
                        const ChangePasswordPage(),
isArabic
? 'تم تحديث كلمة المرور بنجاح.'
: 'Password updated successfully.',
                      ),
                    ),

_SectionLabel(isArabic ? 'الإعدادات' : 'Settings'),
                    _MenuRow(
                      icon: Icons.language,
label: isArabic ? 'اللغة' : 'Language',
                      trailing: const _LanguagePills(),
                    ),
                    const _RowDivider(),
                    _MenuRow(
                      icon: Icons.notifications_outlined,
label: isArabic ? 'الإشعارات' : 'Notifications',
                      trailing: ValueListenableBuilder<bool>(
                        valueListenable: AuthStore.notificationsOn,
                        builder: (context, on, _) => Switch(
                          value: on,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.primary,
                          onChanged: (value) =>
                              AuthStore.notificationsOn.value = value,
                        ),
                      ),
                    ),

_SectionLabel(isArabic ? 'المساعدة' : 'Help'),
                    _MenuRow(
                      icon: Icons.menu_book_outlined,
label: isArabic ? 'الإرشادات' : 'Guidance',
                      trailing: const _Chevron(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GuidancePage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogOut,
                  icon: const Icon(Icons.logout),
label: Text(
isArabic ? 'تسجيل الخروج' : 'Log Out',
),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
);
},
);
}
}

/// Small label chip.
class _Chip extends StatelessWidget {
  final String text;
  final bool filled;

  const _Chip(this.text, {this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: filled
            ? const Color(0xFFDCEDE0)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Label above a group of rows.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

/// Thin divider between rows.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 48,
      color: AppColors.textPrimary.withValues(alpha: 0.1),
    );
  }
}

/// Arrow icon at the end of a row.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.textSecondary,
    );
  }
}

/// One tappable row in the menu.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// English / Arabic selector.
class _LanguagePills extends StatelessWidget {
  const _LanguagePills();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, _) {
        Widget pill(String text, bool selected, bool arabicValue) {
          return GestureDetector(
            onTap: () => AuthStore.arabic.value = arabicValue,
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            pill('English', !isArabic, false),
            pill('العربية', isArabic, true),
          ],
        );
      },
    );
  }
}
