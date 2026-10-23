import 'package:flutter/material.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';

class InvitationsPage extends StatelessWidget {
  const InvitationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(title: 'Pending Invitations'),
      body: SafeArea(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: RasdManagementService.watchInvitations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final invitations = snapshot.data!;
          if (invitations.isEmpty) return const Center(child: GlassBox(child: Text('No pending invitations')));
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
                        return const Text('Unable to load farmer email');
                      }

                      if (!snapshot.hasData) {
                        return const Text('Loading farmer email...');
                      }

                      return Text(
                        'Farmer Email: ${snapshot.data!['farmerEmail']}',
                      );
                    },
                  ),

                ),
                TextButton(onPressed: () async {
                  try {
                    await RasdManagementService.cancelInvitation(invitation['id'].toString());
                  } catch (error) {
                    if (context.mounted) showCenterMessage(context, error.toString(), success: false);
                  }
                }, child: const Text('Cancel')),
              ]));
            },
          );
        },
      )),
    );
  }
}
