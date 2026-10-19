import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../screens/home.dart';
import 'farm_management_page.dart';
import 'add_farm_page.dart';

class MyFarmsPage extends StatelessWidget {
  const MyFarmsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'My Farms',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 23,
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              child: IconButton(
                icon: const Icon(
                  Icons.person,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  // Profile navigation will be connected later.
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: MockData.changes,
          builder: (context, _) {
            final farms = MockData.farms;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddFarmPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Farm'),
                    ),
                  ),
                ),

                Expanded(
                  child: farms.isEmpty
                      ? Center(
                    child: GlassBox(
                      child: Text(
                        'No farms found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: farms.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final farm = farms[index];
                      final palmCount = farm.palmCount;

                      return _FarmCard(
                        farm: farm,
                        palmCount: palmCount,
                        onTap: () {
                          MockData.selectedFarmId = farm.id;
                          MockData.notifyChange();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        },
                        onManage: () {
                          MockData.selectedFarmId = farm.id;
                          MockData.notifyChange();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FarmManagementPage(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  final RasdFarm farm;
  final int palmCount;
  final VoidCallback onTap;
  final VoidCallback onManage;

  const _FarmCard({
    required this.farm,
    required this.palmCount,
    required this.onTap,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: GlassBox(
          padding: const EdgeInsets.all(14),
          child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 88,
              height: 88,
              child: farm.imagePath.isEmpty
                  ? _buildImageFallback()
                  : Image.asset(
                farm.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildImageFallback();
                },
              ),
            ),

                  ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farm.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                const SizedBox(height: 4),

                Text(
                  '$palmCount Palms · ${farm.farmerCount} ${farm.farmerCount == 1 ? 'Farmer' : 'Farmers'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton(
                  onPressed: onManage,
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
          ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: AppColors.beige,
      alignment: Alignment.center,
      child: const Icon(
        Icons.agriculture_rounded,
        size: 34,
        color: AppColors.primary,
      ),
    );
  }
}