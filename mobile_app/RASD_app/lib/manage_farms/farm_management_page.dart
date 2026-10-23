import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../data/mock_data.dart';
import '../services/rasd_management_service.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';
import '../manage_palms/manage_palms_page.dart';
import 'manage_farmers_page.dart';
import 'farm_settings_page.dart';
import 'invitations_page.dart';

class FarmManagementPage extends StatelessWidget {
  final String farmId;

  const FarmManagementPage({
    super.key,
    required this.farmId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RasdFarm?>(
      stream: RasdManagementService.watchFarm(farmId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: Center(child: Text('${snapshot.error}')));
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final farm = snapshot.data!;
        final palmCount = farm.palmCount;

    return PalmScaffold(
      appBar: glassAppBar(
        title: farm.name,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassBox(
                padding: EdgeInsets.zero,
                radius: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.asset(
                      farm.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.beige,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.agriculture_rounded,
                            size: 52,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: GlassBox(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const PalmIcon(
                            size: 28,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$palmCount Palms',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            size: 28,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),

                          StreamBuilder<DatabaseEvent>(
                            stream: FirebaseDatabase.instance
                                .ref('users')
                                .orderByChild('farmId')
                                .equalTo(farmId)
                                .onValue,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Text(
                                  'Unable to load farmers',
                                  style: Theme.of(context).textTheme.bodySmall,
                                );
                              }

                              if (!snapshot.hasData) {
                                return const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }

                              final value = snapshot.data!.snapshot.value;

                              int farmerCount = 0;

                              if (value is Map) {
                                farmerCount = value.values.where((account) {
                                  if (account is! Map) return false;

                                  return account['role'] == 'Farmer' &&
                                      account['farmId'] == farmId;
                                }).length;
                              }

                              return Text(
                                '$farmerCount ${farmerCount == 1 ? 'Farmer' : 'Farmers'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              );
                            },
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ),
              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _ManagementCard(
                      icon: const PalmIcon(
                        size: 42,
                        color: AppColors.primary,
                      ),
                      title: 'Manage Palms',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManagePalmsPage(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _ManagementCard(
                      icon: const Icon(
                        Icons.groups_rounded,
                        size: 42,
                        color: AppColors.primary,
                      ),
                      title: 'Manage Farmers',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageFarmersPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                child: _ManagementCard(
                  icon: const Icon(Icons.mail_outline, size: 42, color: AppColors.primary),
                  title: 'Pending Invitations',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const InvitationsPage())),
                ),
              ),
              const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: _ManagementCard(
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 42,
                  color: AppColors.primary,
                ),
                title: 'Farm Settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FarmSettingsPage(),
                    ),
                  );
                },
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

class _ManagementCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}