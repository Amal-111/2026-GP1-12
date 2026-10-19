import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import 'assign_farmer_page.dart';
import 'edit_farmer_page.dart';

class ManageFarmersPage extends StatefulWidget {
  const ManageFarmersPage({super.key});

  @override
  State<ManageFarmersPage> createState() => _ManageFarmersPageState();
}

class _ManageFarmersPageState extends State<ManageFarmersPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FarmerData> get _filteredFarmers {
    final query = _searchController.text.trim().toLowerCase();

    return MockData.farmersForFarm().where((farmer) {
      return query.isEmpty ||
          farmer.name.toLowerCase().contains(query) ||
          farmer.email.toLowerCase().contains(query);
    }).toList();
  }

  void _showMessage(String text) {
    showCenterMessage(context, text);
  }

  Future<void> _confirmDelete(FarmerData farmer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${farmer.name}?'),
        content: const Text(
          'Are you sure you want to delete this farmer? '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      MockData.deleteFarmer(farmer);

      if (mounted) {
        _showMessage('Farmer deleted successfully.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Manage Farmers',
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: MockData.changes,
          builder: (context, _) {
            final farmers = _filteredFarmers;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final assigned = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssignFarmerPage(),
                          ),
                        );

                        if (assigned == true && mounted) {
                          _showMessage('Farmer assigned successfully.');
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Farmer'),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),

                Expanded(
                  child: farmers.isEmpty
                      ? Center(
                    child: GlassBox(
                      child: Text(
                        'No farmers found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: farmers.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildFarmerCard(farmers[index]);
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

  Widget _buildFarmerCard(FarmerData farmer) {
    return GlassBox(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 30,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmer.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  farmer.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () async {
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditFarmerPage(
                    farmer: farmer,
                  ),
                ),
              );

              if (saved == true && mounted) {
                _showMessage('Farmer information updated successfully.');
              }
            },
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.primary,
            tooltip: 'Edit',
          ),

          IconButton(
            onPressed: () => _confirmDelete(farmer),
            icon: const Icon(Icons.delete_outline),
            color: AppColors.error,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}