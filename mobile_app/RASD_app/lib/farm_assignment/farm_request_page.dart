import 'package:flutter/material.dart';
import '../services/rasd_management_service.dart';
import '../theme/glass_widgets.dart';

/// Farmer accepts or rejects invitations sent by farm owners.
class FarmRequestPage extends StatefulWidget {
  const FarmRequestPage({super.key});
  @override
  State<FarmRequestPage> createState() => _FarmRequestPageState();
}

class _FarmRequestPageState extends State<FarmRequestPage> {
  bool _busy = false;

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
      if (mounted) showCenterMessage(context, error.toString(), success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(title: 'Farm Invitations'),
      body: SafeArea(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: RasdManagementService.watchMyInvitations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final invitations = snapshot.data!;
          if (invitations.isEmpty) return const Center(
            child: GlassBox(child: Text('No pending invitations')));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: invitations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              final id = invitation['id'].toString();
              return GlassBox(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Farm Invitation', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Farm ID: ${invitation['farmId']}'),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: _busy ? null : () => _respond(id, accept: false),
                      child: const Text('Reject'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: _busy ? null : () => _respond(id, accept: true),
                      child: const Text('Accept'))),
                  ]),
                ],
              ));
            },
          );
        },
      )),
    );
  }
}
