// Lists the invitations the owner has sent and their status.
import 'package:flutter/material.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';
import '../services/rasd_errors.dart';
import '../data/auth_store.dart';
/// Page listing sent invitations.
class InvitationsPage extends StatelessWidget {
  const InvitationsPage({super.key});

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
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
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
? 'تعذر تحميل البريد الإلكتروني للمزارع'
: 'Unable to load farmer email',
);
                      }

                      if (!snapshot.hasData) {
return Text(
isArabic
? 'جارٍ تحميل البريد الإلكتروني للمزارع...'
: 'Loading farmer email...',
);
                      }

return Text(
isArabic
? 'البريد الإلكتروني للمزارع: ${snapshot.data!['farmerEmail']}'
: 'Farmer Email: ${snapshot.data!['farmerEmail']}',
);
                    },
                  ),

                ),
                TextButton(onPressed: () async {
                  try {
                    await RasdManagementService.cancelInvitation(invitation['id'].toString());
                  } catch (error) {
                    if (context.mounted) {
showRasdError(
context,
error,
title: AuthStore.arabic.value
? 'تعذر إلغاء الدعوة'
: 'Could not cancel the invitation',
);
                    }
                  }
}, child: Text(
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
