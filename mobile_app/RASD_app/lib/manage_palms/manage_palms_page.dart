import 'package:flutter/material.dart';
import '../theme/palm_icon.dart';
import '../theme/app_colors.dart';
import 'palm_store.dart';
import 'add_palm_page.dart';
import 'edit_palm_page.dart';
import '../theme/glass_widgets.dart';

/// Manage Palms: list of palms with Add, Edit and Delete.
class ManagePalmsPage extends StatefulWidget {
  const ManagePalmsPage({super.key});

  @override
  State<ManagePalmsPage> createState() => _ManagePalmsPageState();
}

class _ManagePalmsPageState extends State<ManagePalmsPage> {
  final PalmStore _store = PalmStore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Palm> get _filteredPalms {
    final query = _searchController.text.trim().toLowerCase();
    return _store.palms.where((palm) {
      return query.isEmpty ||
          palm.id.toLowerCase().contains(query) ||
          (palm.type ?? '').toLowerCase().contains(query);
    }).toList();
  }

  void _showMessage(String text) {
    showCenterMessage(context, text);
  }

  Future<void> _openAddPalm() async {
    // A farm owner who is not assigned to any farm cannot add palms.
    if (_store.activeFarmId == null || _store.activeFarmId!.isEmpty) {
      showCenterMessage(
        context,
        'You are not assigned to any farm yet.',
        success: false,
      );
      return;
    }
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddPalmPage()),
    );
    if (added == true && mounted) {
      _showMessage('Palm tree added successfully.');
    }
  }

  Future<void> _openEditPalm(Palm palm) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditPalmPage(palm: palm)),
    );
    if (saved == true && mounted) {
      _showMessage('Palm tree information updated successfully.');
    }
  }

  Future<void> _confirmDelete(Palm palm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${palm.id}?'),
        content: const Text(
          'Are you sure you want to delete this palm tree? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _store.deletePalm(palm);
      if (mounted) _showMessage('Palm tree deleted successfully.');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Healthy':
        return AppColors.healthy;
      case 'Suspected':
        return AppColors.suspected;
      case 'Under Monitoring':
        return AppColors.monitoring;
      case 'Treated':
        return AppColors.treated;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Suspected':
        return Icons.warning_rounded;
      case 'Under Monitoring':
        return Icons.access_time_rounded;
      case 'Treated':
        return Icons.medical_services_rounded;
      default:
        return Icons.park_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PalmScaffold(
      appBar: glassAppBar(
        title: 'Manage Palms',
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store.changes,
          builder: (context, _) {
            final palms = _filteredPalms;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search by Palm ID...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: palms.isEmpty
                      ? Center(
                          child: GlassBox(
                            child: Text(
                              'No palms found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: palms.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _buildPalmCard(palms[index]),
                        ),
                ),
                // Add Palm button at the bottom of the page.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openAddPalm,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Palm'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPalmCard(Palm palm) {
    final color = _statusColor(palm.statusLabel);

    return GlassBox(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      child: Row(
          children: [
            Container(
              width: 52,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: appIcon(_statusIcon(palm.statusLabel), color: color, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(palm.id,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    palm.statusLabel,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    '${palm.type ?? '-'} · ${palm.age == null ? '-' : '${palm.age} yrs'} · ${palm.deviceId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _openEditPalm(palm),
              icon: const Icon(Icons.edit_outlined),
              color: AppColors.primary,
              tooltip: 'Edit',
            ),
            IconButton(
              onPressed: () => _confirmDelete(palm),
              icon: const Icon(Icons.delete_outline),
              color: AppColors.error,
              tooltip: 'Delete',
            ),
          ],
        ),
    );
  }
}
