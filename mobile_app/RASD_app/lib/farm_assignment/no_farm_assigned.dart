
import 'package:flutter/material.dart';
import '../profile/profile_page.dart';
import '../services/rasd_management_service.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';

class NoFarmAssigned extends StatefulWidget {
  const NoFarmAssigned({super.key});

  @override
  State<NoFarmAssigned> createState() => _NoFarmAssignedState();
}

class _NoFarmAssignedState extends State<NoFarmAssigned> {
  String? _busyInvitationId;

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
        showCenterMessage(context, 'Invitation rejected.');
      }

      // Home listens to users/{uid}.
      // Once farmId changes, Home automatically shows the farm pages.
    } catch (error) {
      if (mounted) {
        showCenterMessage(
          context,
          error.toString(),
          success: false,
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
    return PalmScaffold(
      appBar: AppBar(
        title: const Text('RASD'),
        actions: [
          IconButton(
            tooltip: 'Profile',
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
                    'Unable to load invitations:\n${snapshot.error}',
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
                    'No Farm Assigned',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your account is not assigned to a farm yet. '
                        'You can accept an invitation from a farm owner '
                        'to start monitoring palm trees.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Farm Invitations',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (invitations.isEmpty)
                    const GlassBox(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.mark_email_unread_outlined,
                              size: 42,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No pending invitations',
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Invitations from farm owners will appear here.',
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

                      final farmId =
                      (invitation['farmId'] ?? '').toString();

                      final busy = _busyInvitationId != null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassBox(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Farm Invitation',
                                style: Theme.of(context)
                                    .textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),


                              FutureBuilder<Map<String, String>>(
                                future: RasdManagementService.getInvitationDetails(
                                  invitationId,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return const Text('Unable to load farm information');
                                  }

                                  if (!snapshot.hasData) {
                                    return const Text('Loading farm information...');
                                  }

                                  final info = snapshot.data!;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Farm Name: ${info['farmName']}'),
                                      const SizedBox(height: 4),
                                      Text('Farm Owner: ${info['ownerName']}'),
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
                                      child: const Text('Reject'),
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
                                          : const Text('Accept'),
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
  }
}
