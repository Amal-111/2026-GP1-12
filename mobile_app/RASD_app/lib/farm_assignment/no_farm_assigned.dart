import 'package:flutter/material.dart';

import '../data/auth_store.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';
import 'farm_request_page.dart';

/// Page body shown by Home when the farmer has no farm.
/// It has no Scaffold, because Home already has the app bar area and the
/// bottom navigation bar around it.
class NoFarmAssigned extends StatefulWidget {
  const NoFarmAssigned({super.key});

  @override
  State<NoFarmAssigned> createState() => _NoFarmAssignedState();
}

class _NoFarmAssignedState extends State<NoFarmAssigned> {
  Future<void> _openRequestPage() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const FarmRequestPage()),
    );

    if (sent == true && mounted) {
      showCenterMessage(context, 'Request sent to the farm owner.');
    }
  }

  String _farmName(String farmId) {
    for (final farm in MockData.farms) {
      if (farm.id == farmId) return farm.name;
    }
    return 'the farm';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListenableBuilder(
            listenable: MockData.changes,
            builder: (context, _) {
              final pending = AuthStore.pendingRequest;

              return GlassBox(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: PalmIcon(size: 46, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      pending == null ? 'No Farm Assigned' : 'Request Pending',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pending == null
                          ? 'Your account is not linked to a farm yet. '
                              'Send a request to join a farm and the farm '
                              'owner will review it.'
                          : 'Your request to join ${_farmName(pending.farmId)} '
                              'is waiting for the farm owner to approve it.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: pending == null
                          ? ElevatedButton.icon(
                              onPressed: _openRequestPage,
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Request Farm Assignment'),
                            )
                          : OutlinedButton(
                              onPressed: () => AuthStore.cancelRequest(pending),
                              child: const Text('Cancel Request'),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
