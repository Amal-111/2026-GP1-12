// Screen shown to a farmer who is not assigned to a farm yet; lists pending invitations.

import 'package:flutter/material.dart';
import '../profile/profile_page.dart';
import '../services/rasd_management_service.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';
import '../services/rasd_errors.dart';
import '../data/auth_store.dart';
/// Page for a farmer with no farm.
class NoFarmAssigned extends StatefulWidget {
  const NoFarmAssigned({super.key});

  @override
  State<NoFarmAssigned> createState() => _NoFarmAssignedState();
}

class _NoFarmAssignedState extends State<NoFarmAssigned> {
  String? _busyInvitationId;

  /// Accepts or declines an invitation, then refreshes the screen.
  Future<void> _respond(
      String invitationId, {
        required bool accept,
      }) async {
    if (_busyInvitationId != null) return;

    setState(() => _busyInvitationId = invitationId);

    try {
      if (accept) {
        await RasdManagementService.acceptInvitation(invitationId);
      } else {
        await RasdManagementService.rejectInvitation(invitationId);
      }

      if (mounted && !accept) {
        showCenterMessage(
          context,
          AuthStore.arabic.value
              ? 'تم رفض الدعوة.'
              : 'The invitation was rejected.',
        );
      }

      // Home listens to users/{uid}.
      // Once farmId changes, Home automatically shows the farm pages.
    } catch (error) {
      if (mounted) {
        showRasdError(
          context,
          error,
          title: AuthStore.arabic.value
              ? (accept ? 'تعذر قبول الدعوة' : 'تعذر رفض الدعوة')
              : (accept
              ? 'Could not accept the invitation'
              : 'Could not reject the invitation'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyInvitationId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, child) {
        return PalmScaffold(
          appBar: AppBar(
            title: const Text('RASD'),
            actions: [
              IconButton(
                tooltip: isArabic ? 'الملف الشخصي' : 'Profile',
                icon: const Icon(Icons.person_outline),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfilePage(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: RasdManagementService.watchMyInvitations(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isArabic
                            ? 'تعذر تحميل الدعوات:\n${snapshot.error}'
                            : 'Unable to load invitations:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final invitations = snapshot.data!;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      const PalmIcon(
                        size: 72,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isArabic ? 'لا توجد مزرعة مرتبطة بالحساب' : 'No Farm Assigned',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isArabic
                            ? 'حسابك غير مرتبط بمزرعة حتى الآن. يمكنك قبول دعوة من مالك مزرعة لبدء مراقبة أشجار النخيل.'
                            : 'Your account is not assigned to a farm yet. You can accept an invitation from a farm owner to start monitoring palm trees.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 30),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isArabic ? 'دعوات المزارع' : 'Farm Invitations',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (invitations.isEmpty)
                        GlassBox(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.mark_email_unread_outlined,
                                  size: 42,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isArabic
                                      ? 'لا توجد دعوات معلقة'
                                      : 'No pending invitations',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isArabic
                                      ? 'ستظهر هنا الدعوات المرسلة من أصحاب المزارع.'
                                      : 'Invitations from farm owners will appear here.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...invitations.map((invitation) {
                          final invitationId =
                          invitation['id'].toString();

                          final busy = _busyInvitationId != null;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassBox(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'دعوة مزرعة' : 'Farm Invitation',
                                    style: Theme.of(context)
                                        .textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  FutureBuilder<Map<String, String>>(
                                    future: RasdManagementService
                                        .getInvitationDetails(invitationId),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) {
                                        return Text(
                                          isArabic
                                              ? 'تعذر تحميل معلومات المزرعة'
                                              : 'Unable to load farm information',
                                        );
                                      }

                                      if (!snapshot.hasData) {
                                        return Text(
                                          isArabic
                                              ? 'جارٍ تحميل معلومات المزرعة...'
                                              : 'Loading farm information...',
                                        );
                                      }

                                      final info = snapshot.data!;

                                      return Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${isArabic ? 'اسم المزرعة' : 'Farm Name'}: ${info['farmName']}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${isArabic ? 'مالك المزرعة' : 'Farm Owner'}: ${info['ownerName']}',
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: busy
                                              ? null
                                              : () => _respond(
                                            invitationId,
                                            accept: false,
                                          ),
                                          child: Text(
                                            isArabic ? 'رفض' : 'Reject',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: busy
                                              ? null
                                              : () => _respond(
                                            invitationId,
                                            accept: true,
                                          ),
                                          child: _busyInvitationId ==
                                              invitationId
                                              ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child:
                                            CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                              : Text(
                                            isArabic ? 'قبول' : 'Accept',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
