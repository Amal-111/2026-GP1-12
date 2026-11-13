// Lists the invitations the owner has sent and their status.
import 'package:flutter/material.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';
import '../services/rasd_errors.dart';
import '../data/auth_store.dart';
/// Page listing sent invitations.
class InvitationsPage extends StatelessWidget {
  const InvitationsPage({super.key});

/// Builds the page using the selected language.

@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
return PalmScaffold(
appBar: glassAppBar(
title: isArabic ? 'الدعوات المعلقة' : 'Pending Invitations',),
      body: SafeArea(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: RasdManagementService.watchInvitations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                isArabic ? 'تعذر تحميل الدعوات.' : 'Unable to load invitations.',
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final invitations = snapshot.data!;
if (invitations.isEmpty) {
return Center(
child: GlassBox(
child: Text(
isArabic ? 'لا توجد دعوات معلقة' : 'No pending invitations',
),
),
);
}
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: invitations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              return GlassBox(child: Row(children: [
                const Icon(Icons.mail_outline),
                const SizedBox(width: 12),

                Expanded(
                  child:
                  FutureBuilder<Map<String, String>>(
                    future: RasdManagementService.getInvitationDetails(
                      invitation['id'].toString(),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
return Text(
isArabic
? 'تعذر تحميل بيانات المزارع'
: 'Unable to load farmer details',
);
                      }

                      if (!snapshot.hasData) {
return Text(
isArabic
? 'جارٍ تحميل بيانات المزارع...'
: 'Loading farmer details...',
);
                      }


            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (snapshot.data!['farmerName'] == null ||
                      snapshot.data!['farmerName'] == 'Unknown Farmer')
                      ? (isArabic ? 'مزارع غير معروف' : 'Unknown Farmer')
                      : snapshot.data!['farmerName']!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (snapshot.data!['farmerEmail'] == null ||
                      snapshot.data!['farmerEmail'] == 'Unknown Email')
                      ? (isArabic ? 'بريد إلكتروني غير معروف' : 'Unknown Email')
                      : snapshot.data!['farmerEmail']!,
                  style: Theme.of(context).textTheme.bodySmall,
                  softWrap: true,
                ),
              ],
            );

                    },
                  ),

                ),
      TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(
                  isArabic ? 'إلغاء الدعوة؟' : 'Cancel Invitation?',
                ),
                content: Text(
                  isArabic
                      ? 'هل أنت متأكد من إلغاء هذه الدعوة؟'
                      : 'Are you sure you want to cancel this invitation?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(isArabic ? 'رجوع' : 'Back'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(isArabic ? 'إلغاء الدعوة' : 'Cancel Invitation'),
                  ),
                ],
              ),
            );

            if (confirmed != true || !context.mounted) return;

            try {
              await RasdManagementService.cancelInvitation(
                invitation['id'].toString(),
              );
            } catch (error) {
              if (context.mounted) {
                showRasdError(
                  context,
                  error,
                  title: isArabic
                      ? 'تعذر إلغاء الدعوة'
                      : 'Could not cancel the invitation',
                );
              }
            }
          },
                    child: Text(
isArabic ? 'إلغاء' : 'Cancel',
)),
              ]));
            },
          );
        },
      )),
);
},
);
}
}
