// Shows the farm invitations a farmer received and lets them accept or decline.
import 'package:flutter/material.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';
import '../services/rasd_errors.dart';
import '../data/auth_store.dart';

/// Farmer accepts or rejects invitations sent by farm owners.
class FarmRequestPage extends StatefulWidget {
  const FarmRequestPage({super.key});
  @override
  State<FarmRequestPage> createState() => _FarmRequestPageState();
}

class _FarmRequestPageState extends State<FarmRequestPage> {
  /// True while a request is running (disables the button).
  bool _busy = false;

  /// Accepts or declines an invitation, then refreshes the screen.
  Future<void> _respond(String id, {required bool accept}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (accept) {
        await RasdManagementService.acceptInvitation(id);
      } else {
        await RasdManagementService.rejectInvitation(id);
      }
      if (mounted && accept) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showRasdError(
          context,
          error,
          title: AuthStore.arabic.value
              ? (accept
              ? 'تعذر قبول الدعوة'
              : 'تعذر رفض الدعوة')
              : (accept
              ? 'Could not accept the invitation'
              : 'Could not reject the invitation'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Displays incoming farm invitations in the selected language.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, child) {
        return PalmScaffold(
          appBar: glassAppBar(
            title: isArabic ? 'دعوات المزارع' : 'Farm Invitations',
          ),
          body: SafeArea(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: RasdManagementService.watchMyInvitations(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      isArabic
                          ? 'تعذر تحميل الدعوات'
                          : 'Could not load invitations',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final invitations = snapshot.data!;

                if (invitations.isEmpty) {
                  return Center(
                    child: GlassBox(
                      child: Text(
                        isArabic
                            ? 'لا توجد دعوات معلقة'
                            : 'No pending invitations',
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: invitations.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final invitation = invitations[index];
                    final id = invitation['id'].toString();

                    return GlassBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'دعوة مزرعة' : 'Farm Invitation',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${isArabic ? 'معرّف المزرعة' : 'Farm ID'}: ${invitation['farmId']}',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _respond(id, accept: false),
                                  child: Text(
                                    isArabic ? 'رفض' : 'Reject',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _respond(id, accept: true),
                                  child: Text(
                                    isArabic ? 'قبول' : 'Accept',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
